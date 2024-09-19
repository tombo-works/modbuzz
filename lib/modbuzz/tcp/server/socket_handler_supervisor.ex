defmodule Modbuzz.TCP.Server.SocketHandlerSupervisor do
  @moduledoc false

  @doc false
  def name(address, port) do
    {:via, Registry, {Modbuzz.Registry, {__MODULE__, address, port}}}
  end

  @doc false
  def start_socket_handler(transport, socket, address, port, data_source) do
    DynamicSupervisor.start_child(
      name(address, port),
      {Modbuzz.TCP.Server.SocketHandler,
       [
         transport: transport,
         socket: socket,
         address: address,
         port: port,
         data_source: data_source
       ]}
    )
  end
end
