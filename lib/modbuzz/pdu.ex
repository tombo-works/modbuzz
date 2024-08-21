defprotocol Modbuzz.PDU do
  @moduledoc """
  MODBUS Protocol Data Unit.

  Each PDU is documented, for example, in `Modbuzz.PDU.ReadCoils`.
  """

  @doc "Encodes the request into a PDU binary"
  @spec encode(request :: t()) :: binary()
  def encode(request)

  @doc "Decodes the PDU binary into tuple"
  @spec decode(request :: t(), binary()) :: {:ok, response :: term()} | {:error, reason :: term()}
  def decode(request, binary)
end
