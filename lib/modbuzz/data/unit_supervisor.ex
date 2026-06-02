defmodule Modbuzz.Data.UnitSupervisor do
  @moduledoc false

  import Modbuzz, only: [is_unit_id: 1]

  def name(name) do
    {:via, Registry, {Modbuzz.Registry, {name, __MODULE__}}}
  end

  def create_unit(name, unit_id) when is_unit_id(unit_id) do
    DynamicSupervisor.start_child(
      name(name),
      {Modbuzz.Data.Unit, name: name, unit_id: unit_id}
    )
  end
end
