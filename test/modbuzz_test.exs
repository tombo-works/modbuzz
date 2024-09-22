defmodule ModbuzzTest do
  use ExUnit.Case

  @test_address {127, 0, 0, 1}
  @test_port_1 502 * 100
  @test_port_2 503 * 100

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

    test "return error tuple" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}

      assert {:error, %Modbuzz.PDU.ReadDiscreteInputs.Err{}} =
               Modbuzz.request(:client_1, 0, request)
    end

    test "return ok tuple" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      :ok = Modbuzz.upsert(:data_server_1, request, response)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} = Modbuzz.request(:client_1, 0, request)
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

      :ok = Modbuzz.upsert(:data_server_1, request_1, response_1)
      :ok = Modbuzz.upsert(:data_server_2, request_2, response_2)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} =
               Modbuzz.request(:client_1, 0, request_1)

      assert {:ok, %Modbuzz.PDU.ReadDiscreteInputs.Res{}} =
               Modbuzz.request(:client_2, 0, request_2)
    end
  end

  describe "upsert/4, delete/3, dump/2" do
    setup do
      :ok = Modbuzz.start_data_server(:data_server)
    end

    test "upsert/4" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      assert :ok = Modbuzz.upsert(:data_server, request, response)
    end

    test "delete/3" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      :ok = Modbuzz.upsert(:data_server, request, response)
      assert :ok = Modbuzz.delete(:data_server, request)
    end

    test "dump/2" do
      request = %Modbuzz.PDU.ReadDiscreteInputs.Req{starting_address: 0, quantity_of_inputs: 0}
      response = %Modbuzz.PDU.ReadDiscreteInputs.Res{byte_count: 0, input_status: []}

      assert Modbuzz.dump(:data_server) == %{}
      :ok = Modbuzz.upsert(:data_server, request, response)
      assert Modbuzz.dump(:data_server) == %{request => response}
    end
  end
end
