defmodule Modbuzz.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Modbuzz.Registry},
      {DynamicSupervisor, name: data_server_dynamic_supervisor_name(), strategy: :one_for_one},
      {DynamicSupervisor, name: server_dynamic_supervisor_name(), strategy: :one_for_one},
      {DynamicSupervisor, name: client_dynamic_supervisor_name(), strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc false
  def data_server_dynamic_supervisor_name(), do: Modbuzz.DataServerDynamicSupervisor

  @doc false
  def server_dynamic_supervisor_name(), do: Modbuzz.ServerDynamicSupervisor

  @doc false
  def client_dynamic_supervisor_name(), do: Modbuzz.ClientDynamicSupervisor
end
