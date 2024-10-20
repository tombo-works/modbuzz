defmodule Modbuzz.RTU.Client do
  use GenServer

  alias Modbuzz.RTU.Log

  alias Modbuzz.RTU.ADU
  alias Modbuzz.PDU

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.get(args, :name, __MODULE__)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  @spec call(
          GenServer.server(),
          unit_id :: 0x00..0xFF,
          request :: Modbuzz.PDU.Protocol.t(),
          timeout()
        ) :: {:ok, response :: term()} | {:error, reason :: term()}
  def call(name \\ __MODULE__, unit_id, request, timeout \\ 5000)
      when unit_id in 0x00..0xFF and is_struct(request) and is_integer(timeout) do
    GenServer.call(name, {:call, unit_id, request, timeout})
  end

  def init(args) when is_list(args) do
    transport = Keyword.get(args, :transport, Circuits.UART)
    transport_opts = Keyword.get(args, :transport_opts, []) ++ [active: false]
    device_name = Keyword.fetch!(args, :device_name)

    {:ok, pid} = transport.start_link([])
    :ok = transport.open(pid, device_name, transport_opts)

    {:ok,
     %{
       transport: transport,
       transport_opts: transport_opts,
       device_name: device_name,
       pid: pid,
       binary: <<>>,
       recall: false
     }}
  end

  def handle_call({:call, unit_id, request, timeout}, from, state) do
    %{transport: transport, pid: pid} = state

    adu = PDU.encode_request!(request) |> ADU.new(unit_id) |> ADU.encode()

    case transport.write(pid, adu, timeout) do
      :ok ->
        {:noreply, state, {:continue, {:read, unit_id, request, timeout, from}}}

      {:error, reason} ->
        Log.warning(":call write failed, :recall", reason, state)

        {:noreply, %{state | recall: true},
         {:continue, {:recall, unit_id, request, timeout, from}}}
    end
  end

  def handle_continue({:recall, unit_id, request, timeout, from}, %{recall: true} = state) do
    %{
      transport: transport,
      transport_opts: transport_opts,
      device_name: device_name,
      pid: pid
    } = state

    adu = PDU.encode_request!(request) |> ADU.new(unit_id) |> ADU.encode()

    with {:close, :ok} <- {:close, transport.close(pid)},
         {:open, :ok} <- {:open, transport.open(pid, device_name, transport_opts)},
         {:write, :ok} <- {:write, transport.write(pid, adu, timeout)} do
      {:noreply, state, {:continue, {:read, unit_id, request, timeout, from}}}
    else
      {:close, {:error, reason}} ->
        Log.warning(":recall close failed", reason, state)
        {:noreply, %{state | recall: false}}

      {:open, {:error, reason}} ->
        Log.warning(":recall open failed", reason, state)
        {:noreply, %{state | recall: false}}

      {:write, {:error, reason}} ->
        Log.warning(":recall write failed", reason, state)
        {:noreply, %{state | recall: false}}
    end
  end

  def handle_continue({:read, unit_id, request, timeout, from}, state) do
    %{transport: transport, pid: pid, recall: recall} = state

    case transport.read(pid, 100) do
      {:ok, <<>>} ->
        if recall do
          Log.error(":recall no response", nil, state)
          {:noreply, %{state | binary: <<>>, recall: false}}
        else
          Log.warning(":call no response, :recall", nil, state)

          {:noreply, %{state | binary: <<>>, recall: true},
           {:continue, {:recall, unit_id, request, timeout, from}}}
        end

      {:ok, binary} ->
        new_binary = state.binary <> binary

        with {:ok, %ADU{unit_id: ^unit_id, pdu: pdu}} <- ADU.decode_response(new_binary) do
          res_tuple = PDU.decode_response(pdu)
          GenServer.reply(from, res_tuple)
          {:noreply, %{state | binary: <<>>, recall: false}}
        else
          {:error, :binary_is_short} ->
            {:noreply, %{state | binary: new_binary},
             {:continue, {:read, unit_id, request, timeout, from}}}

          {:error, :crc_error} ->
            GenServer.reply(from, {:error, :crc_error})
            {:noreply, %{state | binary: <<>>, recall: false}}
        end

      {:error, reason} ->
        if recall do
          Log.error(":recall read failed", reason, state)
          {:noreply, %{state | binary: <<>>, recall: false}}
        else
          Log.warning(":call read failed, :recall", reason, state)

          {:noreply, %{state | binary: <<>>, recall: true},
           {:continue, {:recall, unit_id, request, timeout, from}}}
        end
    end
  end
end
