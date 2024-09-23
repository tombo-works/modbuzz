defmodule Modbuzz.Data.Server do
  @moduledoc false

  use GenServer

  import Modbuzz, only: [is_unit_id: 1]

  @spec upsert(
          GenServer.name(),
          Modbuzz.unit_id(),
          Modbuzz.request(),
          Modbuzz.response() | Modbuzz.callback()
        ) :: :ok
  def upsert(name, unit_id \\ 0, request, res_or_cb) when is_unit_id(unit_id) do
    GenServer.call(name, {:upsert, unit_id, request, res_or_cb})
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

  def handle_call({:call, unit_id, request, _timeout}, from, state) do
    %{name: name} = state

    unit_name = Modbuzz.Data.Unit.name(name, unit_id)

    res_or_cb =
      case GenServer.whereis(unit_name) do
        pid when is_pid(pid) ->
          Modbuzz.Data.Unit.get(pid, request)

        {atom, node} ->
          Modbuzz.Data.Unit.get({atom, node}, request)

        nil ->
          initial_data = %{}
          Modbuzz.Data.UnitSupervisor.start_unit(name, unit_id, initial_data)
          nil
      end

    case res_or_cb do
      response when is_struct(response) ->
        {:reply, {:ok, response}, state}

      nil ->
        {:reply, {:error, Modbuzz.PDU.to_error(request)}, state}

      callback when is_function(callback) ->
        Task.Supervisor.start_child(
          {:via, PartitionSupervisor, {Modbuzz.Data.CallbackSupervisor.name(name), self()}},
          fn -> GenServer.reply(from, {:ok, callback.(request)}) end
        )

        {:noreply, state}
    end
  end

  def handle_call({:upsert, unit_id, request, res_or_cb}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    case GenServer.whereis(unit_name) do
      pid when is_pid(pid) ->
        :ok = Modbuzz.Data.Unit.upsert(pid, request, res_or_cb)

      {atom, node} ->
        :ok = Modbuzz.Data.Unit.upsert({atom, node}, request, res_or_cb)

      nil ->
        initial_data = %{request => res_or_cb}
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
