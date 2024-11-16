defmodule Modbuzz.Data.Unit do
  @moduledoc false

  use Agent

  def get(pid, request) when is_pid(pid) do
    Agent.get(pid, fn state -> Map.get(state, request) end)
  end

  def get({atom, node}, request) do
    Agent.get({atom, node}, fn state -> Map.get(state, request) end)
  end

  def upsert(pid, request, response) when is_pid(pid) do
    Agent.update(pid, fn state -> Map.put(state, request, response) end)
  end

  def upsert({atom, node}, request, response) do
    Agent.update({atom, node}, fn state -> Map.put(state, request, response) end)
  end

  def delete(pid, request) when is_pid(pid) do
    Agent.update(pid, fn state -> Map.delete(state, request) end)
  end

  def delete({atom, node}, request) do
    Agent.update({atom, node}, fn state -> Map.delete(state, request) end)
  end

  def dump(pid) when is_pid(pid) do
    Agent.get(pid, fn state -> state end)
  end

  def dump({atom, node}) do
    Agent.get({atom, node}, fn state -> state end)
  end

  def name(server_name, unit_id) do
    {:via, Registry, {Modbuzz.Registry, {server_name, __MODULE__, unit_id}}}
  end

  def start_link(args) do
    server_name = Keyword.fetch!(args, :server_name)
    unit_id = Keyword.fetch!(args, :unit_id)

    Agent.start_link(fn -> _initial_state = %{} end, name: name(server_name, unit_id))
  end
end
