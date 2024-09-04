defprotocol Modbuzz.PDU2.Protocol do
  @moduledoc false

  def encode(struct)
  def decode(struct, binary)
end
