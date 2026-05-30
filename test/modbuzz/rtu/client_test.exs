defmodule Modbuzz.RTU.ClientTest do
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
               Modbuzz.RTU.Client.start_link(
                 name: :client,
                 transport: Modbuzz.RTU.TransportMock,
                 device_name: "ttyTEST"
               )
    end
  end

  describe "handle_call/3" do
    setup do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      name = :client
      device_name = "ttyTEST"

      _pid =
        start_link_supervised!(
          {Modbuzz.RTU.Client,
           name: name, transport: Modbuzz.RTU.TransportMock, device_name: device_name},
          restart: :temporary
        )

      %{name: name, device_name: device_name}
    end

    test "return :ok tuple", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 0x01
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, res)})
        :ok
      end)

      task = Task.async(fn -> GenServer.call(name, {:call, unit_id, req, 100}) end)
      assert Task.await(task) == {:ok, res}
    end

    test "return :error tuple, timeout", %{
      name: name
    } do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      unit_id = 0x01
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      assert GenServer.call(name, {:call, unit_id, req, 10}) == {:error, :timeout}
    end

    test "return :error tuple, crc error", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 0x01
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        <<binary_wo_crc::binary-size(3), _crc::binary-size(2)>> = to_binary(unit_id, res)
        crc_error_binary = binary_wo_crc <> <<0x00, 0x00>>
        send(name, {:circuits_uart, device_name, crc_error_binary})
        :ok
      end)

      task = Task.async(fn -> GenServer.call(name, {:call, unit_id, req, 10}) end)
      assert Task.await(task) == {:error, :timeout}
    end

    test "return :error tuple, modbus error response", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      err_res = Modbuzz.PDU.to_error(req, :server_device_failure)

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, err_res)})
        :ok
      end)

      task = Task.async(fn -> GenServer.call(name, {:call, unit_id, req, 100}) end)
      assert Task.await(task) == {:error, err_res}
    end

    test "clears buffer and recovers on unknown function code binary", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 0x01
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        unknown_function_code = <<0x00>>
        fake_crc = <<0x00, 0x00>>
        unknown_function_binary = <<_unit_id = 0x02>> <> unknown_function_code <> fake_crc
        send(name, {:circuits_uart, device_name, unknown_function_binary})
        :ok
      end)
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, res)})
        :ok
      end)

      task2 = Task.async(fn -> GenServer.call(name, {:call, _unit_id = 0x02, req, 10}) end)
      task1 = Task.async(fn -> GenServer.call(name, {:call, unit_id, req, 100}) end)

      assert Task.await(task1) == {:ok, res}
      assert Task.await(task2) == {:error, :timeout}
    end

    test "clears buffer and recovers on binary_is_long binary", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        extra_byte = <<0xFF>>
        long_binary = to_binary(_unit_id = 0x02, res) <> extra_byte
        send(name, {:circuits_uart, device_name, long_binary})
        :ok
      end)
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, res)})
        :ok
      end)

      task2 = Task.async(fn -> GenServer.call(name, {:call, _unit_id = 0x02, req, 10}) end)
      task1 = Task.async(fn -> GenServer.call(name, {:call, unit_id, req, 10}) end)

      assert Task.await(task1) == {:ok, res}
      assert Task.await(task2) == {:error, :timeout}
    end
  end

  describe "handle_cast/2" do
    setup do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      name = :client
      device_name = "ttyTEST"

      _pid =
        start_link_supervised!(
          {Modbuzz.RTU.Client,
           name: name, transport: Modbuzz.RTU.TransportMock, device_name: device_name},
          restart: :temporary
        )

      %{name: name, device_name: device_name}
    end

    test "return :ok tuple", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, res)})
        :ok
      end)

      GenServer.cast(name, {:cast, unit_id, req, self(), 100})
      assert_receive {:modbuzz, :client, ^unit_id, ^req, {:ok, ^res}}
    end

    test "return :error tuple, timeout", %{
      name: name
    } do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      GenServer.cast(name, {:cast, unit_id, req, self(), 10})
      assert_receive {:modbuzz, :client, ^unit_id, ^req, {:error, :timeout}}
    end

    test "return :error tuple, crc error", %{name: name, device_name: device_name} do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        <<binary_wo_crc::binary-size(3), _crc::binary-size(2)>> = to_binary(unit_id, res)
        crc_error_binary = binary_wo_crc <> <<0x00, 0x00>>
        send(name, {:circuits_uart, device_name, crc_error_binary})
        :ok
      end)

      GenServer.cast(name, {:cast, unit_id, req, self(), 10})
      assert_receive {:modbuzz, :client, ^unit_id, ^req, {:error, :timeout}}
    end

    test "return :error tuple, server device busy", %{
      name: name
    } do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      me = self()

      [pid1, pid2] =
        for pid_res <- [:pid1_res, :pid2_res] do
          spawn(fn ->
            receive do
              {:modbuzz, :client, ^unit_id, ^req, res_tuple} -> send(me, {pid_res, res_tuple})
            end
          end)
        end

      # First cast occupies unit_id: 1 with pid1
      GenServer.cast(name, {:cast, unit_id, req, pid1, 100})
      # Second cast for the same unit_id should report busy to pid2
      GenServer.cast(name, {:cast, unit_id, req, pid2, 100})

      # Busy must be reported only to the second requester (pid2), not the first requester (pid1).
      assert_receive {:pid2_res, {:error, :another_request_in_progress}}
      refute_receive {:pid1_res, {:error, :another_request_in_progress}}
    end

    test "return :error tuple, modbus error response", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      err_res = Modbuzz.PDU.to_error(req, :server_device_failure)

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, err_res)})
        :ok
      end)

      GenServer.cast(name, {:cast, unit_id, req, self(), 100})

      assert_receive {:modbuzz, :client, ^unit_id, ^req, {:error, ^err_res}}
    end

    test "clears buffer and recovers on unknown function code binary", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 0x01
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        unknown_function_code = <<0x00>>
        fake_crc = <<0x00, 0x00>>
        unknown_function_binary = <<_unit_id = 0x02>> <> unknown_function_code <> fake_crc
        send(name, {:circuits_uart, device_name, unknown_function_binary})
        :ok
      end)
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, res)})
        :ok
      end)

      GenServer.cast(name, {:cast, _unit_id = 0x02, req, self(), 10})
      GenServer.cast(name, {:cast, unit_id, req, self(), 10})

      assert_receive {:modbuzz, :client, ^unit_id, ^req, {:ok, ^res}}
      assert_receive {:modbuzz, :client, _unit_id = 0x02, ^req, {:error, :timeout}}
    end

    test "clears buffer and recovers on binary_is_long binary", %{
      name: name,
      device_name: device_name
    } do
      unit_id = 0x01
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        extra_byte = <<0xFF>>
        long_binary = to_binary(_unit_id = 0x02, res) <> extra_byte
        send(name, {:circuits_uart, device_name, long_binary})
        :ok
      end)
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(name, {:circuits_uart, device_name, to_binary(unit_id, res)})
        :ok
      end)

      GenServer.cast(name, {:cast, _unit_id = 0x02, req, self(), 10})
      GenServer.cast(name, {:cast, unit_id, req, self(), 10})

      assert_receive {:modbuzz, :client, ^unit_id, ^req, {:ok, ^res}}
      assert_receive {:modbuzz, :client, _unit_id = 0x02, ^req, {:error, :timeout}}
    end
  end

  describe "terminate/2" do
    setup do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)

      name = :client
      device_name = "ttyTEST"

      # Use start_supervised! (not start_link_supervised!) so stopping the client with :shutdown
      # does not propagate an exit signal to this test process.
      _pid =
        start_supervised!(
          {Modbuzz.RTU.Client,
           name: name, transport: Modbuzz.RTU.TransportMock, device_name: device_name},
          restart: :temporary
        )

      %{name: name}
    end

    test "pending cast requester gets client_terminated", %{
      name: name
    } do
      unit_id = 1
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      :ok = GenServer.cast(name, {:cast, unit_id, req, self(), 100})
      :ok = GenServer.stop(name, :shutdown)
      assert_receive {:modbuzz, :client, ^unit_id, ^req, {:error, :client_terminated}}
    end
  end

  defp to_binary(unit_id, res) do
    res
    |> Modbuzz.RTU.ADU.new(unit_id)
    |> Modbuzz.RTU.ADU.encode()
  end
end
