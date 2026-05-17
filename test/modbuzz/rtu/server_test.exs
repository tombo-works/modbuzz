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

      on_exit(fn ->
        :ok = Application.stop(:modbuzz)
        :ok = Application.start(:modbuzz)
      end)

      unit_id = 0x01
      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 2}
      response = %Modbuzz.PDU.ReadCoils.Res{coil_status: [true, false]}

      Modbuzz.create_unit(:data_server, unit_id)
      :ok = Modbuzz.upsert(:data_server, unit_id, request, response)

      request_binary =
        request
        |> Modbuzz.RTU.ADU.new(unit_id)
        |> Modbuzz.RTU.ADU.encode()

      response_binary =
        response
        |> Modbuzz.RTU.ADU.new(unit_id)
        |> Modbuzz.RTU.ADU.encode()

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      device_name = "ttyTEST"

      {:ok, pid} =
        start_supervised(
          {Modbuzz.RTU.Server,
           [
             name: :server,
             transport: Modbuzz.RTU.TransportMock,
             device_name: device_name,
             data_source: :data_server
           ]},
          restart: :temporary
        )

      %{
        request_binary: request_binary,
        response_binary: response_binary,
        device_name: device_name,
        pid: pid
      }
    end

    test "handle request binary all at once", %{
      request_binary: request_binary,
      response_binary: response_binary,
      device_name: device_name,
      pid: pid
    } do
      me = self()

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _transport_pid, binary ->
        send(me, binary)
        :ok
      end)

      send(pid, {:circuits_uart, device_name, request_binary})

      assert_receive ^response_binary
    end

    test "handle request binary in two parts", %{
      request_binary: request_binary,
      response_binary: response_binary,
      device_name: device_name,
      pid: pid
    } do
      me = self()

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _transport_pid, binary ->
        send(me, binary)
        :ok
      end)

      <<part1::binary-size(2), part2::binary>> = request_binary

      send(pid, {:circuits_uart, device_name, part1})
      send(pid, {:circuits_uart, device_name, part2})

      assert_receive ^response_binary
    end

    test "clears buffer and recovers on unknown function code binary", %{
      request_binary: request_binary,
      response_binary: response_binary,
      device_name: device_name,
      pid: pid
    } do
      me = self()

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _transport_pid, binary ->
        send(me, binary)
        :ok
      end)

      unit_id = <<0x01>>
      unknown_function_code = <<0x00>>
      fake_crc = <<0x00, 0x00>>

      unknown_function_binary = unit_id <> unknown_function_code <> fake_crc

      send(pid, {:circuits_uart, device_name, unknown_function_binary})
      send(pid, {:circuits_uart, device_name, request_binary})

      assert_receive ^response_binary
    end

    test "clears buffer and recovers on binary_is_long binary", %{
      request_binary: request_binary,
      response_binary: response_binary,
      device_name: device_name,
      pid: pid
    } do
      me = self()

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _transport_pid, binary ->
        send(me, binary)
        :ok
      end)

      unit_id = <<0x01>>
      fixed_pdu = <<0x01, 0x00, 0x00, 0x00, 0x02>>
      extra_byte = <<0xFF>>
      fake_crc = <<0x00, 0x00>>

      long_binary = unit_id <> fixed_pdu <> extra_byte <> fake_crc

      send(pid, {:circuits_uart, device_name, long_binary})
      send(pid, {:circuits_uart, device_name, request_binary})

      assert_receive ^response_binary
    end
  end
end
