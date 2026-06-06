defmodule Modbuzz.TCP.ServerTest do
  use ExUnit.Case, async: false

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  test "stops started socket handler when controlling_process setup fails" do
    me = self()
    dummy_listen_socket = make_ref()
    dummy_accept_socket = make_ref()

    Modbuzz.TCP.TransportMock
    |> expect(:listen, fn _port, _opts -> {:ok, dummy_listen_socket} end)
    |> expect(:accept, fn ^dummy_listen_socket -> {:ok, dummy_accept_socket} end)
    |> stub(:accept, fn ^dummy_listen_socket ->
      # Keep the accept loop parked so this test only exercises the setup-failure path.
      receive do
      end
    end)
    |> expect(:controlling_process, fn ^dummy_accept_socket, socket_handler_pid ->
      send(me, {:socket_handler_pid, socket_handler_pid})
      {:error, :controlling_process_failed}
    end)
    |> expect(:close, fn ^dummy_accept_socket -> :ok end)

    start_link_supervised!(
      {Modbuzz.TCP.ServerSupervisor,
       [
         via_name: Modbuzz.TCP.ServerSupervisor.name(:tcp_server),
         address: {127, 0, 0, 1},
         port: 50_299,
         # this test doesn't need data_source
         data_source: nil,
         transport: Modbuzz.TCP.TransportMock
       ]},
      restart: :temporary
    )

    assert_receive {:socket_handler_pid, socket_handler_pid}

    # Confirm the socket handler that was started is explicitly terminated on setup failure.
    ref = Process.monitor(socket_handler_pid)
    assert_receive {:DOWN, ^ref, :process, ^socket_handler_pid, _reason}
  end
end
