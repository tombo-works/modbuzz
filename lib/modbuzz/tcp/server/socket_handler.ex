defmodule Modbuzz.TCP.Server.SocketHandler do
  @moduledoc false

  use GenServer, restart: :temporary

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
       timeout: timeout
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
        for adu <- Modbuzz.TCP.ADU.decode(binary, []) do
          {:ok, request} = Modbuzz.PDU.decode_request(adu.pdu)

          request(data_source, adu.unit_id, request, timeout)
          |> Modbuzz.PDU.encode()
          |> Modbuzz.TCP.ADU.new(adu.transaction_id, adu.unit_id)
          |> Modbuzz.TCP.ADU.encode()
        end
        |> Enum.reduce(<<>>, &(&2 <> &1))
        |> then(&transport.send(socket, &1))

        {:noreply, state, {:continue, :recv}}

      {:error, :closed = reason} ->
        :ok = transport.close(socket)
        {:stop, reason, state}

      {:error, reason} ->
        Log.error(":recv failed", reason, state)
        :ok = transport.close(socket)
        {:stop, reason, state}
    end
  end

  defp request(data_source, unit_id, request, timeout) do
    try do
      case GenServer.call(data_source, {:call, unit_id, request, timeout}) do
        {:ok, response} -> response
        {:error, error} -> error
      end
    catch
      :exit, {:noproc, mfa} ->
        Log.error("`#{data_source}` not found. (mfa is #{inspect(mfa)})")
        Modbuzz.PDU.to_error(request)
    end
  end
end
