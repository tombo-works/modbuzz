defmodule Modbuzz.Data.CallbackSupervisor do
  @moduledoc false

  def name(server_name) do
    {:via, Registry, {Modbuzz.Registry, {server_name, __MODULE__}}}
  end
end
