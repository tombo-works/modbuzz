defmodule ModbuzzTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

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

  describe "stop_data_server/1" do
    test "return ok, return error tuple" do
      name = :data_server

      :ok = Modbuzz.start_data_server(name)

      assert :ok = Modbuzz.stop_data_server(name)
      assert is_nil(GenServer.whereis(name))
      assert {:error, :not_started} = Modbuzz.stop_data_server(name)
    end
  end

  describe "start_tcp_client/3" do
    test "return ok, return error tuple" do
      name = :tcp_client

      assert :ok = Modbuzz.start_tcp_client(name, @test_address, @test_port_1)

      assert {:error, :already_started} =
               Modbuzz.start_tcp_client(name, @test_address, @test_port_1)
    end

    test "multiple instance" do
      assert :ok = Modbuzz.start_tcp_client(:client_1, @test_address, @test_port_1)
      assert :ok = Modbuzz.start_tcp_client(:client_2, @test_address, @test_port_2)
    end
  end

  describe "stop_tcp_client/1" do
    test "return ok, return error tuple" do
      name = :tcp_client

      :ok = Modbuzz.start_tcp_client(name, @test_address, @test_port_1)

      assert :ok = Modbuzz.stop_tcp_client(name)
      assert is_nil(GenServer.whereis(name))
      assert {:error, :not_started} = Modbuzz.stop_tcp_client(name)
    end
  end

  describe "start_tcp_server/4" do
    test "return ok, return error tuple" do
      name = :tcp_server

      assert :ok = Modbuzz.start_tcp_server(name, @test_address, @test_port_1, :no_source)

      assert {:error, :already_started} =
               Modbuzz.start_tcp_server(name, @test_address, @test_port_1, :no_source)
    end

    test "multiple instance" do
      assert :ok = Modbuzz.start_tcp_server(:server_1, @test_address, @test_port_1, :no_source)
      assert :ok = Modbuzz.start_tcp_server(:server_2, @test_address, @test_port_2, :no_source)
    end
  end

  describe "stop_tcp_server/1" do
    test "return ok, return error tuple" do
      name = :tcp_server

      :ok = Modbuzz.start_tcp_server(name, @test_address, @test_port_1, :no_source)

      assert :ok = Modbuzz.stop_tcp_server(name)
      assert is_nil(GenServer.whereis(name))
      assert {:error, :not_started} = Modbuzz.stop_tcp_server(name)
    end
  end

  describe "start_rtu_client/4" do
    test "return ok, return error tuple" do
      name = :rtu_client

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      assert :ok = Modbuzz.start_rtu_client(name, "ttyTEST", [], Modbuzz.RTU.TransportMock)

      assert {:error, :already_started} =
               Modbuzz.start_rtu_client(name, "ttyTEST", [], Modbuzz.RTU.TransportMock)
    end

    test "multiple instance" do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, 2, fn [] -> {:ok, self()} end)
      |> expect(:open, 2, fn _transport_pid, _device_name, _opts -> :ok end)

      assert :ok =
               Modbuzz.start_rtu_client(:rtu_client_1, "ttyTEST_1", [], Modbuzz.RTU.TransportMock)

      assert :ok =
               Modbuzz.start_rtu_client(:rtu_client_2, "ttyTEST_2", [], Modbuzz.RTU.TransportMock)
    end
  end

  describe "stop_rtu_client/1" do
    test "return ok, return error tuple" do
      name = :rtu_client

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      :ok = Modbuzz.start_rtu_client(name, "ttyTEST", [], Modbuzz.RTU.TransportMock)

      assert :ok = Modbuzz.stop_rtu_client(name)
      assert is_nil(GenServer.whereis(name))
      assert {:error, :not_started} = Modbuzz.stop_rtu_client(name)
    end
  end

  describe "start_rtu_server/5" do
    test "return ok, return error tuple" do
      name = :rtu_server

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      assert :ok =
               Modbuzz.start_rtu_server(
                 name,
                 "ttyTEST",
                 [],
                 :no_source,
                 Modbuzz.RTU.TransportMock
               )

      assert {:error, :already_started} =
               Modbuzz.start_rtu_server(
                 name,
                 "ttyTEST",
                 [],
                 :no_source,
                 Modbuzz.RTU.TransportMock
               )
    end

    test "multiple instance" do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, 2, fn [] -> {:ok, self()} end)
      |> expect(:open, 2, fn _transport_pid, _device_name, _opts -> :ok end)

      assert :ok =
               Modbuzz.start_rtu_server(
                 :rtu_server_1,
                 "ttyTEST_1",
                 [],
                 :no_source,
                 Modbuzz.RTU.TransportMock
               )

      assert :ok =
               Modbuzz.start_rtu_server(
                 :rtu_server_2,
                 "ttyTEST_2",
                 [],
                 :no_source,
                 Modbuzz.RTU.TransportMock
               )
    end
  end

  describe "stop_rtu_server/1" do
    test "return ok, return error tuple" do
      name = :rtu_server

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      :ok = Modbuzz.start_rtu_server(name, "ttyTEST", [], :no_source, Modbuzz.RTU.TransportMock)

      assert :ok = Modbuzz.stop_rtu_server(name)
      assert is_nil(GenServer.whereis(name))
      assert {:error, :not_started} = Modbuzz.stop_rtu_server(name)
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

    test "return error tuple when stored response is an exception pdu" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      err_response = Modbuzz.PDU.to_error(request, :server_device_failure)

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, err_response)

      assert {:error, ^err_response} = Modbuzz.request(:data_server_1, 0, request)
    end

    test "return error tuple when callback returns an exception pdu" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      err_response = Modbuzz.PDU.to_error(request, :server_device_failure)

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, fn _request -> err_response end)

      assert {:error, ^err_response} = Modbuzz.request(:data_server_1, 0, request)
    end

    test "callback invalid response times out" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, fn _request -> nil end)

      # The callback worker is expected to crash on invalid return values; request/4 should still return timeout.
      capture_log(fn ->
        assert {:error, :timeout} = Modbuzz.request(:data_server_1, 0, request, 10)
      end)
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

  describe "request_async/3" do
    setup do
      :ok = Modbuzz.start_data_server(:data_server_1)
      :ok = Modbuzz.start_tcp_server(:server_1, @test_address, @test_port_1, :data_server_1)
      :ok = Modbuzz.start_tcp_client(:client_1, @test_address, @test_port_1)
    end

    test "returns immediately and receives async response from tcp client and data server" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, response)

      assert :ok = Modbuzz.request_async(:client_1, 0, request)
      assert_receive {:modbuzz, :client_1, 0, ^request, {:ok, ^response}}

      assert :ok = Modbuzz.request_async(:data_server_1, 0, request)
      assert_receive {:modbuzz, :data_server_1, 0, ^request, {:ok, ^response}}
    end

    test "receives timeout error from data server when request is not mapped" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}

      :ok = Modbuzz.create_unit(:data_server_1)

      assert :ok = Modbuzz.request_async(:data_server_1, 0, request, self(), 10)
      assert_receive {:modbuzz, :data_server_1, 0, ^request, {:error, :timeout}}
    end

    test "receives error tuple from data server when stored response is an exception pdu" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      err_response = Modbuzz.PDU.to_error(request, :server_device_failure)

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, err_response)

      assert :ok = Modbuzz.request_async(:data_server_1, 0, request)
      assert_receive {:modbuzz, :data_server_1, 0, ^request, {:error, ^err_response}}
    end

    test "receives error tuple from data server when callback returns an exception pdu" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      err_response = Modbuzz.PDU.to_error(request, :server_device_failure)

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, fn _request -> err_response end)

      assert :ok = Modbuzz.request_async(:data_server_1, 0, request)
      assert_receive {:modbuzz, :data_server_1, 0, ^request, {:error, ^err_response}}
    end

    test "invalid callback response times out and data server stays alive" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      valid_response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      :ok = Modbuzz.create_unit(:data_server_1)
      :ok = Modbuzz.upsert(:data_server_1, request, fn _request -> nil end)

      # The timeout is the assertion; the worker crash log is expected and would only make test output noisy.
      capture_log(fn ->
        assert :ok = Modbuzz.request_async(:data_server_1, 0, request, self(), 10)
        assert_receive {:modbuzz, :data_server_1, 0, ^request, {:error, :timeout}}
      end)

      assert Process.alive?(GenServer.whereis(:data_server_1))

      :ok = Modbuzz.upsert(:data_server_1, request, valid_response)

      assert :ok = Modbuzz.request_async(:data_server_1, 0, request)
      assert_receive {:modbuzz, :data_server_1, 0, ^request, {:ok, ^valid_response}}
    end

    test "receives async response from rtu client" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}
      unit_id = 1

      response_binary =
        response
        |> Modbuzz.RTU.ADU.new(unit_id)
        |> Modbuzz.RTU.ADU.encode()

      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(:rtu_client, {:circuits_uart, "ttyTEST", response_binary})
        :ok
      end)

      _pid =
        start_supervised!(
          {Modbuzz.RTU.Client,
           [name: :rtu_client, transport: Modbuzz.RTU.TransportMock, device_name: "ttyTEST"]},
          restart: :temporary
        )

      assert :ok = Modbuzz.request_async(:rtu_client, unit_id, request, self(), 100)
      assert_receive {:modbuzz, :rtu_client, ^unit_id, ^request, {:ok, ^response}}
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
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      _pid =
        start_supervised!(
          {Modbuzz.RTU.Client,
           [name: :rtu_client, transport: Modbuzz.RTU.TransportMock, device_name: "ttyTEST"]},
          restart: :temporary
        )

      :ok = Modbuzz.start_tcp_server(:tcp_server, @test_address, @test_port_1, :rtu_client)
      :ok = Modbuzz.start_tcp_client(:tcp_client, @test_address, @test_port_1)

      task = Task.async(fn -> Modbuzz.request(:tcp_client, 1, request) end)

      pid = GenServer.whereis(:rtu_client)

      response_binary =
        response
        |> Modbuzz.RTU.ADU.new(1)
        |> Modbuzz.RTU.ADU.encode()

      Process.send_after(pid, {:circuits_uart, "ttyTEST", response_binary}, 10)

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
        |> Modbuzz.RTU.ADU.new(1)
        |> Modbuzz.RTU.ADU.encode()

      Process.send_after(pid, {:circuits_uart, "ttyTEST", request_binary}, 10)

      # NOTE: Confirm that the RTU server has written the response
      receive do
        binary ->
          {:ok, adu} = Modbuzz.RTU.ADU.decode_response(binary)
          assert adu.pdu == response
      end
    end
  end
end
