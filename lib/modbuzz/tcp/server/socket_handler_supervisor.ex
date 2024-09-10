defmodule Modbuzz.TCP.Server.SocketHandlerSupervisor do
  @moduledoc false

  @doc false
  def name(host, address, port) do
    {:global, {__MODULE__, host, address, port}}
  end

  @doc false
  def start_socket_handler(transport, socket, host, address, port) do
    DynamicSupervisor.start_child(
      name(host, address, port),
      {Modbuzz.TCP.Server.SocketHandler,
       [transport: transport, socket: socket, host: host, address: address, port: port]}
    )
  end
end
