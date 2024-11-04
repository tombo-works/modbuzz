defmodule Modbuzz.RTU.Client do
  use GenServer

  alias Modbuzz.PDU
  alias Modbuzz.RTU.ADU
  alias Modbuzz.RTU.Client.Receiver

  @server_device_busy 0x06

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

  def handle_call({:call, unit_id, request, _timeout}, from, state) do
    %{
      transport: transport,
      transport_pid: transport_pid,
      receiver: receiver
    } = state

    adu = PDU.encode_request!(request) |> ADU.new(unit_id)

    if Receiver.busy_with?(receiver, adu) do
      err = PDU.to_error(request, @server_device_busy)

      {:reply, {:error, err}, state}
    else
      to = from

      case Receiver.will_respond(receiver, to, adu) do
        :ok ->
          binary = ADU.encode(adu)
          transport.write(transport_pid, binary)
          {:noreply, state}

        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    end
  end
end
