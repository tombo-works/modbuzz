defmodule Modbuzz.Data.ServerSupervisor do
  @moduledoc false

  use Supervisor

  def name(name) do
    {:via, Registry, {Modbuzz.Registry, {name, __MODULE__}}}
  end

  @doc false
  def start_link(args) do
    via_name = Keyword.fetch!(args, :via_name)
    Supervisor.start_link(__MODULE__, args, name: via_name)
  end

  @doc false
  def init(args) do
    {via_name, args} = Keyword.pop!(args, :via_name)
    {:via, Registry, {Modbuzz.Registry, {name, __MODULE__}}} = via_name

    children = [
      {
        PartitionSupervisor,
        name: Modbuzz.Data.CallbackSupervisor.name(name), child_spec: Task.Supervisor
      },
      {
        DynamicSupervisor,
        name: Modbuzz.Data.UnitSupervisor.name(name), strategy: :one_for_one
      },
      {
        Modbuzz.Data.Server,
        name: name, args: args
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
