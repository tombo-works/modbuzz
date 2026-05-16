defmodule Modbuzz.RTU.ADU do
  @moduledoc false

  alias Modbuzz.PDU

  @crc_defn :cerlc.init(:crc16_modbus)

  @type t :: %__MODULE__{unit_id: 0x00..0xF7, pdu: struct(), crc_valid?: boolean()}
  defstruct unit_id: 0x00, pdu: nil, crc_valid?: true

  def new(pdu, unit_id) when is_struct(pdu) do
    %__MODULE__{
      unit_id: unit_id,
      pdu: pdu
    }
  end

  def encode(%__MODULE__{} = adu) do
    pdu_binary = PDU.encode(adu.pdu)
    binary = <<adu.unit_id, pdu_binary::binary-size(byte_size(pdu_binary))>>
    binary <> crc(binary)
  end

  def decode_request(<<unit_id, binary::binary>>) do
    with {:ok, pdu_length} <- Modbuzz.PDU.request_length(binary),
         <<pdu_binary::binary-size(pdu_length), crc::binary-size(2)>> <- binary do
      if crc(<<unit_id, pdu_binary::binary>>) == crc do
        {:ok, pdu} = PDU.decode_request(pdu_binary)
        {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
      else
        {:ok, pdu} = PDU.decode_request(pdu_binary)
        {:error, %__MODULE__{unit_id: unit_id, pdu: pdu, crc_valid?: false}}
      end
    else
      _ -> {:error, :binary_is_short}
    end
  end

  def decode_response(<<unit_id, binary::binary>>) do
    with {:ok, pdu_length} <- Modbuzz.PDU.response_length(binary),
         <<pdu_binary::binary-size(pdu_length), crc::binary-size(2)>> <- binary do
      if crc(<<unit_id, pdu_binary::binary>>) == crc do
        {:ok, pdu} = PDU.decode_response(pdu_binary)
        {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
      else
        {:ok, pdu} = PDU.decode_response(pdu_binary)
        {:error, %__MODULE__{unit_id: unit_id, pdu: pdu, crc_valid?: false}}
      end
    else
      _ -> {:error, :binary_is_short}
    end
  end

  defp crc(binary) do
    <<:cerlc.calc_crc(binary, @crc_defn)::little-size(16)>>
  end
end
