defmodule Modbuzz.TCP.Server.SocketHandler do
  @moduledoc false

  use GenServer, restart: :temporary

  alias Modbuzz.TCP.ADU
  alias Modbuzz.TCP.Log

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    transport = Keyword.fetch!(args, :transport)
    address = Keyword.fetch!(args, :address)
    port = Keyword.fetch!(args, :port)
    socket = Keyword.fetch!(args, :socket)
    data_source = Keyword.fetch!(args, :data_source)
    timeout = Keyword.get(args, :timeout, 5000)

    {:ok,
     %{
       transport: transport,
       address: address,
       port: port,
       socket: socket,
       data_source: data_source,
       timeout: timeout,
       binary: <<>>
     }}
  end

  def handle_info({:tcp, socket, recv_binary}, %{socket: socket} = state) do
    %{
      transport: transport
    } = state

    binary = state.binary <> recv_binary

    case ADU.decode_request(binary, []) do
      {:ok, {adu_tuples, rest_binary}} ->
        response_binary =
          Enum.reduce(adu_tuples, <<>>, fn {:ok, adu}, acc ->
            response_pdu_or_nil = request(adu, state)
            acc <> to_adu_binary(response_pdu_or_nil, adu.transaction_id, adu.unit_id)
          end)

        if response_binary != <<>>, do: transport.send(socket, response_binary)

        case set_active_once(transport, socket) do
          :ok ->
            {:noreply, %{state | binary: rest_binary}}

          {:error, reason} ->
            Log.error("setopts error", reason, state)
            :ok = transport.close(socket)
            {:stop, reason, state}
        end

      {:error, reason} ->
        Log.error("decode error", reason, state)
        :ok = transport.close(socket)
        {:stop, reason, state}
    end
  end

  def handle_info({:tcp, _socket, _binary}, state) do
    Log.warning("tcp message from stale socket ignored", nil, state)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    %{transport: transport} = state

    :ok = transport.close(socket)
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Log.warning("tcp_closed message from stale socket ignored", nil, state)
    {:noreply, state}
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    %{transport: transport} = state

    Log.error("tcp error", reason, state)
    :ok = transport.close(socket)
    {:stop, reason, state}
  end

  def handle_info({:tcp_error, _socket, _reason}, state) do
    Log.warning("tcp_error message from stale socket ignored", nil, state)
    {:noreply, state}
  end

  defp request(adu, state) do
    %{
      data_source: data_source,
      timeout: timeout
    } = state

    case GenServer.call(data_source, {:call, adu.unit_id, adu.pdu, timeout}, timeout + 50) do
      {:ok, pdu} when is_struct(pdu) ->
        pdu

      {:error, pdu} when is_struct(pdu) ->
        pdu

      {:error, reason} ->
        Log.error("request to data source failed", reason, state)
        nil
    end
  end

  defp to_adu_binary(pdu, transaction_id, unit_id) do
    case pdu do
      pdu when is_struct(pdu) ->
        ADU.new(pdu, transaction_id, unit_id) |> ADU.encode()

      nil ->
        <<>>
    end
  end

  defp set_active_once(:gen_tcp, socket), do: :inet.setopts(socket, active: :once)
  defp set_active_once(transport, socket), do: transport.setopts(socket, active: :once)
end
