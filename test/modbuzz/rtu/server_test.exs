defmodule Modbuzz.RTU.ServerTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "start_link/1" do
    test "return :ok tuple" do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      assert {:ok, _pid} =
               Modbuzz.RTU.Server.start_link(
                 name: :server,
                 transport: Modbuzz.RTU.TransportMock,
                 device_name: "ttyTEST",
                 data_source: :data_server
               )
    end
  end

  describe "transport message" do
    setup do
      Modbuzz.start_data_server(:data_server)

      unit_id = 0x01
      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 2}
      response = %Modbuzz.PDU.ReadCoils.Res{coil_status: [true, false]}

      Modbuzz.create_unit(:data_server, unit_id)
      :ok = Modbuzz.upsert(:data_server, unit_id, request, response)

      request_binary =
        request
        |> Modbuzz.PDU.encode()
        |> Modbuzz.RTU.ADU.new(unit_id)
        |> Modbuzz.RTU.ADU.encode()

      response_binary =
        response
        |> Modbuzz.PDU.encode()
        |> Modbuzz.RTU.ADU.new(unit_id)
        |> Modbuzz.RTU.ADU.encode()

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      {:ok, pid} =
        start_supervised(
          {Modbuzz.RTU.Server,
           [
             name: :server,
             transport: Modbuzz.RTU.TransportMock,
             device_name: "ttyTEST",
             data_source: :data_server
           ]},
          restart: :temporary
        )

      %{
        request_binary: request_binary,
        response_binary: response_binary,
        pid: pid
      }
    end

    test "handle request binary all at once", %{
      request_binary: request_binary,
      response_binary: response_binary,
      pid: pid
    } do
      me = self()

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _transport_pid, binary ->
        send(me, binary)
        :ok
      end)

      send(pid, {:circuits_uart, "ttyTest", request_binary})

      assert_receive ^response_binary
    end

    test "handle request binary in two parts", %{
      request_binary: request_binary,
      response_binary: response_binary,
      pid: pid
    } do
      me = self()

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _transport_pid, binary ->
        send(me, binary)
        :ok
      end)

      <<part1::binary-size(2), part2::binary>> = request_binary

      send(pid, {:circuits_uart, "ttyTest", part1})
      send(pid, {:circuits_uart, "ttyTest", part2})

      assert_receive ^response_binary
    end
  end
end
