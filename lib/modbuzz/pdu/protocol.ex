defprotocol Modbuzz.PDU.Protocol do
  @moduledoc """
  Protocol for `MODBUS PDU`

  We defined Req/Res/Err structs for each `MODBUS function`.
  Each struct implements this protocol.
  """

  @doc false
  def encode(struct)
  @doc false
  def decode(struct, binary)
  @doc false
  def expected_binary_size(struct, binary)
end
