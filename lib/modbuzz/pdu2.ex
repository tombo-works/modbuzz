defmodule Modbuzz.PDU2 do
  defdelegate encode_request(struct), to: Modbuzz.PDU2.Protocol, as: :encode
  defdelegate encode_response(struct), to: Modbuzz.PDU2.Protocol, as: :encode

  def decode_request(binary = <<0x01, _rest::binary>>) do
    Modbuzz.PDU2.Protocol.decode(%Modbuzz.PDU2.ReadCoils.Req{}, binary)
  end

  def decode_response(binary = <<0x01, _rest::binary>>) do
    Modbuzz.PDU2.Protocol.decode(%Modbuzz.PDU2.ReadCoils.Res{}, binary)
  end

  def decode_response(binary = <<0x81, _rest::binary>>) do
    Modbuzz.PDU2.Protocol.decode(%Modbuzz.PDU2.ReadCoils.Err{}, binary)
  end
end
