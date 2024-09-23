defmodule Modbuzz.TCP.ServerSupervisor do
  @moduledoc false

  use Supervisor

  @doc """
  Starts a `Modbuzz.TCP.Server`'s Supervisor process linked to the current process.

  ## Options

    * `:address` - passed through to `:gen_tcp.listen/2`

    * `:port` - passed through to `:gen_tcp.listen/2`

  ## Examples

      iex> Modbuzz.TCP.ServerSupervisor.start_link([address: {192, 168, 0, 123}, port: 502])

  """
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @doc false
  def init(args) do
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)

    children = [
      {
        DynamicSupervisor,
        name: Modbuzz.TCP.Server.SocketHandlerSupervisor.name(address, port),
        strategy: :one_for_one
      },
      {Modbuzz.TCP.Server, args}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
