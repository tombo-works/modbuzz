defmodule Modbuzz.TCP.Server.SocketHandlerTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  test "does not send when recv has only a partial ADU binary" do
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
    |> expect(:recv, fn ^socket, _length = 0, _timeout ->
      {:ok, partial_adu_binary}
    end)
    |> expect(:recv, fn ^socket, _length = 0, _timeout -> {:error, :closed} end)
    |> expect(:close, fn ^socket ->
      send(me, :closed)
      :ok
    end)

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

    assert_receive(:closed)
  end
end
