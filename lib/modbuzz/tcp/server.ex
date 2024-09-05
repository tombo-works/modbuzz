defmodule Modbuzz.TCP.Server do
  @moduledoc """
  This is MODBUS TCP server `GenServer` module.
  """

  use GenServer

  require Logger

  defdelegate upsert(address, port, unit_id \\ 0, request, response),
    to: Modbuzz.TCP.Server.DataStoreOperator

  defdelegate delete(address, port, unit_id \\ 0, request),
    to: Modbuzz.TCP.Server.DataStoreOperator

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    transport = Keyword.get(args, :transport, :gen_tcp)
    address = Keyword.get(args, :address, {0, 0, 0, 0})
    port = Keyword.get(args, :port, 502)
    active = Keyword.get(args, :active, false)

    {:ok,
     %{
       transport: transport,
       address: address,
       port: port,
       active: active,
       listen_socket: nil
     }, {:continue, :listen}}
  end

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
      address: address,
      port: port
    } = state

    case transport.accept(listen_socket) do
      {:ok, socket} ->
        DynamicSupervisor.start_child(
          Modbuzz.TCP.Server.SocketHandlerSupervisor,
          {Modbuzz.TCP.Server.SocketHandler,
           [transport: transport, socket: socket, address: address, port: port]}
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
