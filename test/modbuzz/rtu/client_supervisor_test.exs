defmodule Modbuzz.RTU.ClientSupervisorTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "start_link/1" do
    test "return :ok tuple" do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)
      |> expect(:controlling_process, fn _transport_pid, _pid -> :ok end)

      assert {:ok, _pid} =
               Modbuzz.RTU.ClientSupervisor.start_link(
                 name: :client,
                 transport: Modbuzz.RTU.TransportMock,
                 device_name: "ttyTEST"
               )
    end
  end

  describe "call/4" do
    setup do
      Modbuzz.RTU.TransportMock
      |> expect(:start_link, fn [] -> {:ok, self()} end)
      |> expect(:open, fn _transport_pid, _device_name, _opts -> :ok end)
      |> expect(:controlling_process, fn _transport_pid, _pid -> :ok end)

      name = :client

      _pid =
        start_link_supervised!(
          {Modbuzz.RTU.ClientSupervisor,
           name: name, transport: Modbuzz.RTU.TransportMock, device_name: "ttyTEST"},
          restart: :temporary
        )

      %{name: name}
    end

    test "return :ok tuple", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      task = Task.async(fn -> Modbuzz.RTU.Client.call(context.name, 1, request, 100) end)

      pid = Modbuzz.RTU.Client.Receiver.pid(context.name)
      Process.send_after(pid, {:circuits_uart, "ttyTest", <<0x01, 0x01, 0x00, 0x21, 0x90>>}, 10)

      assert Task.await(task) == {:ok, %Modbuzz.PDU.ReadCoils.Res{byte_count: 0, coil_status: []}}
    end

    test "return :error tuple, no response", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      assert Modbuzz.RTU.Client.call(context.name, 1, request, 100) ==
               {:error, %Modbuzz.PDU.ReadCoils.Err{exception_code: 4}}
    end

    test "return :error tuple, crc error", context do
      Modbuzz.RTU.TransportMock
      |> expect(:write, fn _pid, _binary, _timeout -> :ok end)

      request = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 0}

      task = Task.async(fn -> Modbuzz.RTU.Client.call(context.name, 1, request, 100) end)

      pid = Modbuzz.RTU.Client.Receiver.pid(context.name)
      Process.send_after(pid, {:circuits_uart, "ttyTest", <<0x01, 0x01, 0x00, 0x00, 0x00>>}, 10)

      assert Task.await(task) == {:error, :crc_error}
    end
  end
end
