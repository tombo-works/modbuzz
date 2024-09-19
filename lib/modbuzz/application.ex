defmodule Modbuzz.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DynamicSupervisor, name: Modbuzz.ClientsSupervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
