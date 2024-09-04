defprotocol Modbuzz.PDU.Protocol do
  @moduledoc false

  def encode(struct)
  def decode(struct, binary)
end
