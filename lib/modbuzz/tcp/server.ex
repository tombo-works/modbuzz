defmodule Modbuzz.TCP.Server do
  @moduledoc """
  This is MODBUS TCP server `GenServer` module.
  """

  use GenServer

  require Logger

  @doc """
  This function handles the upsert (insert or update) of a response in the server, based on the provided request.
  If a matching response for the request already exists, it will be updated;
  otherwise, a new response entry will be inserted.
  """
  @spec upsert(
          address :: :inet.socket_address(),
          port :: :inet.port_number(),
          unit_id :: non_neg_integer(),
          request :: struct(),
          response :: struct()
        ) :: :ok
  defdelegate upsert(address, port, unit_id \\ 0, request, response),
    to: Modbuzz.TCP.Server.DataStoreOperator

  @doc """
  This function handles the delete of a response in the server, based on the provided request.
  If a matching response for the request already exists, it will be deleted.
  """
  @spec delete(
          address :: :inet.socket_address(),
          port :: :inet.port_number(),
          unit_id :: non_neg_integer(),
          request :: struct()
        ) :: :ok
  defdelegate delete(address, port, unit_id \\ 0, request),
    to: Modbuzz.TCP.Server.DataStoreOperator

  @doc false
  @spec hostname() :: String.t()
  def hostname() do
    :inet.gethostname() |> then(fn {:ok, hostname} -> "#{hostname}" end)
  end

  @doc false
  def name(host, address, port) do
    {:global, {__MODULE__, host, address, port}}
  end

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    host = Keyword.fetch!(args, :host)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    GenServer.start_link(__MODULE__, args, name: name(host, address, port))
  end

  @doc false
  def init(args) do
    transport = Keyword.get(args, :transport, :gen_tcp)
    host = Keyword.fetch!(args, :host)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    active = Keyword.get(args, :active, false)

    {:ok,
     %{
       transport: transport,
       host: host,
       address: address,
       port: port,
       active: active,
       listen_socket: nil
     }, {:continue, :listen}}
  end

  @doc false
  def handle_continue(:listen, state) do
    case gen_tcp_listen(state) do
      {:ok, socket} ->
        {:noreply, %{state | listen_socket: socket}, {:continue, :accept}}

      {:error, reason} ->
        Logger.error("#{__MODULE__}: :listen failed, the reason is #{inspect(reason)}.")
        {:noreply, state, {:continue, :listen}}
    end
  end

  def handle_continue(:accept, state) do
    %{
      transport: transport,
      listen_socket: listen_socket,
      host: host,
      address: address,
      port: port
    } = state

    case transport.accept(listen_socket) do
      {:ok, socket} ->
        Modbuzz.TCP.Server.SocketHandlerSupervisor.start_socket_handler(
          transport,
          socket,
          host,
          address,
          port
        )

      {:error, reason} ->
        Logger.error("#{__MODULE__}: #{inspect(reason)}")
    end

    {:noreply, state, {:continue, :accept}}
  end

  defp gen_tcp_listen(state) do
    %{transport: transport, address: address, port: port, active: active} = state
    transport.listen(port, ip: address, mode: :binary, packet: :raw, active: active)
  end
end
