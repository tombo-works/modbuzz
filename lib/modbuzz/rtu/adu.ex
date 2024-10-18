defmodule Modbuzz.RTU.ADU do
  @moduledoc false

  @crc_defn :cerlc.init(:crc16_modbus)

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

  def decode_response(binary) when is_binary(binary) do
    with <<_unit_id, function_code, _rest::binary>> <- binary,
         {:ok, length} <- expected_binary_length(function_code, binary),
         true <- byte_size(binary) == length do
      <<binary::binary-size(length - 2), crc::binary-size(2)>> = binary

      if(crc(binary) == crc) do
        <<unit_id, pdu::binary>> = binary
        {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
      else
        {:error, :crc_error}
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

  defp expected_binary_length(function_code, binary) when function_code in [0x03] do
    <<_unit_id, _function_code, byte_count, _rest::binary>> = binary
    {:ok, 1 + 1 + 1 + byte_count + 2}
  rescue
    error -> {:error, error}
  end
end
