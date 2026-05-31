defmodule Modbuzz.TCP.Client do
  @moduledoc false

  use GenServer

  alias Modbuzz.TCP.ADU
  alias Modbuzz.TCP.Log

  @unit_id_max 255

  defguardp is_valid_unit_id(unit_id) when unit_id >= 0 and unit_id <= @unit_id_max

  defmodule Transaction do
    @moduledoc false
    @type t :: %__MODULE__{
            call_or_cast: :call | :cast,
            unit_id: 0x00..0xFF,
            request: Modbuzz.PDU.Protocol.t(),
            from_or_pid: GenServer.from() | pid() | nil,
            ref: reference(),
            timer: reference()
          }
    defstruct [:call_or_cast, :unit_id, :request, :from_or_pid, :ref, :timer]
  end

  @doc """
  Starts a #{__MODULE__} GenServer process linked to the current process.

  ## Options

    * `:name` - used for name registration as described in the "Name
      registration" section in the documentation for `GenServer`

    * `:address` - passed through to `:gen_tcp.connect/4`

    * `:port` - passed through to `:gen_tcp.connect/4`

  ## Examples

      iex> Modbuzz.TCP.Client.start_link([name: :client, address: {192, 168, 0, 123}, port: 502])

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.get(args, :name, __MODULE__)
    args = Keyword.put_new(args, :name, name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Makes a synchronous call to the server and waits for a response.

  The response type is `{:ok, %Res{}}` or `{:error, %Err{} | reason :: term()}`.

  ## Examples

      iex> alias Modbuzz.PDU.{WriteSingleCoil, ReadCoils}
      [Modbuzz.PDU.WriteSingleCoil, Modbuzz.PDU.ReadCoils]
      iex> Modbuzz.TCP.Client.call(%WriteSingleCoil.Req{output_address: 0 , output_value: true})
      {:ok, %WriteSingleCoil.Res{output_address: 0 , output_value: true}}
      iex> Modbuzz.TCP.Client.call(%ReadCoils.Req{starting_address: 0 , quantity_of_coils: 1})
      {:ok, %ReadCoils.Res{byte_count: 1, [true, false, false, false, false, false, false, false]}}
  """
  @spec call(
          GenServer.server(),
          unit_id :: 0x00..0xFF,
          request :: Modbuzz.PDU.Protocol.t(),
          non_neg_integer()
        ) ::
          {:ok, response :: term()} | {:error, reason :: term()}
  def call(name \\ __MODULE__, unit_id \\ 0, request, timeout \\ 5000)
      when unit_id in 0x00..0xFF and is_struct(request) and is_integer(timeout) do
    GenServer.call(name, {:call, unit_id, request, timeout})
  end

  @doc """
  Casts a request to the server without waiting for a response.

  This function always returns :ok regardless of whether the destination server (or node) exists.
  Therefore it is unknown whether the destination server successfully handled the request.

  Its response is sent as a message, looks like

  ```
  {:modbuzz, client_name, unit_id, request, response_tuple}
  ```

  The response type is `{:ok, %Res{}}` or `{:error, %Err{} | reason :: term()}`.

  ## Examples

      iex> alias Modbuzz.PDU.{WriteSingleCoil.Req, ReadCoils.Req}
      [Modbuzz.PDU.WriteSingleCoil.Req, Modbuzz.PDU.ReadCoils.Req]
      iex> Modbuzz.TCP.Client.cast(%WriteSingleCoil.Req{output_address: 0 , output_value: true})
      :ok
      iex> Modbuzz.TCP.Client.cast(%ReadCoils.Req{starting_address: 0 , quantity_of_coils: 1})
      :ok
  """
  @spec cast(
          GenServer.server(),
          unit_id :: 0x00..0xFF,
          request :: Modbuzz.PDU.Protocol.t(),
          pid(),
          non_neg_integer()
        ) ::
          :ok
  def cast(name \\ __MODULE__, unit_id \\ 0, request, pid \\ self(), timeout \\ 5000)
      when unit_id in 0x00..0xFF and is_struct(request) and is_pid(pid) and is_integer(timeout) do
    GenServer.cast(name, {:cast, unit_id, request, pid, timeout})
  end

  @impl true
  def init(args) when is_list(args) do
    client_name = Keyword.fetch!(args, :name)
    transport = Keyword.get(args, :transport, :gen_tcp)
    address = Keyword.get(args, :address, {192, 168, 5, 57})
    port = Keyword.get(args, :port, 502)

    state = %{
      client_name: client_name,
      transport: transport,
      address: address,
      port: port,
      socket: nil,
      transaction_id: 0,
      transactions: %{},
      binary: <<>>
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:call, unit_id, request, timeout}, from, state)
      when is_valid_unit_id(unit_id) do
    handle_req({:call, unit_id, request, from, timeout}, state)
  end

  @impl true
  def handle_cast({:cast, unit_id, request, pid, timeout}, state)
      when is_valid_unit_id(unit_id) and is_pid(pid) do
    handle_req({:cast, unit_id, request, pid, timeout}, state)
  end

  defp handle_req({call_or_cast, unit_id, request, from_or_pid, timeout}, state) do
    %{
      client_name: client_name,
      transport: transport,
      transaction_id: transaction_id,
      transactions: transactions
    } = state

    transaction_id = ADU.increment_transaction_id(transaction_id)

    ref = make_ref()

    transaction = %Transaction{
      call_or_cast: call_or_cast,
      unit_id: unit_id,
      request: request,
      from_or_pid: from_or_pid,
      ref: ref,
      timer: Process.send_after(self(), {:timeout?, transaction_id, ref}, timeout)
    }

    case connect(state, timeout) do
      {:ok, socket} ->
        binary = request |> ADU.new(transaction_id, unit_id) |> ADU.encode()

        case transport.send(socket, binary) do
          :ok ->
            transactions = Map.put(transactions, transaction_id, transaction)

            {:noreply,
             %{
               state
               | socket: socket,
                 transaction_id: transaction_id,
                 transactions: transactions
             }}

          {:error, reason} ->
            Log.error("#{inspect(transport)} send error", reason, state)
            :ok = transport.close(socket)

            transactions = Map.put(transactions, transaction_id, transaction)
            res_tuple = {:error, :tcp_send_error}

            Enum.each(transactions, fn {_transaction_id, transaction} ->
              Process.cancel_timer(transaction.timer)
              report_response(transaction, client_name, res_tuple)
            end)

            {:noreply, %{state | socket: nil, binary: <<>>, transactions: %{}}}
        end

      {:error, reason} ->
        Log.error("#{inspect(transport)} connect error", reason, state)

        res_tuple = {:error, :tcp_connect_error}

        Process.cancel_timer(transaction.timer)
        report_response(transaction, client_name, res_tuple)

        {:noreply, %{state | socket: nil, binary: <<>>, transactions: %{}}}
    end
  end

  @impl true
  def handle_info({:timeout?, transaction_id, ref}, state) do
    %{
      client_name: client_name,
      transactions: transactions
    } = state

    case Map.get(transactions, transaction_id) do
      # already responded
      nil ->
        {:noreply, state}

      # timeout for the current request, report timeout error
      %Transaction{request: request, ref: ref_} = transaction when ref_ == ref ->
        Log.error("TCP server didn't respond for #{inspect(request)}", nil, state)

        res_tuple = {:error, :timeout}

        report_response(transaction, client_name, res_tuple)

        {:noreply, %{state | transactions: Map.delete(transactions, transaction_id)}}

      # the current request is different, do not report timeout error
      # this means the request that triggered this timeout message has already been responded to
      # and a new request for the same transaction_id has been sent after that
      %Transaction{ref: ref_} when ref_ != ref ->
        {:noreply, state}
    end
  end

  def handle_info({:tcp, socket, binary}, %{socket: socket} = state) do
    %{
      client_name: client_name,
      transport: transport,
      transactions: transactions
    } = state

    new_binary = state.binary <> binary

    case ADU.decode_response(new_binary, []) do
      {:ok, {adu_tuples, binary}} ->
        transactions =
          Enum.reduce(
            adu_tuples,
            transactions,
            fn {ok_or_error, %ADU{transaction_id: transaction_id, pdu: pdu}}, acc ->
              {transaction, acc} = Map.pop(acc, transaction_id)
              res_tuple = {ok_or_error, pdu}

              if not is_nil(transaction) do
                Process.cancel_timer(transaction.timer)
                report_response(transaction, client_name, res_tuple)
              end

              acc
            end
          )

        {:noreply, %{state | transactions: transactions, binary: binary}}

      {:error, reason} ->
        Log.error("Decode error", reason, state)
        :ok = transport.close(socket)
        res_tuple = {:error, :decode_error}

        Enum.each(transactions, fn {_transaction_id, transaction} ->
          Process.cancel_timer(transaction.timer)
          report_response(transaction, client_name, res_tuple)
        end)

        {:noreply, %{state | socket: nil, binary: <<>>, transactions: %{}}}
    end
  end

  def handle_info({:tcp, _socket, _binary}, state) do
    # Ignore frames from stale sockets so they cannot affect the active connection state.
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    %{
      client_name: client_name,
      transport: transport,
      transactions: transactions
    } = state

    Log.error("#{inspect(transport)} closed", nil, state)
    if not is_nil(socket), do: :ok = transport.close(socket)
    res_tuple = {:error, :tcp_closed}

    Enum.each(transactions, fn {_transaction_id, transaction} ->
      Process.cancel_timer(transaction.timer)
      report_response(transaction, client_name, res_tuple)
    end)

    {:noreply, %{state | socket: nil, binary: <<>>, transactions: %{}}}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    # Ignore close notifications from stale sockets.
    {:noreply, state}
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    %{
      client_name: client_name,
      transport: transport,
      transactions: transactions
    } = state

    Log.error("transport error", reason, state)
    if not is_nil(socket), do: :ok = transport.close(socket)
    res_tuple = {:error, :tcp_error}

    Enum.each(transactions, fn {_transaction_id, transaction} ->
      Process.cancel_timer(transaction.timer)
      report_response(transaction, client_name, res_tuple)
    end)

    {:noreply, %{state | socket: nil, binary: <<>>, transactions: %{}}}
  end

  def handle_info({:tcp_error, _socket, _reason}, state) do
    # Ignore errors from stale sockets; only the active socket should fail pending work.
    {:noreply, state}
  end

  defp connect(state, timeout) do
    %{transport: transport, address: address, port: port, socket: socket} = state

    if is_nil(socket) do
      transport.connect(
        address,
        port,
        [
          mode: :binary,
          packet: :raw,
          active: true,
          keepalive: true,
          nodelay: true,
          reuseaddr: true
        ],
        timeout
      )
    else
      {:ok, socket}
    end
  end

  defp report_response(%Transaction{} = transaction, client_name, res_tuple) do
    case transaction do
      %{call_or_cast: :call, unit_id: _unit_id, request: _request, from_or_pid: from}
      when is_tuple(from) ->
        GenServer.reply(from, res_tuple)

      %{call_or_cast: :cast, unit_id: unit_id, request: request, from_or_pid: pid}
      when is_pid(pid) ->
        send(pid, {:modbuzz, client_name, unit_id, request, res_tuple})
    end
  end
end
