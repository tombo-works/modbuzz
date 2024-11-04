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
      |> expect(:controlling_process, fn _transport_pid, _pid -> :ok end)

      assert {:ok, _pid} =
               Modbuzz.RTU.Client.start_link(
                 name: :client,
                 transport: Modbuzz.RTU.TransportMock,
                 device_name: "ttyTEST"
               )
    end
  end
end
