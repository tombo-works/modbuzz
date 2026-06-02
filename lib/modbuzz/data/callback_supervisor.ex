defmodule Modbuzz.Data.CallbackSupervisor do
  @moduledoc false

  def name(name) do
    {:via, Registry, {Modbuzz.Registry, {name, __MODULE__}}}
  end
end
