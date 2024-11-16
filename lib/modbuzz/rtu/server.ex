defmodule Modbuzz.RTU.Server do
  @moduledoc false

  use GenServer

  alias Modbuzz.PDU
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
       transport_pid: transport_pid,
       data_source: data_source,
       timeout: timeout,
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

    # NOTE: unit_id: 1, functions_code: 1, crc: 2, so at least 4 bytes
    with true <- byte_size(new_binary) > 4 || {:error, :binary_is_short},
         {:ok, %ADU{unit_id: unit_id, pdu: pdu}} <- ADU.decode_request(new_binary) do
      {:ok, request} = PDU.decode_request(pdu)

      request(data_source, unit_id, request)
      |> Modbuzz.PDU.encode_response!()
      |> Modbuzz.RTU.ADU.new(unit_id)
      |> Modbuzz.RTU.ADU.encode()
      |> then(&transport.write(transport_pid, &1))

      {:noreply, %{state | binary: <<>>}}
    else
      {:error, :binary_is_short} ->
        {:noreply, %{state | binary: new_binary}}

      {:error, %ADU{unit_id: _unit_id, pdu: _pdu, crc_valid?: false} = adu} ->
        Log.warning("CRC error detected, #{inspect(adu)}.")
        # ignore request
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
