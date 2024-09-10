defmodule Modbuzz.TCP.ServerTest do
  use ExUnit.Case

  @test_address {127, 0, 0, 1}
  @test_port_1 502 * 100
  @test_port_2 503 * 100

  describe "operate data strore" do
    setup do
      start_supervised!(
        {Modbuzz.TCP.Server.Supervisor,
         [
           address: @test_address,
           port: @test_port_1
         ]}
      )

      start_supervised!(
        {Modbuzz.TCP.Client,
         [
           address: @test_address,
           port: @test_port_1,
           active: false
         ]}
      )

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
      Modbuzz.TCP.Server.upsert(@test_address, @test_port_1, req, res)
      assert {:ok, ^res} = Modbuzz.TCP.Client.call(req)
    end

    test "upsert/5", %{req: req, res: res} do
      unit_id = 1
      Modbuzz.TCP.Server.upsert(@test_address, @test_port_1, unit_id, req, res)
      assert {:ok, ^res} = Modbuzz.TCP.Client.call(Modbuzz.TCP.Client, unit_id, req)
    end

    test "delete/3", %{req: req, res: res} do
      Modbuzz.TCP.Server.upsert(@test_address, @test_port_1, req, res)
      {:ok, ^res} = Modbuzz.TCP.Client.call(req)
      Modbuzz.TCP.Server.delete(@test_address, @test_port_1, req)
      assert {:error, %{exception_code: 2}} = Modbuzz.TCP.Client.call(req)
    end

    test "delete/4", %{req: req, res: res} do
      unit_id = 1
      Modbuzz.TCP.Server.upsert(@test_address, @test_port_1, unit_id, req, res)
      {:ok, ^res} = Modbuzz.TCP.Client.call(Modbuzz.TCP.Client, unit_id, req)
      Modbuzz.TCP.Server.delete(@test_address, @test_port_1, unit_id, req)

      assert {:error, %{exception_code: 2}} =
               Modbuzz.TCP.Client.call(Modbuzz.TCP.Client, unit_id, req)
    end
  end

  test "multiple server instances" do
    for {id, port} <- [{:server_1, @test_port_1}, {:server_2, @test_port_2}] do
      start_supervised!(%{
        Modbuzz.TCP.Server.Supervisor.child_spec(
          address: @test_address,
          port: port
        )
        | id: id
      })
    end

    for {id, port} <- [{:client_1, @test_port_1}, {:client_2, @test_port_2}] do
      start_supervised!(%{
        Modbuzz.TCP.Client.child_spec(
          name: id,
          address: @test_address,
          port: port,
          active: false
        )
        | id: id
      })
    end

    req_1 = %Modbuzz.PDU.ReadCoils.Req{
      starting_address: 0,
      quantity_of_coils: 1
    }

    res_1 = %Modbuzz.PDU.ReadCoils.Res{
      byte_count: 1,
      coil_status: [true | List.duplicate(false, 7)]
    }

    req_2 = %Modbuzz.PDU.ReadDiscreteInputs.Req{
      starting_address: 0,
      quantity_of_inputs: 8
    }

    res_2 = %Modbuzz.PDU.ReadDiscreteInputs.Res{
      byte_count: 1,
      input_status: List.duplicate(true, 8)
    }

    Modbuzz.TCP.Server.upsert(@test_address, @test_port_1, req_1, res_1)
    Modbuzz.TCP.Server.upsert(@test_address, @test_port_2, req_2, res_2)

    assert {:ok, ^res_1} = Modbuzz.TCP.Client.call(:client_1, req_1)
    assert {:ok, ^res_2} = Modbuzz.TCP.Client.call(:client_2, req_2)
  end
end
