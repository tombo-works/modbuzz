defmodule Modbuzz.TCP.Server.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    modbuzz_tcp_server_args = Keyword.get(args, :modbuzz_tcp_server_args, [])

    children = [
      {Registry, keys: :unique, name: Modbuzz.TCP.Server.Registry},
      {DynamicSupervisor, name: Modbuzz.TCP.Server.DataStoreSupervisor, strategy: :one_for_one},
      {Modbuzz.TCP.Server.DataStoreOperator, modbuzz_tcp_server_args},
      {DynamicSupervisor,
       name: Modbuzz.TCP.Server.SocketHandlerSupervisor, strategy: :one_for_one},
      {Modbuzz.TCP.Server, modbuzz_tcp_server_args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
