defmodule Modbuzz.RTU.ADU do
  @moduledoc false

  @crc_defn :cerlc.init(:crc16_modbus)

  @type t :: %__MODULE__{unit_id: 0x00..0xF7, pdu: binary(), crc_valid?: boolean()}
  defstruct unit_id: 0x00, pdu: nil, crc_valid?: true

  def new(pdu, unit_id) when is_binary(pdu) do
    %__MODULE__{
      unit_id: unit_id,
      pdu: pdu
    }
  end

  def encode(%__MODULE__{} = adu) do
    binary = <<adu.unit_id, adu.pdu::binary-size(byte_size(adu.pdu))>>
    binary <> crc(binary)
  end

  def decode_response(<<unit_id, binary::binary>>) do
    with {:ok, pdu_length} <- Modbuzz.PDU.response_length(binary),
         <<pdu::binary-size(pdu_length), crc::binary-size(2)>> <- binary do
      if(crc(<<unit_id, pdu::binary>>) == crc) do
        {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
      else
        {:error, %__MODULE__{unit_id: unit_id, pdu: pdu, crc_valid?: false}}
      end
    else
      _ -> {:error, :binary_is_short}
    end
  end

  def decode(binary) when is_binary(binary) do
    length = byte_size(binary)
    <<binary::binary-size(length - 2), crc::binary-size(2)>> = binary
    <<unit_id, pdu::binary>> = binary

    %__MODULE__{
      unit_id: unit_id,
      pdu: pdu,
      crc_valid?: crc(binary) == crc
    }
  end

  def decode!(binary) when is_binary(binary) do
    length = byte_size(binary)
    <<binary::binary-size(length - 2), crc::binary-size(2)>> = binary
    <<unit_id, pdu::binary>> = binary

    if crc(binary) != crc, do: raise(Modbuzz.RTU.Exceptions.CRCError)

    %__MODULE__{
      unit_id: unit_id,
      pdu: pdu,
      crc_valid?: crc(binary) == crc
    }
  end

  defp crc(binary) do
    <<:cerlc.calc_crc(binary, @crc_defn)::little-size(16)>>
  end
end
