defmodule Modbuzz.Data.UnitSupervisor do
  @moduledoc false

  import Modbuzz, only: [is_unit_id: 1]

  def name(server_name) do
    {:via, Registry, {Modbuzz.Registry, {server_name, __MODULE__}}}
  end

  def create_unit(server_name, unit_id) when is_unit_id(unit_id) do
    DynamicSupervisor.start_child(
      name(server_name),
      {Modbuzz.Data.Unit, server_name: server_name, unit_id: unit_id}
    )
  end
end
