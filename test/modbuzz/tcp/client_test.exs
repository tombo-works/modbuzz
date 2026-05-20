defmodule Modbuzz.TCP.ClientTest do
  use ExUnit.Case

  @moduletag capture_log: true

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "start_link/1" do
    test "return :ok tuple" do
      assert {:ok, _pid} = Modbuzz.TCP.Client.start_link(transport: Modbuzz.TCP.TransportMock)
    end
  end

  describe "call" do
    setup do
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 16}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0x02, coil_status: List.duplicate(false, 16)}
      res_err = %Modbuzz.PDU.ReadCoils.Err{exception_code: 0x01}

      %{req: req, res: res, res_err: res_err}
    end

    test "return :ok tuple", %{req: req, res: res} do
      dummy_socket = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ ->
        send(Modbuzz.TCP.Client, {:tcp, dummy_socket, to_binary(res)})
        :ok
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(req) == {:ok, res}
    end

    test "return :error tuple by connect error", %{req: req} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:error, :timeout} end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(req) == {:error, :tcp_connect_error}
    end

    test "return :error tuple by send error", %{req: req} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_socket = make_ref()} end)
      |> expect(:send, fn _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(req) == {:error, :tcp_send_error}
    end

    test "return :error tuple by timeout", %{req: req} do
      dummy_socket = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ -> :ok end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(Modbuzz.TCP.Client, 0, req, 10) == {:error, :timeout}
    end

    test "return :error tuple by modbus error", %{req: req, res_err: res_err} do
      dummy_socket = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ ->
        send(Modbuzz.TCP.Client, {:tcp, dummy_socket, to_binary(res_err)})
        :ok
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(req) == {:error, res_err}
    end
  end

  describe "cast" do
    setup do
      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 16}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0x02, coil_status: List.duplicate(false, 16)}

      %{parent: self(), ref: make_ref(), req: req, res: res}
    end

    test "return :ok", %{req: req, res: res} do
      dummy_socket = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ ->
        send(Modbuzz.TCP.Client, {:tcp, dummy_socket, to_binary(res)})
        :ok
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(req) == :ok
      assert_receive({:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:ok, ^res}})
    end

    test "return :ok, receive {:error, :tcp_connect_error}", %{req: req} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:error, :timeout} end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(req) == :ok

      assert_receive(
        {:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:error, :tcp_connect_error}}
      )
    end

    test "return :ok, receive {:error, :tcp_send_error}", %{req: req} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(req) == :ok

      assert_receive(
        {:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:error, :tcp_send_error}}
      )
    end

    test "return :ok, receive {:error, :timeout}", %{
      req: req
    } do
      dummy_socket = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ -> :ok end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(Modbuzz.TCP.Client, 0, req, self(), 10) == :ok
      assert_receive({:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:error, :timeout}})
    end
  end

  describe "tcp messages" do
    setup do
      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock},
          restart: :temporary
        )

      req = %Modbuzz.PDU.ReadCoils.Req{starting_address: 0, quantity_of_coils: 16}
      res = %Modbuzz.PDU.ReadCoils.Res{byte_count: 0x02, coil_status: List.duplicate(false, 16)}

      %{pid: pid, req: req, res: res}
    end

    test "message {:tcp, socket, binary}", %{
      pid: pid,
      req: req,
      res: res
    } do
      dummy_socket = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ -> :ok end)

      :ok = Modbuzz.TCP.Client.cast(req)

      send(pid, {:tcp, dummy_socket, to_binary(res)})
      assert_receive({:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:ok, ^res}})
    end

    test "message {:tcp, socket, binary}, recv two messages at once", %{
      pid: pid,
      req: req,
      res: res
    } do
      dummy_socket = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:send, fn _, _ -> :ok end)

      :ok = Modbuzz.TCP.Client.cast(req)
      :ok = Modbuzz.TCP.Client.cast(req)

      send(pid, {:tcp, dummy_socket, to_binary(res, 1) <> to_binary(res, 2)})
      assert_receive({:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:ok, ^res}})
      assert_receive({:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:ok, ^res}})
    end

    test "message {:tcp, socket, binary}, {:tcp_closed, socket}", %{
      pid: pid,
      req: req,
      res: res
    } do
      dummy_socket = make_ref()
      me = self()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:close, fn _ ->
        send(me, :closed)
        :ok
      end)

      :ok = Modbuzz.TCP.Client.cast(req)

      send(pid, {:tcp, dummy_socket, to_binary(res)})
      assert_receive({:modbuzz, Modbuzz.TCP.Client, _unit_id = 0, ^req, {:ok, ^res}})

      send(pid, {:tcp_closed, dummy_socket})
      assert_receive(:closed)
    end

    test "message {:tcp_closed, socket}", %{
      pid: pid,
      req: req
    } do
      dummy_socket = make_ref()
      me = self()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:close, fn _ ->
        send(me, :closed)
        :ok
      end)

      :ok = Modbuzz.TCP.Client.cast(req)

      send(pid, {:tcp_closed, dummy_socket})
      assert_receive(:closed)
    end

    test "message {:tcp_error, socket, reason}", %{
      pid: pid,
      req: req
    } do
      dummy_socket = make_ref()
      me = self()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_socket} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:close, fn _ ->
        send(me, :closed)
        :ok
      end)

      :ok = Modbuzz.TCP.Client.cast(req)

      send(pid, {:tcp_error, dummy_socket, :reason})
      assert_receive(:closed)
    end
  end

  defp to_binary(pdu, transaction_id \\ 0x0001) do
    pdu
    |> Modbuzz.TCP.ADU.new(transaction_id, _unit_id = 0)
    |> Modbuzz.TCP.ADU.encode()
  end
end
