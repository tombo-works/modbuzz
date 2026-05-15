defmodule Modbuzz.RTU.Client do
  @moduledoc false

  use GenServer

  alias Modbuzz.PDU
  alias Modbuzz.RTU.ADU
  alias Modbuzz.RTU.Log

  @unit_id_max 247

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    client_name = Keyword.fetch!(args, :name)
    transport = Keyword.get(args, :transport, Circuits.UART)
    transport_opts = Keyword.get(args, :transport_opts, []) ++ [active: true]
    device_name = Keyword.fetch!(args, :device_name)

    {:ok, transport_pid} = transport.start_link([])
    :ok = transport.open(transport_pid, device_name, transport_opts)

    {:ok,
     %{
       client_name: client_name,
       transport: transport,
       device_name: device_name,
       transport_pid: transport_pid,
       callers: List.duplicate(nil, @unit_id_max + 1),
       binary: <<>>
     }}
  end

  def handle_call({:call, unit_id, request, timeout}, from, state) do
    %{
      transport: transport,
      transport_pid: transport_pid,
      callers: callers
    } = state

    adu = PDU.encode(request) |> ADU.new(unit_id)
    caller = Enum.fetch!(callers, adu.unit_id)

    if is_nil(caller) do
      Process.send_after(self(), {:no_response?, adu}, timeout)
      binary = ADU.encode(adu)

      :ok = transport.write(transport_pid, binary, timeout)

      {:noreply, %{state | callers: List.replace_at(callers, adu.unit_id, from)}}
    else
      res_tuple = {:error, PDU.to_error(request, :server_device_busy)}

      {:reply, res_tuple, state}
    end
  end

  def handle_cast({:cast, unit_id, request, pid, timeout}, state) when is_pid(pid) do
    %{
      client_name: client_name,
      transport: transport,
      transport_pid: transport_pid,
      callers: callers
    } = state

    adu = PDU.encode(request) |> ADU.new(unit_id)
    caller = Enum.fetch!(callers, adu.unit_id)

    if is_nil(caller) do
      Process.send_after(self(), {:no_response?, adu}, timeout)
      binary = ADU.encode(adu)

      :ok = transport.write(transport_pid, binary, timeout)

      {:noreply, %{state | callers: List.replace_at(callers, adu.unit_id, pid)}}
    else
      res_tuple = {:error, PDU.to_error(request, :server_device_busy)}

      maybe_report_response(pid, client_name, res_tuple)

      {:noreply, state}
    end
  end

  def handle_info({:no_response?, adu}, state) do
    %{
      client_name: client_name,
      callers: callers
    } = state

    caller = Enum.fetch!(callers, adu.unit_id)

    if is_nil(caller) do
      # already responded
      {:noreply, state}
    else
      Log.error("RTU server didn't respond.", nil, state)
      # treat as server device failure
      {:ok, req} = PDU.decode_request(adu.pdu)
      res_tuple = {:error, PDU.to_error(req, :server_device_failure)}

      maybe_report_response(caller, client_name, res_tuple)

      {:noreply, %{state | callers: List.replace_at(callers, adu.unit_id, nil), binary: <<>>}}
    end
  end

  def handle_info({:circuits_uart, _device_name, binary}, state) do
    %{
      client_name: client_name,
      callers: callers
    } = state

    new_binary = state.binary <> binary

    # NOTE: unit_id: 1, functions_code: 1, crc: 2, so at least 4 bytes
    with true <- byte_size(new_binary) > 4 || {:error, :binary_is_short},
         {:ok, %ADU{unit_id: unit_id, pdu: pdu}} <- ADU.decode_response(new_binary) do
      res_tuple = PDU.decode_response(pdu)
      caller = Enum.fetch!(callers, unit_id)

      maybe_report_response(caller, client_name, res_tuple)

      {:noreply, %{state | callers: List.replace_at(callers, unit_id, nil), binary: <<>>}}
    else
      {:error, :binary_is_short} ->
        {:noreply, %{state | binary: new_binary}}

      {:error, %ADU{unit_id: unit_id, pdu: _pdu, crc_valid?: false} = adu} ->
        Log.warning("CRC error detected, #{inspect(adu)}.", nil, state)
        res_tuple = {:error, :crc_error}
        caller = Enum.fetch!(callers, unit_id)

        maybe_report_response(caller, client_name, res_tuple)

        {:noreply, %{state | callers: List.replace_at(callers, unit_id, nil), binary: <<>>}}
    end
  end

  defp maybe_report_response(caller, client_name, res_tuple) do
    cond do
      # for cast
      is_pid(caller) -> send(caller, {:modbuzz, client_name, res_tuple})
      # for call
      is_tuple(caller) -> GenServer.reply(caller, res_tuple)
      # for nil
      true -> :noop
    end
  end
end
