defmodule Modbuzz do
  @moduledoc """
  Documentation for `Modbuzz`.
  """

  @type request :: Modbuzz.PDU.Protocol.t()
  @type response :: Modbuzz.PDU.Protocol.t()
  @type error :: Modbuzz.PDU.Protocol.t()
  @type client :: GenServer.name()
  @type server :: GenServer.name()
  @type unit_id :: byte()

  @spec request(name :: client(), unit_id(), request()) ::
          {:ok, response()} | {:error, error() | term()}
  def request(name, unit_id \\ 0, request, timeout \\ 5000) do
    GenServer.call(name, {:call, unit_id, request, timeout})
  end

  defdelegate upsert(name, unit_id \\ 0, request, response), to: Modbuzz.Data.Server
  defdelegate delete(name, unit_id \\ 0, request), to: Modbuzz.Data.Server
  defdelegate dump(name, unit_id \\ 0), to: Modbuzz.Data.Server

  @spec start_data_server(name :: server()) :: :ok
  def start_data_server(name) do
    case DynamicSupervisor.start_child(
           Modbuzz.Application.data_server_supervisor_name(),
           {Modbuzz.Data.ServerSupervisor, [name: name]}
         ) do
      {:ok, _pid} ->
        :ok

      {:error, {:shutdown, {:failed_to_start_child, _, {:already_started, _pid}}}} ->
        {:error, :already_started}

      {:error, {:already_started, _pid}} ->
        {:error, :already_started}
    end
  end

  @spec start_tcp_client(
          name :: client(),
          address :: :inet.socket_address() | :inet.hostname(),
          port :: :inet.port_number()
        ) :: :ok | {:error, :already_started}
  def start_tcp_client(name, address, port) do
    case DynamicSupervisor.start_child(
           Modbuzz.Application.client_supervisor_name(),
           {Modbuzz.TCP.Client, [name: name, address: address, port: port]}
         ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
    end
  end

  @spec start_tcp_server(
          name :: server(),
          address :: :inet.socket_address() | :inet.hostname(),
          port :: :inet.port_number(),
          data_source :: server() | client()
        ) :: :ok | {:error, :already_started}
  def start_tcp_server(name, address, port, data_source) do
    case DynamicSupervisor.start_child(
           Modbuzz.Application.server_supervisor_name(),
           {Modbuzz.TCP.ServerSupervisor,
            [name: name, address: address, port: port, data_source: data_source]}
         ) do
      {:ok, _pid} ->
        :ok

      {:error, {:shutdown, {:failed_to_start_child, _, {:already_started, _pid}}}} ->
        {:error, :already_started}

      {:error, {:already_started, _pid}} ->
        {:error, :already_started}
    end
  end

  defguard is_unit_id(unit_id) when unit_id in 0..247
end
