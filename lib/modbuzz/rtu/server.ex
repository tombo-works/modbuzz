defmodule Modbuzz.RTU.Server do
  @moduledoc false

  use GenServer

  alias Modbuzz.RTU.ADU
  alias Modbuzz.RTU.Log

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc false
  def init(args) do
    transport = Keyword.get(args, :transport, Circuits.UART)
    transport_opts = Keyword.get(args, :transport_opts, []) ++ [active: true]
    device_name = Keyword.fetch!(args, :device_name)
    data_source = Keyword.fetch!(args, :data_source)
    timeout = Keyword.get(args, :timeout, 5000)

    {:ok, transport_pid} = transport.start_link([])
    :ok = transport.open(transport_pid, device_name, transport_opts)

    {:ok,
     %{
       transport: transport,
       transport_opts: transport_opts,
       device_name: device_name,
       data_source: data_source,
       timeout: timeout,
       transport_pid: transport_pid,
       binary: <<>>
     }}
  end

  def handle_info({:circuits_uart, _device_name, binary}, state) do
    %{
      transport: transport,
      transport_pid: transport_pid,
      data_source: data_source
    } = state

    new_binary = state.binary <> binary

    case ADU.decode_request(new_binary) do
      {:ok, %ADU{unit_id: unit_id, pdu: pdu}} ->
        request(data_source, unit_id, pdu)
        |> Modbuzz.RTU.ADU.new(unit_id)
        |> Modbuzz.RTU.ADU.encode()
        |> then(&transport.write(transport_pid, &1))

        {:noreply, %{state | binary: <<>>}}

      {:error, :binary_is_short} ->
        {:noreply, %{state | binary: new_binary}}

      {:error, :unknown} ->
        Log.error("Failed to decode ADU, unknown binary format.", nil, state)
        {:noreply, %{state | binary: <<>>}}

      {:error, :binary_is_long} ->
        Log.error("Failed to decode ADU, binary is too long.", nil, state)
        {:noreply, %{state | binary: <<>>}}

      {:error, %ADU{unit_id: _unit_id, crc_valid?: false} = adu} ->
        Log.warning("CRC error detected, #{inspect(adu)}.", nil, state)
        {:noreply, %{state | binary: <<>>}}
    end
  end

  defp request(data_source, unit_id, request) do
    case GenServer.call(data_source, {:call, unit_id, request, 5000}) do
      {:ok, response} -> response
      {:error, error} -> error
    end
  end
end
