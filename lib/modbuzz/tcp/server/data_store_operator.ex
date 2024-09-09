defmodule Modbuzz.TCP.Server.DataStoreOperator do
  @moduledoc false

  use GenServer

  def name(address, port) do
    {:via, Registry, {Modbuzz.TCP.Server.Registry, {address, port, :data_store_operator}}}
  end

  def start_link(args) do
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    name = name(address, port)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def upsert(address, port, unit_id \\ 0, request, response) do
    name = name(address, port)
    GenServer.call(name, {:upsert, unit_id, request, response})
  end

  def delete(address, port, unit_id \\ 0, request) do
    name = name(address, port)
    GenServer.call(name, {:delete, unit_id, request})
  end

  def init(args) do
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)

    {:ok,
     %{
       address: address,
       port: port
     }}
  end

  def handle_call({:upsert, unit_id, request, response}, _from, state) do
    %{address: address, port: port} = state
    name = Modbuzz.TCP.Server.DataStore.name(address, port, unit_id)

    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        Agent.update(pid, fn map -> Map.put(map, request, response) end)

      {atom, node} ->
        Agent.update({atom, node}, fn map -> Map.put(map, request, response) end)

      nil ->
        DynamicSupervisor.start_child(
          Modbuzz.TCP.Server.DataStoreSupervisor,
          {Modbuzz.TCP.Server.DataStore, name: name, state: %{request => response}}
        )
    end

    {:reply, :ok, state}
  end

  def handle_call({:delete, unit_id, request}, _from, state) do
    %{address: address, port: port} = state
    name = Modbuzz.TCP.Server.DataStore.name(address, port, unit_id)

    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        Agent.update(pid, fn map -> Map.delete(map, request) end)

      {atom, node} ->
        Agent.update({atom, node}, fn map -> Map.delete(map, request) end)

      nil ->
        DynamicSupervisor.start_child(
          Modbuzz.TCP.Server.DataStoreSupervisor,
          {Modbuzz.TCP.Server.DataStore, name: name, state: %{}}
        )
    end

    {:reply, :ok, state}
  end
end
