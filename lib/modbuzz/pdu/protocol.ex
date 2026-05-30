defprotocol Modbuzz.PDU.Protocol do
  @moduledoc """
  Protocol for `MODBUS PDU`

  We defined Req/Res/Err structs for each `MODBUS function`.
  Each struct implements this protocol.
  """

  @doc false
  @spec encode(t()) :: binary()
  def encode(struct)
  @doc false
  @spec decode(t(), binary()) :: t()
  def decode(struct, binary)
  @doc false
  @spec expected_binary_size(t(), binary()) :: non_neg_integer()
  def expected_binary_size(struct, binary)
end
