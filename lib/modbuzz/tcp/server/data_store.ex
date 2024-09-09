defmodule Modbuzz.TCP.Server.DataStore do
  @moduledoc false

  use Agent

  def name(address, port, unit_id) do
    {:via, Registry, {Modbuzz.TCP.Server.Registry, {address, port, unit_id}}}
  end

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    state = Keyword.fetch!(args, :state)

    Agent.start_link(fn -> state end, name: name)
  end
end
