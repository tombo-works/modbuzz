defmodule Modbuzz.TCP.Client do
  @moduledoc false

  use GenServer

  require Logger

  defmodule Transaction do
    @moduledoc false
    defstruct [:unit_id, :request, :from_pid, :sent_time]
  end

  alias Modbuzz.TCP.ADU
  alias Modbuzz.PDU

  @doc """
  Starts a #{__MODULE__} GenServer process linked to the current process.

  ## Options

    * `:name` - used for name registration as described in the "Name
      registration" section in the documentation for `GenServer`

    * `:address` - passed through to `:gen_tcp.connect/4`

    * `:port` - passed through to `:gen_tcp.connect/4`

    * `:active` - passed through to `:gen_tcp.connect/4`

  ## Examples

      iex> Modbuzz.TCP.Client.start_link([address: {192, 168, 0, 123}, port: 502, active: false])

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc """
  Makes a synchronous call to the server and waits for a response.
  Only available when active: false.

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
          timeout()
        ) ::
          {:ok, response :: term()} | {:error, reason :: term()}
  def call(name \\ __MODULE__, unit_id \\ 0, request, timeout \\ 5000)
      when unit_id in 0x00..0xFF and is_struct(request) and is_integer(timeout) do
    GenServer.call(name, {:call, unit_id, request, timeout})
  end

  @doc """
  Casts a request to the server without waiting for a response.
  Only available when active: true.

  This function always returns :ok regardless of whether the destination server (or node) exists.
  Therefore it is unknown whether the destination server successfully handled the request.

  Its response is sent as a meessage, looks like

  ```
  {:modbuzz, unit_id, request, response}
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
          pid()
        ) ::
          :ok
  def cast(name \\ __MODULE__, unit_id \\ 0, request, from_pid \\ self())
      when unit_id in 0x00..0xFF and is_struct(request) and is_pid(from_pid) do
    GenServer.cast(name, {:cast, unit_id, request, from_pid})
  end

  @impl true
  def init(args) when is_list(args) do
    transport = Keyword.get(args, :transport, :gen_tcp)
    address = Keyword.get(args, :address, {192, 168, 5, 57})
    port = Keyword.get(args, :port, 502)
    active = Keyword.get(args, :active, false)

    state = %{
      transport: transport,
      address: address,
      port: port,
      active: active,
      socket: nil,
      transaction_id: 0,
      transactions: %{}
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, %{socket: nil} = state) do
    case gen_tcp_connect(state) do
      {:ok, socket} ->
        Logger.debug("#{__MODULE__}: :connect succeeded.")
        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
        Logger.error("#{__MODULE__}: :connect failed, the reason is #{inspect(reason)}.")
        {:noreply, state, {:continue, :connect}}
    end
  end

  def handle_continue({:recall, unit_id, request, timeout, from}, %{socket: nil} = state) do
    %{transport: transport, socket: socket, transaction_id: transaction_id} = state

    transaction_id = ADU.increment_transaction_id(transaction_id)
    adu = PDU.encode_request!(request) |> ADU.new(transaction_id, unit_id) |> ADU.encode()

    state = %{state | transaction_id: transaction_id}

    with {:connect, {:ok, socket}} <- {:connect, gen_tcp_connect(state)},
         {:send, :ok} <- {:send, transport.send(socket, adu)},
         {:recv, {:ok, binary}} <- {:recv, transport.recv(socket, _length = 0, timeout)} do
      [res_tuple] =
        for %ADU{transaction_id: ^transaction_id, pdu: pdu} <- ADU.decode(binary, []) do
          PDU.decode_response(pdu)
        end

      GenServer.reply(from, res_tuple)
      {:noreply, %{state | socket: socket}}
    else
      {:connect, {:error, reason} = error} ->
        Logger.error("#{__MODULE__}: :recall connect failed, the reason is #{inspect(reason)}.")
        GenServer.reply(from, error)
        {:noreply, state, {:continue, :connect}}

      {:send, {:error, reason} = error} ->
        Logger.error("#{__MODULE__}: :recall send failed, the reason is #{inspect(reason)}.")
        GenServer.reply(from, error)
        {:noreply, %{state | socket: socket}}

      {:recv, {:error, reason} = error} ->
        Logger.error("#{__MODULE__}: :recall recv failed, the reason is #{inspect(reason)}.")
        GenServer.reply(from, error)
        {:noreply, %{state | socket: socket}}
    end
  end

  def handle_continue({:recast, unit_id, request, from_pid}, %{socket: nil} = state) do
    %{
      transport: transport,
      socket: socket,
      transaction_id: transaction_id,
      transactions: transactions
    } = state

    transaction_id = ADU.increment_transaction_id(transaction_id)
    adu = PDU.encode_request!(request) |> ADU.new(transaction_id, unit_id) |> ADU.encode()

    state = %{state | transaction_id: transaction_id}

    with {:connect, {:ok, socket}} <- {:connect, gen_tcp_connect(state)},
         {:send, :ok} <- {:send, transport.send(socket, adu)} do
      transaction = %Transaction{
        unit_id: unit_id,
        request: request,
        from_pid: from_pid,
        sent_time: System.monotonic_time(:millisecond)
      }

      transactions = Map.put(transactions, transaction_id, transaction)
      {:noreply, %{state | socket: socket, transactions: transactions}}
    else
      {:connect, {:error, reason}} ->
        Logger.error("#{__MODULE__}: :recast connect failed, the reason is #{inspect(reason)}.")
        {:noreply, state, {:continue, :connect}}

      {:send, {:error, reason}} ->
        Logger.error("#{__MODULE__}: :recast send failed, the reason is #{inspect(reason)}.")
        {:noreply, %{state | socket: socket}}
    end
  end

  @impl true
  def handle_call({:call, unit_id, request, timeout}, from, %{active: false} = state) do
    %{transport: transport, socket: socket, transaction_id: transaction_id} = state

    transaction_id = ADU.increment_transaction_id(transaction_id)
    adu = PDU.encode_request!(request) |> ADU.new(transaction_id, unit_id) |> ADU.encode()

    state = %{state | transaction_id: transaction_id}

    with {:send, :ok} <- {:send, transport.send(socket, adu)},
         {:recv, {:ok, binary}} <- {:recv, transport.recv(socket, _length = 0, timeout)} do
      [res_tuple] =
        for %ADU{transaction_id: ^transaction_id, pdu: pdu} <- ADU.decode(binary, []) do
          PDU.decode_response(pdu)
        end

      {:reply, res_tuple, state}
    else
      {:send, {:error, reason}} ->
        Logger.warning(
          "#{__MODULE__}: :call send failed, the reason is #{inspect(reason)}, :recall."
        )

        :ok = transport.close(socket)
        state = %{state | socket: nil}
        {:noreply, state, {:continue, {:recall, unit_id, request, timeout, from}}}

      {:recv, {:error, reason}} ->
        Logger.warning(
          "#{__MODULE__}: :call recv failed, the reason is #{inspect(reason)}, :recall."
        )

        :ok = transport.close(socket)
        state = %{state | socket: nil}
        {:noreply, state, {:continue, {:recall, unit_id, request, timeout, from}}}
    end
  end

  def handle_call({:call, _unit_id, _request, _timeout}, _from, %{active: true} = _state) do
    raise RuntimeError, message: "call can't be used when active is true."
  end

  @impl true
  def handle_cast({:cast, unit_id, request, from_pid}, %{active: true} = state) do
    %{
      transport: transport,
      socket: socket,
      transaction_id: transaction_id,
      transactions: transactions
    } = state

    transaction_id = ADU.increment_transaction_id(transaction_id)
    adu = PDU.encode_request!(request) |> ADU.new(transaction_id, unit_id) |> ADU.encode()

    state = %{state | transaction_id: transaction_id}

    case transport.send(socket, adu) do
      :ok ->
        transaction = %Transaction{
          unit_id: unit_id,
          request: request,
          from_pid: from_pid,
          sent_time: System.monotonic_time(:millisecond)
        }

        transactions = Map.put(transactions, transaction_id, transaction)
        {:noreply, %{state | transactions: transactions}}

      {:error, reason} ->
        Logger.warning(
          "#{__MODULE__}: :cast send failed, the reason is #{inspect(reason)}, :recast."
        )

        :ok = transport.close(socket)
        state = %{state | socket: nil}
        {:noreply, state, {:continue, {:recast, unit_id, request, from_pid}}}
    end
  end

  def handle_cast({:cast, _unit_id, _request, _from_pid}, %{active: false} = _state) do
    raise RuntimeError, message: "cast can't be used when active is false."
  end

  @impl true
  def handle_info({:tcp, socket, binary}, %{socket: socket} = state) do
    %{transactions: transactions} = state

    transactions =
      ADU.decode(binary, [])
      |> Enum.reduce(transactions, fn %ADU{transaction_id: transaction_id, pdu: pdu}, acc ->
        {transaction, acc} = Map.pop(acc, transaction_id)
        res_tuple = PDU.decode_response(pdu)

        send(
          transaction.from_pid,
          {
            :modbuzz,
            transaction.unit_id,
            transaction.request,
            res_tuple
          }
        )

        acc
      end)

    {:noreply, %{state | transactions: transactions}}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket, active: true} = state) do
    %{transport: transport, transactions: transactions} = state

    Logger.warning("#{__MODULE__}: transport closed.")
    :ok = transport.close(socket)
    state = %{state | socket: nil}

    transactions
    |> Enum.filter(fn {_transaction_id, transaction} ->
      System.monotonic_time(:millisecond) - transaction.sent_time < 10
    end)
    |> case do
      [] ->
        {:noreply, state, {:continue, :connect}}

      [{_transaction_id, transaction}] ->
        Logger.debug("#{__MODULE__}: sent successfully but RST ACK received, :recast.")

        {:noreply, state,
         {:continue, {:recast, transaction.unit_id, transaction.request, transaction.from_pid}}}
    end
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket, active: true} = state) do
    %{transport: transport} = state
    Logger.error("#{__MODULE__}: transport error, the reason is #{inspect(reason)}.")
    :ok = transport.close(socket)
    {:noreply, %{state | socket: nil}, {:continue, :connect}}
  end

  defp gen_tcp_connect(state) do
    %{transport: transport, address: address, port: port, active: active} = state

    transport.connect(
      address,
      port,
      [mode: :binary, packet: :raw, active: active],
      _timeout = 3000
    )
  end
end
