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
    transport_opts = args |> Keyword.get(:transport_opts, []) |> Keyword.put(:active, true)
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

    Log.error("RTU client terminated", reason, state)

    # All pending requests should be notified of the error
    Enum.each(reqs, fn {_unit_id, req} ->
      maybe_report_response(req, client_name, {:error, :client_terminated})
    end)
  end

  def handle_call({:call, unit_id, request, timeout}, from, state)
      when is_valid_unit_id(unit_id) do
    handle_req({:call, unit_id, request, from, timeout}, state)
  end

  def handle_cast({:cast, unit_id, request, pid, timeout}, state)
      when is_valid_unit_id(unit_id) and is_pid(pid) do
    handle_req({:cast, unit_id, request, pid, timeout}, state)
  end

  defp handle_req({call_or_cast, unit_id, request, from_or_pid, timeout}, state) do
    %{
      client_name: client_name,
      transport: transport,
      transport_pid: transport_pid,
      reqs: reqs
    } = state

    new_req = {call_or_cast, unit_id, request, from_or_pid, make_ref()}
    timer = Process.send_after(self(), {:timeout?, new_req}, timeout)

    with true <- is_nil(Map.get(reqs, unit_id)) || {:error, :another_request_in_progress},
         binary = request |> ADU.new(unit_id) |> ADU.encode(),
         :ok <- transport.write(transport_pid, binary, timeout) do
      {:noreply, %{state | reqs: Map.put(reqs, unit_id, new_req)}}
    else
      {:error, :another_request_in_progress} = res_tuple ->
        Process.cancel_timer(timer)
        maybe_report_response(new_req, client_name, res_tuple)
        {:noreply, state}

      {:error, reason} = res_tuple ->
        Log.error("#{inspect(transport)} write error", reason, state)
        Process.cancel_timer(timer)
        maybe_report_response(new_req, client_name, res_tuple)
        {:noreply, state}
    end
  end

  def handle_info({:timeout?, {_, unit_id, _, _, ref}}, state) do
    %{
      client_name: client_name,
      reqs: reqs
    } = state

    case Map.get(reqs, unit_id) do
      # already responded
      nil ->
        {:noreply, state}

      # timeout for the current request, report timeout error
      {_, unit_id_, request_, _, ref_} = req_ when ref_ == ref ->
        Log.error("RTU server didn't respond for #{inspect(request_)}", nil, state)
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

    case ADU.decode_response(new_binary) do
      {:ok, %ADU{unit_id: unit_id, pdu: pdu}} ->
        res_tuple = {:ok, pdu}
        req = Map.get(reqs, unit_id)

        maybe_report_response(req, client_name, res_tuple)

        {:noreply, %{state | reqs: Map.put(reqs, unit_id, nil), binary: <<>>}}

      {:error, {:pdu_unknown_function_code, _} = reason} ->
        # No response is sent to the requester; the pending request will eventually time out.
        Log.error("Decode error", reason, state)
        {:noreply, %{state | binary: <<>>}}

      {:error, :pdu_decode_error = reason} ->
        Log.error("Decode error", reason, state)
        {:noreply, %{state | binary: <<>>}}

      {:error, :adu_binary_is_short} ->
        {:noreply, %{state | binary: new_binary}}

      {:error, :adu_binary_is_long = reason} ->
        # No response is sent to the requester; the pending request will eventually time out.
        Log.error("Decode error", reason, state)
        {:noreply, %{state | binary: <<>>}}

      {:error, :adu_crc_error = reason} ->
        # No response is sent to the requester; the pending request will eventually time out.
        Log.warning("Decode error", reason, state)
        {:noreply, %{state | binary: <<>>}}

      {:error, %ADU{unit_id: unit_id, pdu: pdu}} ->
        res_tuple = {:error, pdu}
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
