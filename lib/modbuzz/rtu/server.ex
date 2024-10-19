defmodule Modbuzz.RTU.Server do
  @moduledoc false

  use GenServer

  alias Modbuzz.RTU.Log

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) when is_list(args) do
    name = Keyword.fetch!(args, :name)

    GenServer.start_link(__MODULE__, args, name: name)
  end

  @doc false
  def init(args) do
    transport = Keyword.get(args, :transport, Circuits.UART)
    name = Keyword.fetch!(args, :name)
    device_name = Keyword.fetch!(args, :device_name)
    transport_opts = Keyword.get(args, :transport_opts, []) ++ [active: false]
    data_source = Keyword.fetch!(args, :data_source)
    timeout = Keyword.get(args, :timeout, 5000)

    {:ok, pid} = transport.start_link([])
    :ok = transport.open(pid, device_name, transport_opts)

    {:ok,
     %{
       transport: transport,
       name: name,
       device_name: device_name,
       transport_opts: transport_opts,
       data_source: data_source,
       pid: pid,
       timeout: timeout,
       last_binary: <<>>
     }, {:continue, :read}}
  end

  def handle_continue(:read, state) do
    %{
      transport: transport,
      pid: pid,
      data_source: data_source,
      timeout: timeout,
      last_binary: last_binary
    } = state

    case transport.read(pid) do
      {:ok, <<>> = _binary} ->
        {:noreply, state, {:continue, :read}}

      {:ok, binary} ->
        binary = last_binary <> binary

        try do
          adu = Modbuzz.RTU.ADU.decode!(binary)
          {:ok, request} = Modbuzz.PDU.decode_request(adu.pdu)

          request(data_source, adu.unit_id, request, timeout)
          |> Modbuzz.PDU.encode_response!()
          |> Modbuzz.RTU.ADU.new(adu.unit_id)
          |> Modbuzz.RTU.ADU.encode()
          |> then(&transport.write(pid, &1, timeout))

          {:noreply, state, {:continue, :read}}
        rescue
          MatchError ->
            Log.warning("MatchError happened.", nil, state)
            {:noreply, %{state | last_binary: binary}, {:continue, :read}}

          Modbuzz.RTU.Exceptions.CRCError ->
            Log.warning("CRCError happened.", nil, state)
            {:noreply, %{state | last_binary: <<>>}, {:continue, :read}}
        end

      {:error, reason} ->
        Log.error("unexpected", reason, state)
        {:noreply, %{state | last_binary: <<>>}, {:continue, :read}}
    end
  end

  defp request(data_source, unit_id, request, timeout) do
    try do
      case GenServer.call(data_source, {:call, unit_id, request, timeout}) do
        {:ok, response} -> response
        {:error, error} -> error
      end
    catch
      :exit, {:noproc, mfa} ->
        Log.error("`#{data_source}` not found. (mfa is #{inspect(mfa)})")
        Modbuzz.PDU.to_error(request)
    end
  end
end
