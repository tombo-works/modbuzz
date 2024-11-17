defmodule Modbuzz.RTU.ClientSupervisor do
  @moduledoc false

  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @doc false
  def init(args) do
    children = [
      {Modbuzz.RTU.Client.Receiver,
       [
         device_name: Keyword.fetch!(args, :device_name),
         client_name: Keyword.fetch!(args, :name)
       ]},
      {Modbuzz.RTU.Client, args}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
