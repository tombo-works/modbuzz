defprotocol Modbuzz.PDU2.Protocol do
  def encode(struct)
  def decode(struct, binary)
end
