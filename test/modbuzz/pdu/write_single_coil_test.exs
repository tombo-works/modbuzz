defmodule Modbuzz.PDU.WriteSingleCoilTest do
  use ExUnit.Case

  setup do
    request = %Modbuzz.PDU.WriteSingleCoil{output_address: 16, output_value: true}
    %{request: request}
  end

  test "encode/1", %{request: request} do
    assert Modbuzz.PDU.encode(request) == <<0x05::8, 16::16, 0xFF00::16>>
    assert Modbuzz.PDU.encode(%{request | output_value: false}) == <<0x05::8, 16::16, 0x0000::16>>
  end

  test "decode/2", %{request: request} do
    assert Modbuzz.PDU.decode(request, <<0x05::8, 16::16, 1::16>>) == :ok
    assert Modbuzz.PDU.decode(request, <<0x05 + 0x80::8, 1::8>>) == {:error, exception_code: 1}
  end
end
