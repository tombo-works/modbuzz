defmodule Modbuzz.RTU.Client do
  @moduledoc false

  use GenServer

  alias Modbuzz.PDU
  alias Modbuzz.RTU.ADU
  alias Modbuzz.RTU.Client.Receiver

  def call(name, unit_id, request, timeout \\ 5000) do
    GenServer.call(name, {:call, unit_id, request, timeout}, timeout + 10)
  end

  def start_link(args) do
    name = Keyword.fetch!(args, :name)
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    name = Keyword.fetch!(args, :name)
    transport = Keyword.get(args, :transport, Circuits.UART)
    transport_opts = Keyword.get(args, :transport_opts, []) ++ [active: true]
    device_name = Keyword.fetch!(args, :device_name)

    receiver = Receiver.name(name)

    {:ok, transport_pid} = transport.start_link([])
    :ok = transport.open(transport_pid, device_name, transport_opts)
    :ok = transport.controlling_process(transport_pid, GenServer.whereis(receiver))

    {:ok,
     %{
       transport: transport,
       transport_pid: transport_pid,
       receiver: receiver
     }}
  end

  def handle_call({:call, unit_id, request, timeout}, from, state) do
    %{
      transport: transport,
      transport_pid: transport_pid,
      receiver: receiver
    } = state

    adu = PDU.encode(request) |> ADU.new(unit_id)

    if Receiver.busy_with?(receiver, adu) do
      err = PDU.to_error(request, :server_device_busy)

      {:reply, {:error, err}, state}
    else
      to = from

      case Receiver.will_respond(receiver, to, adu, timeout) do
        :ok ->
          binary = ADU.encode(adu)
          transport.write(transport_pid, binary, timeout)
          {:noreply, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end
end
