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

    test "return :ok tuple", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(
          context.name,
          {:circuits_uart, context.device_name, <<0x01, 0x01, 0x00, 0x21, 0x90>>}
        )

        :ok
      end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      task = Task.async(fn -> GenServer.call(context.name, {:call, 1, request, 100}) end)

      assert Task.await(task) == {:ok, %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}}
    end

    test "return :error tuple, no response", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      assert GenServer.call(context.name, {:call, 1, request, 100}) ==
               {:error, %Modbuzz.PDU.ReadCoils.Err{exception_code: 4}}
    end

    test "return :error tuple, crc error", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(
          context.name,
          {:circuits_uart, context.device_name, <<0x01, 0x01, 0x00, 0x00, 0x00>>}
        )

        :ok
      end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      task = Task.async(fn -> GenServer.call(context.name, {:call, 1, request, 100}) end)

      assert Task.await(task) == {:error, :crc_error}
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

    test "return :ok tuple", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(
          context.name,
          {:circuits_uart, context.device_name, <<0x01, 0x01, 0x00, 0x21, 0x90>>}
        )

        :ok
      end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      GenServer.cast(context.name, {:cast, 1, request, self(), 100})

      assert_receive {:modbuzz, :client,
                      {:ok, %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}}}
    end

    test "return :error tuple, no response", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      GenServer.cast(context.name, {:cast, 1, request, self(), 100})

      assert_receive {:modbuzz, :client, {:error, %Modbuzz.PDU.ReadCoils.Err{exception_code: 4}}},
                     500
    end

    test "return :error tuple, crc error", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout ->
        send(
          context.name,
          {:circuits_uart, context.device_name, <<0x01, 0x01, 0x00, 0x00, 0x00>>}
        )

        :ok
      end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      GenServer.cast(context.name, {:cast, 1, request, self(), 100})

      assert_receive {:modbuzz, :client, {:error, :crc_error}}
    end

    test "return :error tuple, server device busy", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      me = self()

      [pid1, pid2] =
        for pid_res <- [:pid1_res, :pid2_res] do
          spawn(fn ->
            receive do
              {:modbuzz, :client, res_tuple} -> send(me, {pid_res, res_tuple})
            end
          end)
        end

      # First cast occupies unit_id: 1 with pid1
      GenServer.cast(context.name, {:cast, 1, request, pid1, 100})
      # Second cast for the same unit_id should report busy to pid2
      GenServer.cast(context.name, {:cast, 1, request, pid2, 100})

      # Busy must be reported only to the second requester (pid2), not the first requester (pid1).
      assert_receive {:pid2_res, {:error, %Modbuzz.PDU.ReadCoils.Err{exception_code: 6}}}
      refute_receive {:pid1_res, {:error, %Modbuzz.PDU.ReadCoils.Err{exception_code: 6}}}
    end
  end
end
