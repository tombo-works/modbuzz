defmodule Modbuzz.TCP.ServerTest do
  use ExUnit.Case

  @test_address {127, 0, 0, 1}
  @test_port 502 * 100

  setup do
    start_supervised!(
      {Modbuzz.TCP.Server.Supervisor,
       modbuzz_tcp_server_args: [
         address: @test_address,
         port: @test_port,
         active: false
       ]}
    )

    start_supervised!(
      {Modbuzz.TCP.Client,
       [
         address: @test_address,
         port: @test_port,
         active: false
       ]}
    )

    :ok
  end

  describe "operate data strore" do
    setup do
      req = %Modbuzz.PDU.ReadCoils.Req{
        starting_address: 0,
        quantity_of_coils: 1
      }

      res = %Modbuzz.PDU.ReadCoils.Res{
        byte_count: 1,
        coil_status: [true | List.duplicate(false, 7)]
      }

      %{req: req, res: res}
    end

    test "upsert/4", %{req: req, res: res} do
      Modbuzz.TCP.Server.upsert(@test_address, @test_port, req, res)
      assert {:ok, ^res} = Modbuzz.TCP.Client.call(req)
    end

    test "upsert/5", %{req: req, res: res} do
      unit_id = 1
      Modbuzz.TCP.Server.upsert(@test_address, @test_port, unit_id, req, res)
      assert {:ok, ^res} = Modbuzz.TCP.Client.call(Modbuzz.TCP.Client, unit_id, req)
    end

    test "delete/3", %{req: req, res: res} do
      Modbuzz.TCP.Server.upsert(@test_address, @test_port, req, res)
      {:ok, ^res} = Modbuzz.TCP.Client.call(req)
      Modbuzz.TCP.Server.delete(@test_address, @test_port, req)
      assert {:error, %{exception_code: 2}} = Modbuzz.TCP.Client.call(req)
    end

    test "delete/4", %{req: req, res: res} do
      unit_id = 1
      Modbuzz.TCP.Server.upsert(@test_address, @test_port, unit_id, req, res)
      {:ok, ^res} = Modbuzz.TCP.Client.call(Modbuzz.TCP.Client, unit_id, req)
      Modbuzz.TCP.Server.delete(@test_address, @test_port, unit_id, req)

      assert {:error, %{exception_code: 2}} =
               Modbuzz.TCP.Client.call(Modbuzz.TCP.Client, unit_id, req)
    end
  end
end
