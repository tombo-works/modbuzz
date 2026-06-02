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
    _args = Keyword.fetch!(args, :args)

    {:ok, %{name: name, reqs: %{}}}
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

  def handle_call({:call, unit_id, request, timeout}, from, state)
      when is_unit_id(unit_id) and is_integer(timeout) and timeout >= 0 do
    handle_req({:call, unit_id, request, from, timeout}, state)
  end

  def handle_cast({:cast, unit_id, request, pid, timeout}, state)
      when is_unit_id(unit_id) and is_pid(pid) and is_integer(timeout) and timeout >= 0 do
    handle_req({:cast, unit_id, request, pid, timeout}, state)
  end

  defp handle_req({call_or_cast, unit_id, request, from_or_pid, timeout}, state) do
    %{
      name: name,
      reqs: reqs
    } = state

    res_or_cb = get_res_or_cb(name, unit_id, request)
    req = {call_or_cast, unit_id, request, from_or_pid}

    case res_or_cb do
      response when is_struct(response) ->
        report_response(req, name, result_tuple(response))
        {:noreply, state}

      callback when is_function(callback) ->
        ref = make_ref()
        timer = Process.send_after(self(), {:timeout?, ref}, timeout)
        reqs = Map.put(reqs, ref, {req, timer})
        me = self()

        Task.Supervisor.start_child(
          {:via, PartitionSupervisor, {Modbuzz.Data.CallbackSupervisor.name(name), self()}},
          fn -> send(me, {:callback_result, ref, result_tuple(callback.(request))}) end
        )

        {:noreply, %{state | reqs: reqs}}

      nil ->
        ref = make_ref()
        timer = Process.send_after(self(), {:timeout?, ref}, timeout)
        reqs = Map.put(reqs, ref, {req, timer})
        {:noreply, %{state | reqs: reqs}}
    end
  end

  def handle_info({:callback_result, ref, result}, state) do
    %{
      name: name,
      reqs: reqs
    } = state

    case Map.pop(reqs, ref) do
      {{req, timer}, reqs} ->
        Process.cancel_timer(timer)
        report_response(req, name, result)
        {:noreply, %{state | reqs: reqs}}

      {nil, _reqs} ->
        {:noreply, state}
    end
  end

  def handle_info({:timeout?, ref}, %{name: name, reqs: reqs} = state) do
    case Map.pop(reqs, ref) do
      {{req, _timer}, reqs} ->
        report_response(req, name, {:error, :timeout})
        {:noreply, %{state | reqs: reqs}}

      {nil, _reqs} ->
        {:noreply, state}
    end
  end

  defp report_response(req, name, res_tuple) do
    case req do
      {:call, _unit_id, _request, from} when is_tuple(from) ->
        GenServer.reply(from, res_tuple)

      {:cast, unit_id, request, pid} when is_pid(pid) ->
        send(pid, {:modbuzz, name, unit_id, request, res_tuple})

      _ ->
        raise ArgumentError, "unexpected req format: #{inspect(req)}"
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

  defp result_tuple(response) when is_struct(response) do
    case response do
      %{exception_code: _} -> {:error, response}
      _ -> {:ok, response}
    end
  end
end
