defmodule Modbuzz.Data.Server do
  @moduledoc false

  use GenServer

  import Modbuzz, only: [is_unit_id: 1]

  @spec upsert(GenServer.name(), Modbuzz.unit_id(), Modbuzz.request(), Modbuzz.response()) :: :ok
  def upsert(name, unit_id \\ 0, request, response) when is_unit_id(unit_id) do
    GenServer.call(name, {:upsert, unit_id, request, response})
  end

  @spec delete(GenServer.name(), Modbuzz.unit_id(), Modbuzz.request()) :: :ok
  def delete(name, unit_id \\ 0, request) when is_unit_id(unit_id) do
    GenServer.call(name, {:delete, unit_id, request})
  end

  @spec dump(GenServer.name(), Modbuzz.unit_id()) :: map()
  def dump(name, unit_id \\ 0) when is_unit_id(unit_id) do
    GenServer.call(name, {:dump, unit_id})
  end

  def start_link(args) do
    name = Keyword.fetch!(args, :name)

    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    name = Keyword.fetch!(args, :name)

    {:ok, %{name: name}}
  end

  def handle_call({:call, unit_id, request, _timeout}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    response =
      case GenServer.whereis(unit_name) do
        pid when is_pid(pid) ->
          Modbuzz.Data.Unit.get(pid, request)

        {atom, node} ->
          Modbuzz.Data.Unit.get({atom, node}, request)

        nil ->
          initial_data = %{}
          Modbuzz.Data.UnitSupervisor.start_unit(state.name, unit_id, initial_data)
          nil
      end

    return =
      case response do
        response when is_struct(response) -> {:ok, response}
        nil -> {:error, Modbuzz.PDU.to_error(request)}
      end

    {:reply, return, state}
  end

  def handle_call({:upsert, unit_id, request, response}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    case GenServer.whereis(unit_name) do
      pid when is_pid(pid) ->
        :ok = Modbuzz.Data.Unit.upsert(pid, request, response)

      {atom, node} ->
        :ok = Modbuzz.Data.Unit.upsert({atom, node}, request, response)

      nil ->
        initial_data = %{request => response}
        {:ok, _pid} = Modbuzz.Data.UnitSupervisor.start_unit(state.name, unit_id, initial_data)
    end

    {:reply, :ok, state}
  end

  def handle_call({:delete, unit_id, request}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    case GenServer.whereis(unit_name) do
      pid when is_pid(pid) ->
        :ok = Modbuzz.Data.Unit.delete(pid, request)

      {atom, node} ->
        :ok = Modbuzz.Data.Unit.delete({atom, node}, request)

      nil ->
        initial_data = %{}
        {:ok, _pid} = Modbuzz.Data.UnitSupervisor.start_unit(state.name, unit_id, initial_data)
    end

    {:reply, :ok, state}
  end

  def handle_call({:dump, unit_id}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    data =
      case GenServer.whereis(unit_name) do
        pid when is_pid(pid) ->
          Modbuzz.Data.Unit.dump(pid)

        {atom, node} ->
          Modbuzz.Data.Unit.dump({atom, node})

        nil ->
          initial_data = %{}
          {:ok, pid} = Modbuzz.Data.UnitSupervisor.start_unit(state.name, unit_id, initial_data)
          Modbuzz.Data.Unit.dump(pid)
      end

    {:reply, data, state}
  end
end
