defmodule Modbuzz.TCP.Server.DataStoreSupervisor do
  @moduledoc false

  @doc false
  def name(host, address, port) do
    {:global, {__MODULE__, host, address, port}}
  end

  def start_data_store(host, address, port, unit_id, state) do
    name = Modbuzz.TCP.Server.DataStore.name(host, address, port, unit_id)

    DynamicSupervisor.start_child(
      Modbuzz.TCP.Server.DataStoreSupervisor.name(host, address, port),
      {Modbuzz.TCP.Server.DataStore, name: name, state: state}
    )
  end
end
