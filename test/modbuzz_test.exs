defmodule ModbuzzTest do
  use ExUnit.Case

  @test_address {127, 0, 0, 1}
  @test_port_1 502 * 100
  @test_port_2 503 * 100

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    on_exit(fn ->
      :ok = Application.stop(:modbuzz)
      :ok = Application.start(:modbuzz)
    end)

    :ok
  end

  describe "start_data_server/1" do
    test "return ok, return error tuple" do
      name = :data_server

      assert :ok = Modbuzz.start_data_server(name)
      assert {:error, :already_started} = Modbuzz.start_data_server(name)
    end

    test "multiple instance" do
      assert :ok = Modbuzz.start_data_server(:data_server_1)
      assert :ok = Modbuzz.start_data_server(:data_server_2)
    end
  end

  describe "start_tcp_client/3" do
    test "return ok, return error tuple" do
      name = :client

      assert :ok = Modbuzz.start_tcp_client(name, @test_address, @test_port_1)

      assert {:error, :already_started} =
               Modbuzz.start_tcp_client(name, @test_address, @test_port_1)
    end

    test "multiple instance" do
      assert :ok = Modbuzz.start_tcp_client(:client_1, @test_address, @test_port_1)
      assert :ok = Modbuzz.start_tcp_client(:client_2, @test_address, @test_port_2)
    end
  end

  describe "start_tcp_server/4" do
    test "return ok, return error tuple" do
      name = :server

      assert :ok = Modbuzz.start_tcp_server(name, @test_address, @test_port_1, :no_source)

      assert {:error, :already_started} =
               Modbuzz.start_tcp_server(name, @test_address, @test_port_1, :no_source)
    end

    test "multiple instance" do
      assert :ok = Modbuzz.start_tcp_server(:server_1, @test_address, @test_port_1, :no_source)
      assert :ok = Modbuzz.start_tcp_server(:server_2, @test_address, @test_port_2, :no_source)
    end
  end

  describe "request/3" do
    setup do
      :ok = Modbuzz.start_data_server(:data_server_1)
      :ok = Modbuzz.start_tcp_server(:server_1, @test_address, @test_port_1, :data_server_1)
      :ok = Modbuzz.start_tcp_client(:client_1, @test_address, @test_port_1)
    end

    test "return ok tuple" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, response)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} = Modbuzz.request(:client_1, 0, request)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} =
               Modbuzz.request(:data_server_1, 0, request)
    end

    test "return ok tuple, callback returns response" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, fn _request -> response end)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} = Modbuzz.request(:client_1, 0, request)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} =
               Modbuzz.request(:data_server_1, 0, request)
    end

    test "multiple instance" do
      :ok = Modbuzz.start_data_server(:data_server_2)
      :ok = Modbuzz.start_tcp_server(:server_2, @test_address, @test_port_2, :data_server_2)
      :ok = Modbuzz.start_tcp_client(:client_2, @test_address, @test_port_2)

      request_1 = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response_1 = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      request_2 = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 8}

      response_2 = %Modbuzz.PDU.ReadDiscreteInputs.Res{
        byte_count: 1,
        input_status: List.duplicate(true, 8)
      }

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.create_unit(:data_server_2)
      :ok = Modbuzz.upsert(:data_server_1, request_1, response_1)
      :ok = Modbuzz.upsert(:data_server_2, request_2, response_2)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} =
               Modbuzz.request(:client_1, 0, request_1)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} =
               Modbuzz.request(:client_2, 0, request_2)
    end
  end

  describe "create_unit/2, upsert/4, delete/3, dump/2" do
    setup do
      :ok = Modbuzz.start_data_server(:data_server)

      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      %{request: request, response: response}
    end

    test "create_unit/2" do
      assert :ok = Modbuzz.create_unit(:data_server, 1)
      assert {:error, :already_created} = Modbuzz.create_unit(:data_server, 1)
    end

    test "upsert/4", %{request: request, response: response} do
      assert {:error, :unit_not_found} = Modbuzz.upsert(:data_server, 1, request, response)
      :ok = Modbuzz.create_unit(:data_server, 1)
      assert :ok = Modbuzz.upsert(:data_server, 1, request, fn _request -> response end)
    end

    test "delete/3", %{request: request, response: _response} do
      assert {:error, :unit_not_found} = Modbuzz.delete(:data_server, 1, request)
      :ok = Modbuzz.create_unit(:data_server, 1)
      assert :ok = Modbuzz.delete(:data_server, 1, request)
    end

    test "dump/2", %{request: request, response: response} do
      assert {:error, :unit_not_found} = Modbuzz.dump(:data_server, 1)
      :ok = Modbuzz.create_unit(:data_server, 1)
      :ok = Modbuzz.upsert(:data_server, 1, request, response)
      assert Modbuzz.dump(:data_server, 1) == {:ok, %{request => response}}
    end
  end

  describe "gateway" do
    setup do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      :ok = Modbuzz.start_data_server(:data_server)
      :ok = Modbuzz.create_unit(:data_server, 1)
      :ok = Modbuzz.upsert(:data_server, 1, request, response)

      %{request: request, response: response}
    end

    test "TCP/TCP", %{request: request, response: response} do
      :ok = Modbuzz.start_tcp_server(:server_1, @test_address, @test_port_1, :data_server)
      :ok = Modbuzz.start_tcp_client(:client_1, @test_address, @test_port_1)

      :ok = Modbuzz.start_tcp_server(:server_2, @test_address, @test_port_2, :client_1)
      :ok = Modbuzz.start_tcp_client(:client_2, @test_address, @test_port_2)

      assert Modbuzz.request(:client_1, 1, request) == {:ok, response}
      assert Modbuzz.request(:client_2, 1, request) == {:ok, response}
    end

    test "TCP/RTU", %{request: request, response: response} do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)
      |> expect(:controlling_process, fn _transport_pid, _pid -> :ok end)
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      {:ok, _pid} =
        start_supervised(
          {Modbuzz.RTU.ClientSupervisor,
           [name: :rtu_client, transport: Modbuzz.RTU.TransportMock, device_name: "ttyTEST"]},
          restart: :temporary
        )

      :ok = Modbuzz.start_tcp_server(:tcp_server, @test_address, @test_port_1, :rtu_client)
      :ok = Modbuzz.start_tcp_client(:tcp_client, @test_address, @test_port_1)

      task = Task.async(fn -> Modbuzz.request(:tcp_client, 1, request) end)

      pid = Modbuzz.RTU.Client.Receiver.pid(:rtu_client)

      response_binary =
        response
        |> Modbuzz.PDU.encode()
        |> Modbuzz.RTU.ADU.new(1)
        |> Modbuzz.RTU.ADU.encode()

      Process.send_after(pid, {:circuits_uart, "ttyTest", response_binary}, 10)

      assert Task.await(task) == {:ok, response}
    end

    @tag :skip
    test "TCP/RTU, with a real sensor" do
      :ok = Modbuzz.start_rtu_client(:rtu_client, "ttyUSB0", speed: 9600)
      :ok = Modbuzz.start_tcp_server(:tcp_server, @test_address, @test_port_1, :rtu_client)
      :ok = Modbuzz.start_tcp_client(:tcp_client, @test_address, @test_port_1)

      request = %Modbuzz.PDU.ReadHoldingRegisters.Req{
        starting_address: 0,
        quantity_of_registers: 2
      }

      assert {:ok, %Modbuzz.PDU.ReadHoldingRegisters.Res{}} =
               Modbuzz.request(:tcp_client, 1, request)
    end

    test "RTU/TCP", %{request: request, response: response} do
      me = self()

      :ok = Modbuzz.start_tcp_server(:tcp_server, @test_address, @test_port_1, :data_server)
      :ok = Modbuzz.start_tcp_client(:tcp_client, @test_address, @test_port_1)

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)
      |> expect(:write, fn _transport_pid, binary ->
        send(me, binary)
        :ok
      end)

      {:ok, pid} =
        start_supervised(
          {Modbuzz.RTU.Server,
           [
             name: :rtu_server,
             transport: Modbuzz.RTU.TransportMock,
             device_name: "ttyTEST",
             data_source: :tcp_client
           ]},
          restart: :temporary
        )

      # NOTE: Simulating an RTU client request to the RTU server
      request_binary =
        request
        |> Modbuzz.PDU.encode()
        |> Modbuzz.RTU.ADU.new(1)
        |> Modbuzz.RTU.ADU.encode()

      Process.send_after(pid, {:circuits_uart, "ttyTest", request_binary}, 10)

      # NOTE: Confirm that the RTU server has written the response
      receive do
        binary ->
          {:ok, adu} = Modbuzz.RTU.ADU.decode_response(binary)
          assert Modbuzz.PDU.decode_response(adu.pdu) == {:ok, response}
      end
    end
  end
end
