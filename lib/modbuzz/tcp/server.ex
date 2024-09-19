defmodule Modbuzz.TCP.Server do
  @moduledoc """
  This is MODBUS TCP server `GenServer` module.
  """

  use GenServer

  require Logger

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.fetch!(args, :name)

    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc false
  def init(args) do
    transport = Keyword.get(args, :transport, :gen_tcp)
    name = Keyword.fetch!(args, :name)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    data_source = Keyword.fetch!(args, :data_source)

    {:ok,
     %{
       transport: transport,
       name: name,
       address: address,
       port: port,
       active: false,
       listen_socket: nil,
       data_source: data_source
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
      address: address,
      port: port,
      data_source: data_source
    } = state

    case transport.accept(listen_socket) do
      {:ok, socket} ->
        Modbuzz.TCP.Server.SocketHandlerSupervisor.start_socket_handler(
          transport,
          socket,
          address,
          port,
          data_source
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
