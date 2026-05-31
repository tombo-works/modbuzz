defmodule Modbuzz.Data.Server do
  @moduledoc false

  use GenServer

  import Modbuzz, only: [is_unit_id: 1]

  @spec create_unit(Modbuzz.data_server(), Modbuzz.unit_id()) :: :ok | {:error, :already_created}
  def create_unit(name, unit_id) do
    GenServer.call(name, {:create_unit, unit_id})
  end

  @spec upsert(
          Modbuzz.data_server(),
          Modbuzz.unit_id(),
          Modbuzz.request(),
          Modbuzz.response() | Modbuzz.callback()
        ) :: :ok | {:error, :unit_not_found}
  def upsert(name, unit_id \\ 0, request, res_or_cb) when is_unit_id(unit_id) do
    GenServer.call(name, {:upsert, unit_id, request, res_or_cb})
  end

  @spec delete(Modbuzz.data_server(), Modbuzz.unit_id(), Modbuzz.request()) ::
          :ok | {:error, :unit_not_found}
  def delete(name, unit_id \\ 0, request) when is_unit_id(unit_id) do
    GenServer.call(name, {:delete, unit_id, request})
  end

  @spec dump(Modbuzz.data_server(), Modbuzz.unit_id()) :: {:ok, map()} | {:error, :unit_not_found}
  def dump(name, unit_id \\ 0) when is_unit_id(unit_id) do
    GenServer.call(name, {:dump, unit_id})
  end

  def start_link(args) do
    name = Keyword.fetch!(args, :name)

    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    name = Keyword.fetch!(args, :name)

    {:ok, %{name: name, async_reqs: %{}}}
  end

  def handle_call({:call, unit_id, request, _timeout}, from, state) do
    %{name: name} = state
    res_or_cb = get_res_or_cb(name, unit_id, request)

    case res_or_cb do
      response when is_struct(response) ->
        {:reply, {:ok, response}, state}

      callback when is_function(callback) ->
        Task.Supervisor.start_child(
          {:via, PartitionSupervisor, {Modbuzz.Data.CallbackSupervisor.name(name), self()}},
          fn -> GenServer.reply(from, {:ok, callback.(request)}) end
        )

        {:noreply, state}

      nil ->
        {:noreply, state}
    end
  end

  def handle_call({:create_unit, unit_id}, _from, state) do
    case Modbuzz.Data.UnitSupervisor.create_unit(state.name, unit_id) do
      {:ok, _pid} -> {:reply, :ok, state}
      {:error, {:already_started, _pid}} -> {:reply, {:error, :already_created}, state}
    end
  end

  def handle_call({:upsert, unit_id, request, res_or_cb}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    case GenServer.whereis(unit_name) do
      pid when is_pid(pid) ->
        :ok = Modbuzz.Data.Unit.upsert(pid, request, res_or_cb)
        {:reply, :ok, state}

      {atom, node} ->
        :ok = Modbuzz.Data.Unit.upsert({atom, node}, request, res_or_cb)
        {:reply, :ok, state}

      nil ->
        {:reply, {:error, :unit_not_found}, state}
    end
  end

  def handle_call({:delete, unit_id, request}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    case GenServer.whereis(unit_name) do
      pid when is_pid(pid) ->
        :ok = Modbuzz.Data.Unit.delete(pid, request)
        {:reply, :ok, state}

      {atom, node} ->
        :ok = Modbuzz.Data.Unit.delete({atom, node}, request)
        {:reply, :ok, state}

      nil ->
        {:reply, {:error, :unit_not_found}, state}
    end
  end

  def handle_call({:dump, unit_id}, _from, state) do
    unit_name = Modbuzz.Data.Unit.name(state.name, unit_id)

    case GenServer.whereis(unit_name) do
      pid when is_pid(pid) ->
        data = Modbuzz.Data.Unit.dump(pid)
        {:reply, {:ok, data}, state}

      {atom, node} ->
        data = Modbuzz.Data.Unit.dump({atom, node})
        {:reply, {:ok, data}, state}

      nil ->
        {:reply, {:error, :unit_not_found}, state}
    end
  end

  def handle_cast({:cast, unit_id, request, pid, timeout}, state)
      when is_pid(pid) and is_integer(timeout) and timeout >= 0 do
    %{name: name, async_reqs: async_reqs} = state
    res_or_cb = get_res_or_cb(name, unit_id, request)

    case res_or_cb do
      response when is_struct(response) ->
        send(pid, {:modbuzz, name, unit_id, request, async_result_tuple(response)})
        {:noreply, state}

      callback when is_function(callback) ->
        ref = make_ref()
        timer = Process.send_after(self(), {:async_timeout, ref}, timeout)
        async_reqs = Map.put(async_reqs, ref, {timer, pid, unit_id, request})
        me = self()

        Task.Supervisor.start_child(
          {:via, PartitionSupervisor, {Modbuzz.Data.CallbackSupervisor.name(name), self()}},
          fn -> send(me, {:async_response, ref, callback.(request)}) end
        )

        {:noreply, %{state | async_reqs: async_reqs}}

      nil ->
        ref = make_ref()
        timer = Process.send_after(self(), {:async_timeout, ref}, timeout)
        async_reqs = Map.put(async_reqs, ref, {timer, pid, unit_id, request})
        {:noreply, %{state | async_reqs: async_reqs}}
    end
  end

  def handle_info({:async_response, ref, response}, %{name: name, async_reqs: async_reqs} = state) do
    case Map.pop(async_reqs, ref) do
      {{timer, pid, unit_id, request}, async_reqs} ->
        Process.cancel_timer(timer)
        send(pid, {:modbuzz, name, unit_id, request, async_result_tuple(response)})
        {:noreply, %{state | async_reqs: async_reqs}}

      {nil, _async_reqs} ->
        {:noreply, state}
    end
  end

  def handle_info({:async_timeout, ref}, %{name: name, async_reqs: async_reqs} = state) do
    case Map.pop(async_reqs, ref) do
      {{_timer, pid, unit_id, request}, async_reqs} ->
        send(pid, {:modbuzz, name, unit_id, request, {:error, :timeout}})
        {:noreply, %{state | async_reqs: async_reqs}}

      {nil, _async_reqs} ->
        {:noreply, state}
    end
  end

  defp get_res_or_cb(name, unit_id, request) do
    unit_name = Modbuzz.Data.Unit.name(name, unit_id)

    case GenServer.whereis(unit_name) do
      pid when is_pid(pid) -> Modbuzz.Data.Unit.get(pid, request)
      {atom, node} -> Modbuzz.Data.Unit.get({atom, node}, request)
      nil -> nil
    end
  end

  defp async_result_tuple(%module{} = response) do
    if List.last(Module.split(module)) == "Err" do
      {:error, response}
    else
      {:ok, response}
    end
  end
end
