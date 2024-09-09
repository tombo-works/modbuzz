defmodule Modbuzz.TCP.Server.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    children = [
      {Registry, keys: :unique, name: Modbuzz.TCP.Server.Registry},
      {DynamicSupervisor, name: Modbuzz.TCP.Server.DataStoreSupervisor, strategy: :one_for_one},
      {Modbuzz.TCP.Server.DataStoreOperator, args},
      {DynamicSupervisor,
       name: Modbuzz.TCP.Server.SocketHandlerSupervisor, strategy: :one_for_one},
      {Modbuzz.TCP.Server, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
