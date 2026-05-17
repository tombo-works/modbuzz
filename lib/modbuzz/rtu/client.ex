defmodule Modbuzz.RTU.Client do
  @moduledoc false

  use GenServer

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
       reqs: %{},
       binary: <<>>
     }}
  end

  def terminate(reason, state) do
    %{
      client_name: client_name,
      reqs: reqs
    } = state

    Log.error("RTU client terminated, #{inspect(reason)}.", nil, state)

    # All pending requests should be notified of the error
    Enum.each(reqs, fn {_unit_id, req} ->
      maybe_report_response(req, client_name, {:error, :client_terminated})
    end)
  end

  def handle_call({:call, unit_id, request, timeout}, from, state)
      when is_valid_unit_id(unit_id) do
    %{
      transport: transport,
      transport_pid: transport_pid,
      reqs: reqs
    } = state

    req = Map.get(reqs, unit_id)
    adu = ADU.new(request, unit_id)
    new_req = {:call, unit_id, request, from, make_ref()}

    with true <- is_nil(req) || {:error, :another_request_in_progress},
         binary <- ADU.encode(adu),
         :ok <- transport.write(transport_pid, binary, timeout) do
      Process.send_after(self(), {:timeout?, new_req}, timeout)
      {:noreply, %{state | reqs: Map.put(reqs, adu.unit_id, new_req)}}
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
      reqs: reqs
    } = state

    req = Map.get(reqs, unit_id)
    adu = ADU.new(request, unit_id)
    new_req = {:cast, unit_id, request, pid, make_ref()}

    with true <- is_nil(req) || {:error, :another_request_in_progress},
         binary <- ADU.encode(adu),
         :ok <- transport.write(transport_pid, binary, timeout) do
      Process.send_after(self(), {:timeout?, new_req}, timeout)
      {:noreply, %{state | reqs: Map.put(reqs, adu.unit_id, new_req)}}
    else
      {:error, :another_request_in_progress} = res_tuple ->
        maybe_report_response(new_req, client_name, res_tuple)
        {:noreply, state}

      {:error, reason} = res_tuple ->
        Log.error("#{inspect(transport)} write error, #{inspect(reason)}.", nil, state)
        maybe_report_response(new_req, client_name, res_tuple)
        {:noreply, state}
    end
  end

  def handle_info({:timeout?, {_, unit_id, _, _, ref}}, state) do
    %{
      client_name: client_name,
      reqs: reqs
    } = state

    req = Map.get(reqs, unit_id)

    case req do
      # already responded
      nil ->
        {:noreply, state}

      # timeout for the current request, report timeout error
      {_, unit_id_, request_, _, ref_} = req_ when ref_ == ref ->
        Log.error("RTU server didn't respond for #{inspect(request_)}.", nil, state)
        res_tuple = {:error, :timeout}

        maybe_report_response(req_, client_name, res_tuple)

        # Do not clear the shared buffer here.
        # A timeout for one unit_id can happen while another unit_id is still receiving data.
        # Clearing the buffer would drop that partial data.
        {:noreply, %{state | reqs: Map.put(reqs, unit_id_, nil)}}

      # the current request is different, do not report timeout error
      # this means the request that triggered this timeout message has already been responded to
      # and a new request for the same unit_id has been sent after that
      {_, _, _, _, ref_} when ref_ != ref ->
        {:noreply, state}
    end
  end

  def handle_info({:circuits_uart, _device_name, binary}, state) do
    %{
      client_name: client_name,
      reqs: reqs
    } = state

    new_binary = state.binary <> binary

    # NOTE: unit_id: 1, functions_code: 1, crc: 2, so at least 4 bytes
    with true <- byte_size(new_binary) > 4 || {:error, :binary_is_short},
         {:ok, %ADU{unit_id: unit_id, pdu: pdu}} <- ADU.decode_response(new_binary) do
      res_tuple = {:ok, pdu}
      req = Map.get(reqs, unit_id)

      maybe_report_response(req, client_name, res_tuple)

      {:noreply, %{state | reqs: Map.put(reqs, unit_id, nil), binary: <<>>}}
    else
      {:error, :binary_is_short} ->
        {:noreply, %{state | binary: new_binary}}

      {:error, %ADU{unit_id: unit_id, pdu: _pdu, crc_valid?: false} = adu} ->
        Log.warning("CRC error detected, #{inspect(adu)}.", nil, state)
        res_tuple = {:error, :crc_error}
        req = Map.get(reqs, unit_id)

        maybe_report_response(req, client_name, res_tuple)

        {:noreply, %{state | reqs: Map.put(reqs, unit_id, nil), binary: <<>>}}
    end
  end

  defp maybe_report_response(req, client_name, res_tuple) do
    case req do
      nil ->
        :noop

      {:call, _unit_id, _request, from, _ref} when is_tuple(from) ->
        GenServer.reply(from, res_tuple)

      {:cast, unit_id, request, pid, _ref} when is_pid(pid) ->
        send(pid, {:modbuzz, client_name, unit_id, request, res_tuple})

      _ ->
        raise ArgumentError, "unexpected req format: #{inspect(req)}"
    end
  end
end
