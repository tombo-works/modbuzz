defmodule Modbuzz.RTU.Client.Receiver do
  @moduledoc false

  use GenServer

  alias Modbuzz.PDU
  alias Modbuzz.RTU.ADU

  @server_device_failure 0x04
  @server_device_busy 0x06
  @unit_id_max 247

  defguardp is_valid_unit_id(unit_id) when unit_id >= 0 and unit_id <= @unit_id_max

  def name(client_name) do
    {:via, Registry, {Modbuzz.Registry, {client_name, __MODULE__}}}
  end

  def pid(client_name) do
    GenServer.whereis(name(client_name))
  end

  def busy_with?(name, adu) when is_struct(adu, ADU) and is_valid_unit_id(adu.unit_id) do
    GenServer.call(name, {:busy_with?, adu})
  end

  def will_respond(name, to, adu, timeout)
      when is_struct(adu, ADU) and is_valid_unit_id(adu.unit_id) do
    GenServer.call(name, {:will_respond, to, adu, timeout})
  end

  def start_link(args) do
    client_name = Keyword.fetch!(args, :client_name)
    GenServer.start_link(__MODULE__, args, name: name(client_name))
  end

  def init(_args) do
    {:ok,
     %{
       callers: List.duplicate(nil, @unit_id_max + 1),
       binary: <<>>
     }}
  end

  def handle_call({:busy_with?, adu}, _from, state) do
    %{callers: callers} = state

    caller = Enum.fetch!(callers, adu.unit_id)

    {:reply, not is_nil(caller), state}
  end

  def handle_call({:will_respond, to, adu, timeout}, _from, state) do
    %{callers: callers} = state

    caller = Enum.fetch!(callers, adu.unit_id)

    if is_nil(caller) do
      Process.send_after(self(), {:no_response?, adu}, timeout)

      callers = List.replace_at(callers, adu.unit_id, to)
      {:reply, :ok, %{state | callers: callers}}
    else
      {:ok, req} = PDU.decode_request(adu.pdu)
      err = PDU.to_error(req, @server_device_busy)
      GenServer.reply(to, {:error, err})

      {:noreply, state}
    end
  end

  def handle_info({:no_response?, adu}, state) do
    %{callers: callers} = state

    caller = Enum.fetch!(callers, adu.unit_id)

    if is_nil(caller) do
      # already responded
      {:noreply, state}
    else
      # something wrong, treat as server failure
      {:ok, req} = PDU.decode_request(adu.pdu)
      err = PDU.to_error(req, @server_device_failure)
      GenServer.reply(caller, {:error, err})

      callers = List.replace_at(callers, adu.unit_id, nil)
      {:noreply, %{state | callers: callers, binary: <<>>}}
    end
  end

  def handle_info({:circuits_uart, _device_name, binary}, state) do
    %{callers: callers} = state

    new_binary = state.binary <> binary

    # NOTE: unit_id: 1, functions_code: 1, crc: 2, so at least 4 bytes
    with true <- byte_size(new_binary) > 4 || {:error, :binary_is_short},
         {:ok, %ADU{unit_id: unit_id, pdu: pdu}} <- ADU.decode_response(new_binary) do
      res_tuple = PDU.decode_response(pdu)

      caller = Enum.fetch!(callers, unit_id)
      if not is_nil(caller), do: GenServer.reply(caller, res_tuple)

      callers = List.replace_at(callers, unit_id, nil)
      {:noreply, %{state | callers: callers, binary: <<>>}}
    else
      {:error, :binary_is_short} ->
        {:noreply, %{state | binary: new_binary}}

      {:error, %ADU{unit_id: unit_id, pdu: _pdu, crc_valid?: false}} ->
        caller = Enum.fetch!(callers, unit_id)
        if not is_nil(caller), do: GenServer.reply(caller, {:error, :crc_error})

        callers = List.replace_at(callers, unit_id, nil)
        {:noreply, %{state | callers: callers, binary: <<>>}}
    end
  end
end
