defmodule Modbuzz.RTU.Client do
  @moduledoc false

  use GenServer

  alias Modbuzz.PDU
  alias Modbuzz.RTU.ADU
  alias Modbuzz.RTU.Log

  @unit_id_max 247

  defguardp is_valid_unit_id(unit_id) when unit_id >= 0 and unit_id <= @unit_id_max

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

  def terminate(reason, state) do
    %{
      client_name: client_name,
      callers: callers
    } = state

    Log.error("RTU client terminated, #{inspect(reason)}.", nil, state)

    # All pending callers should be notified of the error
    Enum.each(callers, fn caller ->
      maybe_report_response(caller, client_name, {:error, :client_terminated})
    end)
  end

  def handle_call({:call, unit_id, request, timeout}, from, state)
      when is_valid_unit_id(unit_id) do
    %{
      transport: transport,
      transport_pid: transport_pid,
      callers: callers
    } = state

    adu = PDU.encode(request) |> ADU.new(unit_id)
    caller = Enum.fetch!(callers, adu.unit_id)

    with true <- is_nil(caller) || {:error, :another_request_in_progress},
         binary <- ADU.encode(adu),
         :ok <- transport.write(transport_pid, binary, timeout) do
      Process.send_after(self(), {:no_response?, adu}, timeout)
      {:noreply, %{state | callers: List.replace_at(callers, adu.unit_id, {:call, from})}}
    else
      {:error, :another_request_in_progress} = res_tuple ->
        {:reply, res_tuple, state}

      {:error, reason} = res_tuple ->
        Log.error("#{inspect(transport)} write error, #{inspect(reason)}.", nil, state)
        {:reply, res_tuple, state}
    end
  end

  def handle_cast({:cast, unit_id, request, pid, timeout}, state)
      when is_valid_unit_id(unit_id) and is_pid(pid) do
    %{
      client_name: client_name,
      transport: transport,
      transport_pid: transport_pid,
      callers: callers
    } = state

    adu = PDU.encode(request) |> ADU.new(unit_id)
    caller = Enum.fetch!(callers, adu.unit_id)

    with true <- is_nil(caller) || {:error, :another_request_in_progress},
         binary <- ADU.encode(adu),
         :ok <- transport.write(transport_pid, binary, timeout) do
      Process.send_after(self(), {:no_response?, adu}, timeout)
      {:noreply, %{state | callers: List.replace_at(callers, adu.unit_id, {:cast, pid})}}
    else
      {:error, :another_request_in_progress} = res_tuple ->
        maybe_report_response({:cast, pid}, client_name, res_tuple)
        {:noreply, state}

      {:error, reason} = res_tuple ->
        Log.error("#{inspect(transport)} write error, #{inspect(reason)}.", nil, state)
        maybe_report_response({:cast, pid}, client_name, res_tuple)
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

      # Do not clear the shared buffer here.
      # A timeout for one unit_id can happen while another unit_id is still receiving data.
      # Clearing the buffer would drop that partial data.
      {:noreply, %{state | callers: List.replace_at(callers, adu.unit_id, nil)}}
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
    case caller do
      nil -> :noop
      {:cast, pid} when is_pid(pid) -> send(pid, {:modbuzz, client_name, res_tuple})
      {:call, from} when is_tuple(from) -> GenServer.reply(from, res_tuple)
      _ -> raise ArgumentError, "unexpected caller format: #{inspect(caller)}"
    end
  end
end
