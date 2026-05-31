defmodule Modbuzz.TCP.Server.SocketHandler do
  @moduledoc false

  use GenServer, restart: :temporary

  alias Modbuzz.TCP.ADU
  alias Modbuzz.TCP.Log

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    transport = Keyword.fetch!(args, :transport)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    socket = Keyword.fetch!(args, :socket)
    data_source = Keyword.fetch!(args, :data_source)
    timeout = Keyword.get(args, :timeout, 5000)

    {:ok,
     %{
       transport: transport,
       address: address,
       port: port,
       socket: socket,
       data_source: data_source,
       timeout: timeout,
       binary: <<>>
     }, {:continue, :recv}}
  end

  def handle_continue(:recv, state) do
    %{
      transport: transport,
      socket: socket,
      data_source: data_source,
      timeout: timeout
    } = state

    case transport.recv(socket, _length = 0, timeout) do
      {:ok, binary} ->
        binary = state.binary <> binary

        case ADU.decode_request(binary, []) do
          {:ok, {adu_tuples, rest_binary}} ->
            response_binary =
              Enum.reduce(adu_tuples, <<>>, fn {:ok, adu}, acc ->
                response_pdu_or_nil = request(data_source, adu.unit_id, adu.pdu, timeout)
                acc <> to_adu_binary(response_pdu_or_nil, adu.transaction_id, adu.unit_id)
              end)

            if response_binary != <<>>, do: transport.send(socket, response_binary)

            {:noreply, %{state | binary: rest_binary}, {:continue, :recv}}

          {:error, reason} ->
            Log.error("decode error", reason, state)
            :ok = transport.close(socket)
            {:stop, reason, state}
        end

      {:error, reason} ->
        Log.error("#{inspect(transport)} recv error", reason, state)
        :ok = transport.close(socket)
        {:stop, reason, state}
    end
  end

  defp request(data_source, unit_id, request, timeout) do
    case GenServer.call(data_source, {:call, unit_id, request, timeout}, timeout + 50) do
      {:ok, pdu} when is_struct(pdu) -> pdu
      {:error, pdu} when is_struct(pdu) -> pdu
      {:error, _reason} -> nil
    end
  end

  defp to_adu_binary(pdu, transaction_id, unit_id) do
    case pdu do
      pdu when is_struct(pdu) ->
        ADU.new(pdu, transaction_id, unit_id) |> ADU.encode()

      nil ->
        <<>>
    end
  end
end
