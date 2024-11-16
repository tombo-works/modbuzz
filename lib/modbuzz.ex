defmodule Modbuzz do
  @moduledoc """
  `Modbuzz` is yet another MODBUS library, supporting both TCP and RTU.
  """

  @type request :: Modbuzz.PDU.Protocol.t()
  @type response :: Modbuzz.PDU.Protocol.t()
  @type error :: Modbuzz.PDU.Protocol.t()
  @type callback :: (request() -> response())
  @type client :: GenServer.name()
  @type data_server :: GenServer.name()
  @type server :: GenServer.name()
  @type unit_id :: 0..247

  @doc "Request data."
  @spec request(name :: client() | data_server(), unit_id(), request(), non_neg_integer()) ::
          {:ok, response()} | {:error, error()} | {:error, reason :: term()}
  def request(name, unit_id \\ 0, request, timeout \\ 5000) do
    GenServer.call(name, {:call, unit_id, request, timeout})
  end

  @doc "Create a unit under the data server."
  @spec create_unit(name :: data_server(), unit_id()) :: :ok | {:error, :already_created}
  defdelegate create_unit(name, unit_id \\ 0), to: Modbuzz.Data.Server

  @doc """
  Upsert request response/callback pair to data server.

  When using a callback, the user is responsible for the callback.
  This library does not handle its error. In case of an error, the request will simply time out with noreply.
  """
  @spec upsert(name :: data_server(), unit_id(), request(), response() | callback()) ::
          :ok | {:error, :unit_not_found}
  defdelegate upsert(name, unit_id \\ 0, request, res_or_cb), to: Modbuzz.Data.Server

  @doc "Delete request response pair from data server."
  @spec delete(name :: data_server(), unit_id(), request()) :: :ok | {:error, :unit_not_found}
  defdelegate delete(name, unit_id \\ 0, request), to: Modbuzz.Data.Server

  @doc "Dump data from data server."
  @spec dump(name :: data_server(), unit_id()) :: {:ok, map()} | {:error, :unit_not_found}
  defdelegate dump(name, unit_id \\ 0), to: Modbuzz.Data.Server

  @doc """
  Start data server.

  ## Examples

      iex> :ok = Modbuzz.start_data_server(:data_server)
      iex> alias Modbuzz.PDU.WriteSingleCoil
      iex> req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
      iex> res = %WriteSingleCoil.Res{output_address: 0 , output_value: true}
      iex> :ok = Modbuzz.create_unit(:data_server, 1)
      iex> :ok = Modbuzz.upsert(:data_server, 1, req, res)
      iex> {:ok, ^res} = Modbuzz.request(:data_server, 1, req)
  """
  @spec start_data_server(name :: data_server()) :: :ok
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

  @doc """
  Start TCP client.

  ## Examples

      iex> :ok = Modbuzz.start_tcp_client(:client, {127, 0, 0, 1}, 50200)
      iex> alias Modbuzz.PDU.WriteSingleCoil
      iex> req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
      iex> {:error, %WriteSingleCoil.Err{}} = Modbuzz.request(:client, req)
  """
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

  @doc """
  Start TCP server.

  ## Examples

      iex> :ok = Modbuzz.start_data_server(:data_server)
      iex> alias Modbuzz.PDU.WriteSingleCoil
      iex> req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
      iex> res = %WriteSingleCoil.Res{output_address: 0 , output_value: true}
      iex> :ok = Modbuzz.create_unit(:data_server, 1)
      iex> :ok = Modbuzz.upsert(:data_server, 1, req, res)
      iex> :ok = Modbuzz.start_tcp_server(:server, {127, 0, 0, 1}, 50200, :data_server)
  """
  @spec start_tcp_server(
          name :: server(),
          address :: :inet.socket_address() | :inet.hostname(),
          port :: :inet.port_number(),
          data_source :: data_server() | client()
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

  @doc """
  Start RTU client.

  This function accepts `transport_opts` as its third argument which allows to pass options to `Circuits.UART`.
  Options provided in `transport_opts` are passed directly to `Circuits.UART` without modification.

  ## Examples

      iex> :ok = Modbuzz.start_rtu_client(:client, "ttyUSB0", [speed: 9600])
      iex> alias Modbuzz.PDU.WriteSingleCoil
      iex> req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
      iex> {:error, %WriteSingleCoil.Err{}} = Modbuzz.request(:client, req)
  """
  @spec start_rtu_client(
          name :: client(),
          device_name :: String.t(),
          transport_opts :: keyword()
        ) :: :ok | {:error, :already_started}
  def start_rtu_client(name, device_name, transport_opts) do
    case DynamicSupervisor.start_child(
           Modbuzz.Application.client_supervisor_name(),
           {Modbuzz.RTU.ClientSupervisor,
            [name: name, device_name: device_name, transport_opts: transport_opts]}
         ) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_started}
    end
  end

  @doc """
  Start RTU server.

  This function accepts `transport_opts` as its third argument which allows to pass options to `Circuits.UART`.
  Options provided in `transport_opts` are passed directly to `Circuits.UART` without modification.

  ## Examples

      iex> :ok = Modbuzz.start_data_server(:data_server)
      iex> alias Modbuzz.PDU.WriteSingleCoil
      iex> req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
      iex> res = %WriteSingleCoil.Res{output_address: 0 , output_value: true}
      iex> :ok = Modbuzz.create_unit(:data_server, 1)
      iex> :ok = Modbuzz.upsert(:data_server, 1, req, res)
      iex> :ok = Modbuzz.start_rtu_server(:server, "ttyUSB0", [speed: 9600], :data_server)
  """
  @spec start_rtu_server(
          name :: server(),
          device_name :: String.t(),
          transport_opts :: Circuits.UART.uart_option(),
          data_source :: data_server() | client()
        ) :: :ok | {:error, :already_started}
  def start_rtu_server(name, device_name, transport_opts, data_source) do
    case DynamicSupervisor.start_child(
           Modbuzz.Application.server_supervisor_name(),
           {Modbuzz.RTU.Server,
            [
              name: name,
              device_name: device_name,
              transport_opts: transport_opts,
              data_source: data_source
            ]}
         ) do
      {:ok, _pid} ->
        :ok

      {:error, {:shutdown, {:failed_to_start_child, _, {:already_started, _pid}}}} ->
        {:error, :already_started}

      {:error, {:already_started, _pid}} ->
        {:error, :already_started}
    end
  end

  @doc false
  defguard is_unit_id(unit_id) when unit_id in 0..247
end
