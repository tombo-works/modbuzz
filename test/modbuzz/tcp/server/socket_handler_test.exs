defmodule Modbuzz.TCP.Server.SocketHandlerTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  test "does not send when socket receives only a partial ADU binary" do
    socket = make_ref()
    me = self()

    request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 1}

    encoded_adu_binary =
      request
      |> Modbuzz.TCP.ADU.new(_transaction_id = 0x0001, _unit_id = 0x00)
      |> Modbuzz.TCP.ADU.encode()

    partial_size = byte_size(encoded_adu_binary) - 1
    # Drop the last byte on purpose so the socket handler receives an incomplete ADU binary.
    <<partial_adu_binary::binary-size(partial_size), _last_byte>> = encoded_adu_binary

    Modbuzz.TCP.TransportMock
    |> expect(:setopts, fn ^socket, active: :once -> :ok end)
    |> expect(:send, 0, fn _, _ -> :ok end)
    |> expect(:close, fn ^socket ->
      send(me, :closed)
      :ok
    end)

    pid =
      start_link_supervised!(
        {Modbuzz.TCP.Server.SocketHandler,
         [
           transport: Modbuzz.TCP.TransportMock,
           address: {127, 0, 0, 1},
           port: 50_200,
           socket: socket,
           data_source: self(),
           timeout: 10
         ]},
        restart: :temporary
      )

    send(pid, {:tcp, socket, partial_adu_binary})
    send(pid, {:tcp_closed, socket})

    assert_receive(:closed)
  end
end
