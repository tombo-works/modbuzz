defmodule Modbuzz.TCP.Client do
  use GenServer

  require Logger

  alias Modbuzz.PDU

  @unit_id_byte_size 1

  def start_link(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def call(name, unit_id \\ 0, request, timeout \\ 5000)
      when unit_id in 0x00..0xFF and is_struct(request) and is_integer(timeout) do
    GenServer.call(name, {:call, unit_id, request, timeout})
  end

  def cast(name, unit_id \\ 0, request) when unit_id in 0x00..0xFF and is_struct(request) do
    GenServer.cast(name, {:cast, unit_id, request, self()})
  end

  @impl true
  def init(args) when is_list(args) do
    address = Keyword.get(args, :address, {192, 168, 5, 57})
    port = Keyword.get(args, :port, 502)
    active = Keyword.get(args, :active, true)

    state = %{
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
  def handle_continue(:connect, state) do
    case gen_tcp_connect(state) do
      {:ok, socket} ->
        Logger.debug("#{__MODULE__}: :connect succeeded.")
        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
        Logger.error("#{__MODULE__}: :connect failed, the reason is #{inspect(reason)}.")
        {:noreply, state, {:continue, :connect}}
    end
  end

  def handle_continue({:recall, unit_id, request, timeout, from}, state) do
    %{socket: socket, transaction_id: transaction_id} = state

    transaction_id = increment_transaction_id(transaction_id)
    adu = adu(unit_id, request, transaction_id)
    state = %{state | transaction_id: transaction_id}

    with :ok = :gen_tcp.close(socket),
         {:connect, {:ok, socket}} = {:connect, gen_tcp_connect(state)},
         {:send, :ok} <- {:send, :gen_tcp.send(socket, adu)},
         {:recv, {:ok, binary}} <- {:recv, :gen_tcp.recv(socket, _length = 0, timeout)},
         <<^transaction_id::16, _rest::binary>> <- binary do
      [decoded_pdu] = for {_transaction_id, pdu} <- pdus(binary), do: PDU.decode(request, pdu)
      GenServer.reply(from, decoded_pdu)
      {:noreply, %{state | socket: socket}}
    else
      {:connect, {:error, reason} = error} ->
        Logger.error("#{__MODULE__}: :recall connect failed, the reason is #{inspect(reason)}.")
        GenServer.reply(from, error)
        {:noreply, %{state | socket: nil}, {:continue, :connect}}

      {:send, {:error, reason} = error} ->
        Logger.error("#{__MODULE__}: :recall send failed, the reason is #{inspect(reason)}.")
        GenServer.reply(from, error)
        {:noreply, %{state | socket: socket}}

      {:recv, {:error, reason} = error} ->
        Logger.error("#{__MODULE__}: :recall recv failed, the reason is #{inspect(reason)}.")
        GenServer.reply(from, error)
        {:noreply, %{state | socket: socket}}

      <<received_transaction_id::16, _rest::binary>> = binary when is_binary(binary) ->
        Logger.error(
          """
          #{__MODULE__}: transaction id is not matched.
          the request is #{inspect(request)}.
          the received binary is #{inspect(binary)}.
          the expected transaction id is #{inspect(transaction_id)}.
          the received transaction id is #{inspect(received_transaction_id)}.
          """
          |> String.trim_trailing()
        )

        GenServer.reply(from, {:error, :transaction_id_mismatch})
        {:noreply, %{state | socket: socket}}
    end
  end

  def handle_continue({:recast, unit_id, request, from_pid}, state) do
    %{socket: socket, transaction_id: transaction_id, transactions: transactions} = state

    transaction_id = increment_transaction_id(transaction_id)
    adu = adu(unit_id, request, transaction_id)
    state = %{state | transaction_id: transaction_id}

    with :ok <- :gen_tcp.close(socket),
         {:connect, {:ok, socket}} <- {:connect, gen_tcp_connect(state)},
         {:send, :ok} <- {:send, :gen_tcp.send(socket, adu)} do
      transactions = Map.put(transactions, transaction_id, {unit_id, request, from_pid})
      {:noreply, %{state | socket: socket, transactions: transactions}}
    else
      {:connect, {:error, reason}} ->
        Logger.error("#{__MODULE__}: :recast connect failed, the reason is #{inspect(reason)}.")
        {:noreply, %{state | socket: nil}, {:continue, :connect}}

      {:send, {:error, reason}} ->
        Logger.error("#{__MODULE__}: :recast send failed, the reason is #{inspect(reason)}.")
        {:noreply, %{state | socket: socket}}
    end
  end

  @impl true
  def handle_call({:call, unit_id, request, timeout}, from, %{active: false} = state) do
    %{socket: socket, transaction_id: transaction_id} = state

    transaction_id = increment_transaction_id(transaction_id)
    adu = adu(unit_id, request, transaction_id)
    state = %{state | transaction_id: transaction_id}

    with {:send, :ok} <- {:send, :gen_tcp.send(socket, adu)},
         {:recv, {:ok, binary}} <- {:recv, :gen_tcp.recv(socket, _length = 0, timeout)},
         <<^transaction_id::16, _rest::binary>> <- binary do
      [decoded_pdu] = for {_transaction_id, pdu} <- pdus(binary), do: PDU.decode(request, pdu)
      {:reply, decoded_pdu, state}
    else
      {:send, {:error, reason}} ->
        Logger.warning(
          "#{__MODULE__}: :call send failed, the reason is #{inspect(reason)}, :recall."
        )

        {:noreply, state, {:continue, {:recall, unit_id, request, timeout, from}}}

      {:recv, {:error, reason}} ->
        Logger.warning(
          "#{__MODULE__}: :call recv failed, the reason is #{inspect(reason)}, :recall."
        )

        {:noreply, state, {:continue, {:recall, unit_id, request, timeout, from}}}

      <<received_transaction_id::16, _rest::binary>> = binary when is_binary(binary) ->
        Logger.error(
          """
          #{__MODULE__}: transaction id is not matched.
          the request is #{inspect(request)}.
          the received binary is #{inspect(binary)}.
          the expected transaction id is #{inspect(transaction_id)}.
          the received transaction id is #{inspect(received_transaction_id)}.
          """
          |> String.trim_trailing()
        )

        {:reply, {:error, :transaction_id_mismatch}, state}
    end
  end

  def handle_call({:call, _unit_id, _request, _timeout}, _from, %{active: true} = _state) do
    raise RuntimeError, message: "call can't be used when active is true."
  end

  @impl true
  def handle_cast({:cast, unit_id, request, from_pid}, %{active: true} = state) do
    %{socket: socket, transaction_id: transaction_id, transactions: transactions} = state

    transaction_id = increment_transaction_id(transaction_id)
    adu = adu(unit_id, request, transaction_id)
    state = %{state | transaction_id: transaction_id}

    case :gen_tcp.send(socket, adu) do
      :ok ->
        transactions = Map.put(transactions, transaction_id, {unit_id, request, from_pid})
        {:noreply, %{state | transactions: transactions}}

      {:error, reason} ->
        Logger.warning(
          "#{__MODULE__}: :cast send failed, the reason is #{inspect(reason)}, :recast."
        )

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
      Enum.reduce(pdus(binary), transactions, fn {transaction_id, pdu}, acc ->
        {{_unit_id, request, from_pid}, acc} = Map.pop(acc, transaction_id)
        send(from_pid, PDU.decode(request, pdu))
        acc
      end)

    {:noreply, %{state | transactions: transactions}}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.warning("#{__MODULE__}: :gen_tcp closed.")
    :ok = :gen_tcp.close(socket)
    {:noreply, %{state | socket: nil}, {:continue, :connect}}
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    Logger.error("#{__MODULE__}: :gen_tcp error, the reason is #{inspect(reason)}.")
    :ok = :gen_tcp.close(socket)
    {:noreply, %{state | socket: nil}, {:continue, :connect}}
  end

  def adu(unit_id, request, transaction_id) do
    pdu = PDU.encode(request)
    mbap_header = mbap_header(transaction_id, byte_size(pdu) + @unit_id_byte_size, unit_id)
    <<mbap_header::binary, pdu::binary>>
  end

  def mbap_header(transaction_id, length, unit_id) do
    protocol_id = 0
    <<transaction_id::16, protocol_id::16, length::16, unit_id::8>>
  end

  def pdus(binary, acc \\ []) when is_binary(binary) do
    <<transaction_id::16, _protocol_id::16, length::16, _unit_id::8,
      pdu::binary-size(length - @unit_id_byte_size), rest::binary>> = binary

    acc = [{transaction_id, pdu} | acc]

    if rest == <<>>, do: Enum.reverse(acc), else: pdus(rest, acc)
  end

  defp gen_tcp_connect(state) do
    %{address: address, port: port, active: active} = state

    :gen_tcp.connect(
      address,
      port,
      [mode: :binary, packet: :raw, keepalive: true, active: active],
      _timeout = 3000
    )
  end

  defp increment_transaction_id(transaction_id) do
    if transaction_id == 0xFFFF, do: 0, else: transaction_id + 1
  end
end
