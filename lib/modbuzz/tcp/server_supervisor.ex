defmodule Modbuzz.TCP.ServerSupervisor do
  @moduledoc false

  use Supervisor

  def name(name) do
    {:via, Registry, {Modbuzz.Registry, {name, __MODULE__}}}
  end

  @doc """
  Starts a `Modbuzz.TCP.Server`'s Supervisor process linked to the current process.

  ## Options

    * `:address` - passed through to `:gen_tcp.listen/2`

    * `:port` - passed through to `:gen_tcp.listen/2`

  ## Examples

      iex> Modbuzz.TCP.ServerSupervisor.start_link([address: {192, 168, 0, 123}, port: 502])

  """
  def start_link(args) do
    via_name = Keyword.fetch!(args, :via_name)
    Supervisor.start_link(__MODULE__, args, name: via_name)
  end

  @doc false
  def init(args) do
    {via_name, args} = Keyword.pop!(args, :via_name)
    {:via, Registry, {Modbuzz.Registry, {name, __MODULE__}}} = via_name

    children = [
      {
        DynamicSupervisor,
        name: Modbuzz.TCP.Server.SocketHandlerSupervisor.name(name), strategy: :one_for_one
      },
      {
        Modbuzz.TCP.Server,
        name: name, args: args
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
