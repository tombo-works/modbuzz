defmodule Modbuzz.TCP.Server.SocketHandler do
  use GenServer, restart: :temporary

  require Logger

  @illegal_data_address 0x02

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    transport = Keyword.fetch!(args, :transport)
    socket = Keyword.fetch!(args, :socket)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    timeout = Keyword.get(args, :timeout, 5000)

    {:ok,
     %{
       transport: transport,
       socket: socket,
       timeout: timeout,
       address: address,
       port: port
     }, {:continue, :recv}}
  end

  def handle_continue(:recv, state) do
    %{
      transport: transport,
      socket: socket,
      timeout: timeout,
      address: address,
      port: port
    } = state

    case transport.recv(socket, _length = 0, timeout) do
      {:ok, binary} ->
        for adu <- Modbuzz.TCP.ADU.decode(binary, []) do
          {:ok, request} = Modbuzz.PDU.decode_request(adu.pdu)

          Modbuzz.TCP.Server.DataStore.name(address, port, adu.unit_id)
          |> get_from_data_store(request)
          |> Modbuzz.PDU.encode_response!()
          |> Modbuzz.TCP.ADU.new(adu.transaction_id, adu.unit_id)
          |> Modbuzz.TCP.ADU.encode()
        end
        |> Enum.reduce(<<>>, &(&2 <> &1))
        |> then(&transport.send(socket, &1))

        {:noreply, state, {:continue, :recv}}

      {:error, reason} ->
        Logger.error("#{__MODULE__}: #{inspect(reason)}")
        :ok = transport.close(socket)
        {:stop, reason, state}
    end
  end

  defp get_from_data_store(name, request) do
    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        case Agent.get(pid, fn map -> Map.get(map, request) end) do
          nil -> error(request)
          response -> response
        end

      {atom, node} ->
        case Agent.get({atom, node}, fn map -> Map.get(map, request) end) do
          nil -> error(request)
          response -> response
        end

      nil ->
        error(request)
    end
  end

  defp error(%req{}, exception_code \\ @illegal_data_address) do
    Module.split(req)
    |> List.replace_at(-1, "Err")
    |> Module.concat()
    |> struct(%{exception_code: exception_code})
  end
end
