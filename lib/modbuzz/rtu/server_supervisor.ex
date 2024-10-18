defmodule Modbuzz.RTU.ServerSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @doc false
  def init(args) do
    children = [
      {Modbuzz.RTU.Server, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
