defmodule Modbuzz.TCP.Server do
  @moduledoc false

  use GenServer

  alias Modbuzz.TCP.Log
  alias Modbuzz.TCP.Server.SocketHandlerSupervisor

  @doc false
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc false
  def init(args) do
    name = Keyword.fetch!(args, :name)
    args = Keyword.fetch!(args, :args)

    transport = Keyword.get(args, :transport, :gen_tcp)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    data_source = Keyword.fetch!(args, :data_source)

    {:ok,
     %{
       name: name,
       transport: transport,
       address: address,
       port: port,
       listen_socket: nil,
       data_source: data_source
     }, {:continue, :listen}}
  end

  @doc false
  def handle_continue(:listen, state) do
    case listen(state) do
      {:ok, socket} ->
        {:noreply, %{state | listen_socket: socket}, {:continue, :accept}}

      {:error, reason} ->
        Log.error(":listen failed", reason, state)
        {:noreply, state, {:continue, :listen}}
    end
  end

  def handle_continue(:accept, state) do
    %{
      name: name,
      transport: transport,
      listen_socket: listen_socket,
      address: address,
      port: port,
      data_source: data_source
    } = state

    case transport.accept(listen_socket) do
      {:ok, socket} ->
        case SocketHandlerSupervisor.start_socket_handler(
               name,
               transport,
               address,
               port,
               data_source,
               socket
             ) do
          {:ok, pid} ->
            with :ok <- transport.controlling_process(socket, pid),
                 :ok <- set_active_once(transport, socket) do
              :ok
            else
              {:error, reason} ->
                Log.error(":accept child setup failed", reason, state)
                :ok = transport.close(socket)
                :ok = SocketHandlerSupervisor.stop_socket_handler(name, pid)
            end

          :ignore ->
            Log.warning(":accept child start ignored", nil, state)
            :ok = transport.close(socket)

          {:error, reason} ->
            Log.error(":accept child start failed", reason, state)
            :ok = transport.close(socket)
        end

      {:error, reason} ->
        Log.error(":accept failed", reason, state)
    end

    {:noreply, state, {:continue, :accept}}
  end

  defp listen(state) do
    %{transport: transport, address: address, port: port} = state

    transport.listen(port,
      ip: address,
      mode: :binary,
      packet: :raw,
      active: false,
      backlog: 1024,
      keepalive: true,
      nodelay: true,
      send_timeout: 30_000,
      send_timeout_close: true,
      reuseaddr: true
    )
  end

  defp set_active_once(:gen_tcp, socket), do: :inet.setopts(socket, active: :once)
  defp set_active_once(transport, socket), do: transport.setopts(socket, active: :once)
end
