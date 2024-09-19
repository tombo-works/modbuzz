defmodule Modbuzz.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Modbuzz.Registry},
      {DynamicSupervisor, name: data_server_supervisor_name(), strategy: :one_for_one},
      {DynamicSupervisor, name: server_supervisor_name(), strategy: :one_for_one},
      {DynamicSupervisor, name: client_supervisor_name(), strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc false
  def data_server_supervisor_name(), do: Modbuzz.DataServerSupervisor

  @doc false
  def server_supervisor_name(), do: Modbuzz.ServerSupervisor

  @doc false
  def client_supervisor_name(), do: Modbuzz.ClientSupervisor
end
