defmodule Modbuzz.TCP.Server.Supervisor do
  @moduledoc """
  This is `Modbuzz.TCP.Server`'s `Supervisor` module.
  """

  use Supervisor

  @doc """
  Starts a `Modbuzz.TCP.Server`'s Supervisor process linked to the current process.
  After `start_link`, we can operate the Server data from its API.

  ## Options

    * `:name` - used for name registration as described in the "Name
      registration" section in the documentation for `GenServer`

    * `:address` - passed through to `:gen_tcp.listen/2`

    * `:port` - passed through to `:gen_tcp.listen/2`

  ## Examples

      iex> Modbuzz.TCP.Server.Supervisor.start_link([address: {192, 168, 0, 123}, port: 502])

  """
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  def init(args) do
    children = [
      {Registry, keys: :unique, name: Modbuzz.TCP.Server.Registry},
      {DynamicSupervisor, name: Modbuzz.TCP.Server.DataStoreSupervisor, strategy: :one_for_one},
      {Modbuzz.TCP.Server.DataStoreOperator, args},
      {DynamicSupervisor,
       name: Modbuzz.TCP.Server.SocketHandlerSupervisor, strategy: :one_for_one},
      {Modbuzz.TCP.Server, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
