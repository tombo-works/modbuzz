defmodule Modbuzz.TCP.ADU do
  defstruct transaction_id: 0x0000, protocol_id: 0x0000, length: 0x0000, unit_id: 0x00, pdu: nil

  def encode(%__MODULE__{} = adu) do
    <<adu.transaction_id::16, adu.protocol_id::16, adu.length::16, adu.unit_id,
      adu.pdu::binary-size(adu.length - 1)>>
  end

  def decode(
        <<transaction_id::16, protocol_id::16, length::16, unit_id, pdu::binary-size(length - 1)>>
      ) do
    %__MODULE__{
      transaction_id: transaction_id,
      protocol_id: protocol_id,
      length: length,
      unit_id: unit_id,
      pdu: pdu
    }
  end
end
