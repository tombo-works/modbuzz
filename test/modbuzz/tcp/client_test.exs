defmodule Modbuzz.TCP.ClientTest do
  use ExUnit.Case

  import Mox

  setup :verify_on_exit!
  setup :set_mox_global

  describe "start_link/1" do
    setup do
      %{parent: self(), ref: make_ref()}
    end

    test "connect/4 succeeded", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ ->
        send(parent, {ref, :connect})
        {:ok, _dummy_port = make_ref()}
      end)

      assert {:ok, pid} = Modbuzz.TCP.Client.start_link(transport: Modbuzz.TCP.TransportMock)
      assert_receive({^ref, :connect})
      GenServer.stop(pid)
    end

    test "connect/4 succeeded after failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:error, :timeout} end)
      |> expect(:connect, fn _, _, _, _ ->
        send(parent, {ref, :connect})
        {:ok, _dummy_port = make_ref()}
      end)

      assert {:ok, pid} = Modbuzz.TCP.Client.start_link(transport: Modbuzz.TCP.TransportMock)
      assert_receive({^ref, :connect})
      GenServer.stop(pid)
    end
  end

  describe "call" do
    setup do
      %{parent: self(), ref: make_ref()}
    end

    test "raise when active: true" do
      Process.flag(:trap_exit, true)

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)

      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
          restart: :temporary
        )

      catch_exit(
        Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
          starting_address: 0,
          quantity_of_coils: 16
        })
      )

      assert_receive({:EXIT, ^pid, {%RuntimeError{message: _message}, _}})
    end

    test "return :ok tuple", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ ->
        send(parent, {ref, :recv})
        {:ok, read_coils_recv_adu(1)}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == {:ok, List.duplicate(false, 16)}

      assert_receive({^ref, :recv})
    end

    test "return :ok tuple, 1st send failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ ->
        send(parent, {ref, :recv})
        {:ok, read_coils_recv_adu(2)}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == {:ok, List.duplicate(false, 16)}

      assert_receive({^ref, :recv})
    end

    test "return :ok tuple, 1st recv failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ ->
        send(parent, {ref, :recv})
        {:ok, read_coils_recv_adu(2)}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == {:ok, List.duplicate(false, 16)}

      assert_receive({^ref, :recv})
    end

    test "return :error tuple, modbus error", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ ->
        send(parent, {ref, :recv})
        {:ok, read_coils_recv_adu(1, _error = true)}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == {:error, exception_code: 1}

      assert_receive({^ref, :recv})
    end

    test "return :error tuple, 2nd connnect failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:error, :timeout} end)
      # confirm {:continue, :connect}
      |> expect(:connect, fn _, _, _, _ ->
        send(parent, {ref, :connect})
        {:ok, _dummy_port = make_ref()}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == {:error, :timeout}

      assert_receive({^ref, :connect})
    end

    test "return :error tuple, 2nd send failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ ->
        send(parent, {ref, :send})
        {:error, :closed}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == {:error, :closed}

      assert_receive({^ref, :send})
    end

    test "return :error tuple, 2nd recv failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:recv, fn _, _, _ ->
        send(parent, {ref, :recv})
        {:error, :closed}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.call(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == {:error, :closed}

      assert_receive({^ref, :recv})
    end
  end

  describe "cast" do
    setup do
      %{parent: self(), ref: make_ref()}
    end

    test "raise when active: false" do
      Process.flag(:trap_exit, true)

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)

      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: false},
          restart: :temporary
        )

      Modbuzz.TCP.Client.cast(%Modbuzz.PDU.ReadCoils{
        starting_address: 0,
        quantity_of_coils: 16
      })

      assert_receive({:EXIT, ^pid, {%RuntimeError{message: _message}, _}})
    end

    test "return :ok", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ ->
        send(parent, {ref, :send})
        :ok
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == :ok

      assert_receive({^ref, :send})
    end

    test "return :ok, 1st send failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ ->
        send(parent, {ref, :send})
        :ok
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == :ok

      assert_receive({^ref, :send})
    end

    test "return :error tuple, 2nd connect failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:error, :timeout} end)
      # confirm {:continue, :connect}
      |> expect(:connect, fn _, _, _, _ ->
        send(parent, {ref, :connect})
        {:ok, _dummy_port = make_ref()}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == :ok

      assert_receive({^ref, :connect})
    end

    test "return :error tuple, 2nd send failed", %{parent: parent, ref: ref} do
      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ -> {:error, :closed} end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:ok, _dummy_port = make_ref()} end)
      |> expect(:send, fn _, _ ->
        send(parent, {ref, :send})
        {:error, :closed}
      end)

      start_link_supervised!(
        {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
        restart: :temporary
      )

      assert Modbuzz.TCP.Client.cast(%Modbuzz.PDU.ReadCoils{
               starting_address: 0,
               quantity_of_coils: 16
             }) == :ok

      assert_receive({^ref, :send})
    end

    test "message {:tcp, socket, binary}" do
      dummy_port = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_port} end)
      |> expect(:send, fn _, _ -> :ok end)

      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
          restart: :temporary
        )

      request = %Modbuzz.PDU.ReadCoils{starting_address: 0, quantity_of_coils: 16}
      assert Modbuzz.TCP.Client.cast(request) == :ok

      send(pid, {:tcp, dummy_port, read_coils_recv_adu(1)})

      assert_receive({:modbuzz, 0, ^request, {:ok, _}})
    end

    test "message {:tcp, socket, binary}, recv two messages at once" do
      dummy_port = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_port} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:send, fn _, _ -> :ok end)

      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
          restart: :temporary
        )

      request_1 = %Modbuzz.PDU.ReadCoils{starting_address: 0, quantity_of_coils: 16}
      assert Modbuzz.TCP.Client.cast(request_1) == :ok
      request_2 = %Modbuzz.PDU.WriteSingleCoil{output_address: 16, output_value: true}
      assert Modbuzz.TCP.Client.cast(request_2) == :ok

      send(pid, {:tcp, dummy_port, read_coils_recv_adu(1) <> write_single_coil_recv_adu(2)})

      assert_receive({:modbuzz, 0, ^request_1, {:ok, _}})
      assert_receive({:modbuzz, 0, ^request_2, {:ok, _}})
    end

    test "message {:tcp, socket, binary}, {:tcp_closed, socket}", %{parent: parent, ref: ref} do
      dummy_port = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_port} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:close, fn _ -> :ok end)
      # confirm {:continue, :connect}
      |> expect(:connect, fn _, _, _, _ ->
        send(parent, {ref, :connect})
        {:ok, dummy_port}
      end)

      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
          restart: :temporary
        )

      request = %Modbuzz.PDU.ReadCoils{starting_address: 0, quantity_of_coils: 16}
      assert Modbuzz.TCP.Client.cast(request) == :ok

      send(pid, {:tcp, dummy_port, read_coils_recv_adu(1)})

      assert_receive({:modbuzz, 0, ^request, {:ok, _}})

      send(pid, {:tcp_closed, dummy_port})
      assert_receive({^ref, :connect})
    end

    test "message {:tcp_closed, socket}", %{parent: parent, ref: ref} do
      dummy_port = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_port} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:close, fn _ -> :ok end)
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_port} end)
      |> expect(:send, fn _, _ ->
        send(parent, {ref, :send})
        :ok
      end)

      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
          restart: :temporary
        )

      request = %Modbuzz.PDU.ReadCoils{starting_address: 0, quantity_of_coils: 16}
      assert Modbuzz.TCP.Client.cast(request) == :ok

      send(pid, {:tcp_closed, dummy_port})

      assert_receive({^ref, :send})
    end

    test "message {:tcp_error, socket, reason}", %{parent: parent, ref: ref} do
      dummy_port = make_ref()

      Modbuzz.TCP.TransportMock
      |> expect(:connect, fn _, _, _, _ -> {:ok, dummy_port} end)
      |> expect(:send, fn _, _ -> :ok end)
      |> expect(:close, fn _ -> :ok end)
      # confirm {:continue, :connect}
      |> expect(:connect, fn _, _, _, _ ->
        send(parent, {ref, :connect})
        {:ok, dummy_port}
      end)

      pid =
        start_link_supervised!(
          {Modbuzz.TCP.Client, transport: Modbuzz.TCP.TransportMock, active: true},
          restart: :temporary
        )

      request = %Modbuzz.PDU.ReadCoils{starting_address: 0, quantity_of_coils: 16}
      assert Modbuzz.TCP.Client.cast(request) == :ok

      send(pid, {:tcp_error, dummy_port, :reason})

      assert_receive({^ref, :connect})
    end
  end

  defp read_coils_recv_adu(transaction_id, error \\ false) do
    pdu = if error, do: <<0x01 + 0x80::8, 1::8>>, else: <<0x01::8, 2::8, 0::8, 0::8>>
    length = byte_size(pdu) + 1
    unit_id = 0
    Modbuzz.TCP.Client.mbap_header(transaction_id, length, unit_id) <> pdu
  end

  defp write_single_coil_recv_adu(transaction_id, error \\ false) do
    pdu = if error, do: <<0x05 + 0x80::8, 1::8>>, else: <<0x05::8, 16::16, 0xFF00::16>>
    length = byte_size(pdu) + 1
    unit_id = 0
    Modbuzz.TCP.Client.mbap_header(transaction_id, length, unit_id) <> pdu
  end
end
