defprotocol Modbuzz.PDU do
  @moduledoc """
  MODBUS Protocol Data Unit

  This module defines PDU functions
  """

  @doc "Encodes the request into a PDU binary"
  def encode(request)
  @doc "Decodes the PDU binary into ?"
  def decode(request, binary)
end
