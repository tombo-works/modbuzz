defmodule Modbuzz do
  @moduledoc """
  `Modbuzz` is a MODBUS library with a small public API for TCP, RTU, and gateway use cases.

  The `Modbuzz` module is the external API entrypoint:

  - Request data (`request/2`, `request/3`, `request/4`, `request_async/2`, `request_async/3`, `request_async/4`, `request_async/5`)
  - Manage optional data-server content (`create_unit/1`, `create_unit/2`, `upsert/3`, `upsert/4`, `delete/2`, `delete/3`, `dump/1`, `dump/2`)
  - Start and stop TCP/RTU clients and servers
  """

  @type request :: Modbuzz.PDU.Protocol.t()
  @type response :: Modbuzz.PDU.Protocol.t()
  @type error :: Modbuzz.PDU.Protocol.t()
  @type callback :: (request() -> response())
  @type client :: GenServer.name()
  @type data_server :: GenServer.name()
  @type server :: GenServer.name()
  @type unit_id :: 0..247

  @doc """
  Send a synchronous request and wait for the result.

  Use this function when your flow is simple and blocking behavior is acceptable.

  ## Returns

  - `{:ok, response}` on normal response.
  - `{:error, error_response}` on MODBUS exception response.
  - `{:error, reason}` on local/network/runtime failures.

  ## Common failures

  - `{:error, :timeout}` when no response arrives before `timeout`.
  - Caller exits with `:noproc` if target process is not running (`GenServer.call/3` behavior).
  """
  @spec request(
          name :: client() | data_server(),
          unit_id(),
          request(),
          non_neg_integer()
        ) :: {:ok, response()} | {:error, error()} | {:error, reason :: term()}
  def request(name, unit_id \\ 0, request, timeout \\ 5000) do
    # The GenServer.call timeout is set slightly longer than the internal `timeout` so that
    # the request logic inside the client/data_server handles the timeout first and returns
    # {:error, :timeout} gracefully, rather than GenServer.call raising an EXIT signal.
    GenServer.call(name, {:call, unit_id, request, timeout}, timeout + 50)
  end

  @doc """
  Send an asynchronous request and return immediately.

  Use this function when you need non-blocking behavior.
  The result is sent to `pid` as a message.

  This function uses `GenServer.cast/2`, so it always returns `:ok` even if `name` is not
  running or registered. In that case, no result message is delivered.

  ## Result message format

      {:modbuzz, name, unit_id, request, {:ok, response}}
      {:modbuzz, name, unit_id, request, {:error, error_response_or_error_reason}}

  ## Common failures

  - No message received because target process is not started.
  - `{:error, :timeout}` in async message payload when response is late.
  """
  @spec request_async(
          name :: client() | data_server(),
          unit_id(),
          request(),
          pid(),
          non_neg_integer()
        ) :: :ok
  def request_async(name, unit_id \\ 0, request, pid \\ self(), timeout \\ 5000)
      when is_pid(pid) and is_integer(timeout) and timeout >= 0 do
    GenServer.cast(name, {:cast, unit_id, request, pid, timeout})
  end

  @doc """
  Create a unit under a data server.

  ## Returns

  - `:ok` when unit is created.
  - `{:error, :already_created}` when the unit already exists.
  """
  @spec create_unit(name :: data_server(), unit_id()) :: :ok | {:error, :already_created}
  defdelegate create_unit(name, unit_id \\ 0), to: Modbuzz.Data.Server

  @doc """
  Upsert a request response/callback pair into a data server unit.

  Use this to define how data server responds for a specific request.

  When using a callback, callback error handling is your responsibility.
  If callback fails and does not return a response, caller may observe timeout.

  ## Returns

  - `:ok` when upsert succeeds.
  - `{:error, :unit_not_found}` when target unit does not exist.
  """
  @spec upsert(name :: data_server(), unit_id(), request(), response() | callback()) ::
          :ok | {:error, :unit_not_found}
  defdelegate upsert(name, unit_id \\ 0, request, res_or_cb), to: Modbuzz.Data.Server

  @doc """
  Delete a request mapping from a data server unit.

  ## Returns

  - `:ok` when mapping is deleted.
  - `{:error, :unit_not_found}` when target unit does not exist.
  """
  @spec delete(name :: data_server(), unit_id(), request()) :: :ok | {:error, :unit_not_found}
  defdelegate delete(name, unit_id \\ 0, request), to: Modbuzz.Data.Server

  @doc """
  Dump all request mappings from a data server unit.

  ## Returns

  - `{:ok, map}` when unit exists.
  - `{:error, :unit_not_found}` when target unit does not exist.
  """
  @spec dump(name :: data_server(), unit_id()) :: {:ok, map()} | {:error, :unit_not_found}
  defdelegate dump(name, unit_id \\ 0), to: Modbuzz.Data.Server

  @doc """
  Start a data server instance.

  ## Returns

  - `:ok` when started.
  - `{:error, :already_started}` when name is already in use.

  ## Examples

      iex> :ok = Modbuzz.start_data_server(:data_server)
      iex> alias Modbuzz.PDU.WriteSingleCoil
      iex> req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
      iex> res = %WriteSingleCoil.Res{output_address: 0 , output_value: true}
      iex> :ok = Modbuzz.create_unit(:data_server, 1)
      iex> :ok = Modbuzz.upsert(:data_server, 1, req, res)
      iex> {:ok, ^res} = Modbuzz.request(:data_server, 1, req)
  """
  @spec start_data_server(name :: data_server()) :: :ok | {:error, :already_started}
  def start_data_server(name) do
    supervisor = Modbuzz.Application.data_server_dynamic_supervisor_name()
    via_name = Modbuzz.Data.ServerSupervisor.name(name)
    child_spec = {Modbuzz.Data.ServerSupervisor, via_name: via_name}

    start_child(supervisor, child_spec)
  end

  @doc """
  Stop a data server instance.

  ## Returns

  - `:ok` when stopped.
  - `{:error, :not_started}` when target is not running.
  """
  @spec stop_data_server(name :: data_server()) :: :ok | {:error, :not_started}
  def stop_data_server(name) do
    supervisor = Modbuzz.Application.data_server_dynamic_supervisor_name()
    via_name = Modbuzz.Data.ServerSupervisor.name(name)

    stop_child(supervisor, via_name)
  end

  @doc """
  Start a TCP client instance.

  ## Returns

  - `:ok` when started.
  - `{:error, :already_started}` when name is already in use.

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
    supervisor = Modbuzz.Application.client_dynamic_supervisor_name()

    child_spec =
      {Modbuzz.TCP.Client,
       [
         name: name,
         address: address,
         port: port
       ]}

    start_child(supervisor, child_spec)
  end

  @doc """
  Stop a TCP client instance.

  ## Returns

  - `:ok` when stopped.
  - `{:error, :not_started}` when target is not running.
  """
  @spec stop_tcp_client(name :: client()) :: :ok | {:error, :not_started}
  def stop_tcp_client(name) do
    supervisor = Modbuzz.Application.client_dynamic_supervisor_name()

    stop_child(supervisor, name)
  end

  @doc """
  Start a TCP server instance.

  `data_source` can be a data server, TCP client, or RTU client process name.

  ## Returns

  - `:ok` when started.
  - `{:error, :already_started}` when name is already in use.

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
    supervisor = Modbuzz.Application.server_dynamic_supervisor_name()
    via_name = Modbuzz.TCP.ServerSupervisor.name(name)

    child_spec =
      {Modbuzz.TCP.ServerSupervisor,
       [
         via_name: via_name,
         address: address,
         port: port,
         data_source: data_source
       ]}

    start_child(supervisor, child_spec)
  end

  @doc """
  Stop a TCP server instance.

  ## Returns

  - `:ok` when stopped.
  - `{:error, :not_started}` when target is not running.
  """
  @spec stop_tcp_server(name :: server()) :: :ok | {:error, :not_started}
  def stop_tcp_server(name) do
    supervisor = Modbuzz.Application.server_dynamic_supervisor_name()
    via_name = Modbuzz.TCP.ServerSupervisor.name(name)

    stop_child(supervisor, via_name)
  end

  @doc """
  Start an RTU client instance.

  This function accepts `transport_opts` as its third argument which allows to pass options to `Circuits.UART`.
  Options provided in `transport_opts` are passed directly to `Circuits.UART` without modification.

  ## Returns

  - `:ok` when started.
  - `{:error, :already_started}` when name is already in use.

  ## Examples

      iex> :ok = Modbuzz.start_rtu_client(:client, "ttyUSB0", [speed: 9600])
      iex> alias Modbuzz.PDU.WriteSingleCoil
      iex> req = %WriteSingleCoil.Req{output_address: 0 , output_value: true}
      iex> {:error, %WriteSingleCoil.Err{}} = Modbuzz.request(:client, req)
  """
  @spec start_rtu_client(
          name :: client(),
          device_name :: String.t(),
          transport_opts :: keyword(),
          transport :: module()
        ) :: :ok | {:error, :already_started}
  def start_rtu_client(name, device_name, transport_opts, transport \\ Circuits.UART) do
    supervisor = Modbuzz.Application.client_dynamic_supervisor_name()

    child_spec =
      {Modbuzz.RTU.Client,
       [
         name: name,
         device_name: device_name,
         transport_opts: transport_opts,
         transport: transport
       ]}

    start_child(supervisor, child_spec)
  end

  @doc """
  Stop an RTU client instance.

  ## Returns

  - `:ok` when stopped.
  - `{:error, :not_started}` when target is not running.
  """
  @spec stop_rtu_client(name :: client()) :: :ok | {:error, :not_started}
  def stop_rtu_client(name) do
    supervisor = Modbuzz.Application.client_dynamic_supervisor_name()

    stop_child(supervisor, name)
  end

  @doc """
  Start an RTU server instance.

  This function accepts `transport_opts` as its third argument which allows to pass options to `Circuits.UART`.
  Options provided in `transport_opts` are passed directly to `Circuits.UART` without modification.

  `data_source` can be a data server, TCP client, or RTU client process name.

  ## Returns

  - `:ok` when started.
  - `{:error, :already_started}` when name is already in use.

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
          data_source :: data_server() | client(),
          transport :: module()
        ) :: :ok | {:error, :already_started}
  def start_rtu_server(name, device_name, transport_opts, data_source, transport \\ Circuits.UART) do
    supervisor = Modbuzz.Application.server_dynamic_supervisor_name()

    child_spec =
      {Modbuzz.RTU.Server,
       [
         name: name,
         device_name: device_name,
         transport_opts: transport_opts,
         data_source: data_source,
         transport: transport
       ]}

    start_child(supervisor, child_spec)
  end

  @doc """
  Stop an RTU server instance.

  ## Returns

  - `:ok` when stopped.
  - `{:error, :not_started}` when target is not running.
  """
  @spec stop_rtu_server(name :: server()) :: :ok | {:error, :not_started}
  def stop_rtu_server(name) do
    supervisor = Modbuzz.Application.server_dynamic_supervisor_name()

    stop_child(supervisor, name)
  end

  defp start_child(supervisor, child_spec) do
    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, _pid} ->
        :ok

      {:error, {:shutdown, {:failed_to_start_child, _, {:already_started, _pid}}}} ->
        {:error, :already_started}

      {:error, {:already_started, _pid}} ->
        {:error, :already_started}
    end
  end

  defp stop_child(supervisor, name) do
    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        case DynamicSupervisor.terminate_child(supervisor, pid) do
          :ok -> :ok
          {:error, :not_found} -> {:error, :not_started}
        end

      nil ->
        {:error, :not_started}
    end
  end

  @doc false
  defguard is_unit_id(unit_id) when unit_id in 0..247
end
