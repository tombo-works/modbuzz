defmodule Modbuzz.TCP.Server.SocketHandlerSupervisor do
  @moduledoc false

  @doc false
  def name(name) do
    {:via, Registry, {Modbuzz.Registry, {name, __MODULE__}}}
  end

  @doc false
  def start_socket_handler(name, transport, address, port, data_source, socket) do
    DynamicSupervisor.start_child(
      name(name),
      {Modbuzz.TCP.Server.SocketHandler,
       [
         transport: transport,
         address: address,
         port: port,
         data_source: data_source,
         socket: socket
       ]}
    )
  end
end
