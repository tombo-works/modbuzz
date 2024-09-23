defmodule Modbuzz.Data.ServerSupervisor do
  @moduledoc false

  use Supervisor

  @doc false
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @doc false
  def init(args) do
    server_name = Keyword.fetch!(args, :name)

    children = [
      {
        PartitionSupervisor,
        child_spec: Task.Supervisor, name: Modbuzz.Data.CallbackSupervisor.name(server_name)
      },
      {
        DynamicSupervisor,
        name: Modbuzz.Data.UnitSupervisor.name(server_name), strategy: :one_for_one
      },
      {Modbuzz.Data.Server, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
