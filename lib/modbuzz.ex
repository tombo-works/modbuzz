defmodule Modbuzz do
  @moduledoc """
  Documentation for `Modbuzz`.
  """

  @type request :: Modbuss.PDU.Protocol.t()
  @type response :: Modbuss.PDU.Protocol.t()
  @type error :: Modbuss.PDU.Protocol.t()

  @spec request(name :: client(), request()) :: {:ok, response()} | {:error, error() | term()}
  def request(name, unit_id \\ 0, struct, timeout \\ 5000) do
    GenServer.call(name, {:call, unit_id, struct, timeout})
  end

  @spec start_tcp_client(
          name :: client(),
          address :: :inet.socket_address() | :inet.hostname(),
          port :: :inet.port_number()
        ) :: :ok | {:error, :already_started}
  def start_tcp_client(name, address, port) do
    case DynamicSupervisor.start_child(
           Modbuzz.ClientsSupervisor,
           {Modbuzz.TCP.Client, [name: name, address: address, port: port]}
         ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
    end
  end
end
