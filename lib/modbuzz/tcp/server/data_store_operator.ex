defmodule Modbuzz.TCP.Server.DataStoreOperator do
  @moduledoc false

  use GenServer

  def name(address, port) do
    host = Modbuzz.TCP.Server.hostname()
    name(host, address, port)
  end

  def name(host, address, port) do
    {:global, {__MODULE__, host, address, port}}
  end

  def start_link(args) do
    host = Keyword.fetch!(args, :host)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    GenServer.start_link(__MODULE__, args, name: name(host, address, port))
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
    host = Keyword.fetch!(args, :host)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)

    {:ok,
     %{
       host: host,
       address: address,
       port: port
     }}
  end

  def handle_call({:upsert, unit_id, request, response}, _from, state) do
    %{host: host, address: address, port: port} = state
    name = Modbuzz.TCP.Server.DataStore.name(host, address, port, unit_id)

    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        Agent.update(pid, fn map -> Map.put(map, request, response) end)

      {atom, node} ->
        Agent.update({atom, node}, fn map -> Map.put(map, request, response) end)

      nil ->
        Modbuzz.TCP.Server.DataStoreSupervisor.start_data_store(host, address, port, unit_id, %{
          request => response
        })
    end

    {:reply, :ok, state}
  end

  def handle_call({:delete, unit_id, request}, _from, state) do
    %{host: host, address: address, port: port} = state
    name = Modbuzz.TCP.Server.DataStore.name(host, address, port, unit_id)

    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        Agent.update(pid, fn map -> Map.delete(map, request) end)

      {atom, node} ->
        Agent.update({atom, node}, fn map -> Map.delete(map, request) end)

      nil ->
        Modbuzz.TCP.Server.DataStoreSupervisor.start_data_store(host, address, port, unit_id, %{})
    end

    {:reply, :ok, state}
  end
end
