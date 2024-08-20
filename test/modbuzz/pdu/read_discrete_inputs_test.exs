defmodule Modbuzz.PDU.ReadDiscreteInputsTest do
  use ExUnit.Case

  setup do
    request = %Modbuzz.PDU.ReadDiscreteInputs{starting_address: 0, quantity_of_inputs: 16}
    %{request: request}
  end

  test "encode/1", %{request: request} do
    assert Modbuzz.PDU.encode(request) == <<0x02::8, 0::16, 16::16>>
  end

  test "decode/2", %{request: request} do
    assert Modbuzz.PDU.decode(request, <<0x02::8, 1::8, 1::8>>) ==
             {:ok, [true | List.duplicate(false, 7)]}

    assert Modbuzz.PDU.decode(request, <<0x02 + 0x80::8, 1::8>>) == {:error, exception_code: 1}
  end
end
