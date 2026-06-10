defmodule Modbuzz.RTU.ADU do
  @moduledoc false

  alias Modbuzz.PDU

  @unit_id_length 1
  @function_code_length 1

  @crc_defn :cerlc.init(:crc16_modbus)
  @crc_length 2

  @type t :: %__MODULE__{
          unit_id: 0x00..0xF7,
          pdu: Modbuzz.PDU.Protocol.t() | nil,
          crc_valid?: boolean()
        }
  defstruct unit_id: 0x00, pdu: nil, crc_valid?: true

  @min_frame_length @unit_id_length + @function_code_length + @crc_length
  def max_frame_length, do: PDU.max_frame_length() + @crc_length

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

  @spec decode_request(binary()) ::
          {:ok, t()}
          | {:error, :adu_binary_is_short}
          | {:error, {:pdu_unknown_function_code, non_neg_integer()}}
          | {:error, :pdu_decode_error}
          | {:error, :adu_binary_is_long}
          | {:error, :adu_crc_error}
  def decode_request(binary) when is_binary(binary) and byte_size(binary) < @min_frame_length do
    {:error, :adu_binary_is_short}
  end

  def decode_request(<<unit_id, binary::binary>>) do
    with {:ok, pdu_length} <- Modbuzz.PDU.request_length(binary),
         true <- byte_size(binary) >= pdu_length + @crc_length || {:error, :adu_binary_is_short},
         <<pdu_binary::binary-size(^pdu_length), crc::binary-size(@crc_length)>> <- binary,
         true <- crc(<<unit_id, pdu_binary::binary>>) == crc || {:error, :adu_crc_error} do
      try do
        case PDU.decode_request(pdu_binary) do
          {:ok, pdu} -> {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
          {:error, {:pdu_unknown_function_code, _}} = error -> error
        end
      rescue
        FunctionClauseError -> {:error, :pdu_decode_error}
      end
    else
      {:error, {:pdu_unknown_function_code, _}} = error -> error
      {:error, :adu_binary_is_short} = error -> error
      long_binary when is_binary(long_binary) -> {:error, :adu_binary_is_long}
      {:error, :adu_crc_error} = error -> error
    end
  end

  @spec decode_response(binary()) ::
          {:ok, t()}
          | {:error, :adu_binary_is_short}
          | {:error, {:pdu_unknown_function_code, non_neg_integer()}}
          | {:error, :pdu_decode_error}
          | {:error, :adu_binary_is_long}
          | {:error, :adu_crc_error}
          | {:error, t()}
  def decode_response(binary) when is_binary(binary) and byte_size(binary) < @min_frame_length do
    {:error, :adu_binary_is_short}
  end

  def decode_response(<<unit_id, binary::binary>>) do
    with {:ok, pdu_length} <- Modbuzz.PDU.response_length(binary),
         true <- byte_size(binary) >= pdu_length + @crc_length || {:error, :adu_binary_is_short},
         <<pdu_binary::binary-size(^pdu_length), crc::binary-size(@crc_length)>> <- binary,
         true <- crc(<<unit_id, pdu_binary::binary>>) == crc || {:error, :adu_crc_error} do
      try do
        case PDU.decode_response(pdu_binary) do
          {:ok, pdu} -> {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
          {:error, pdu} when is_struct(pdu) -> {:error, %__MODULE__{unit_id: unit_id, pdu: pdu}}
          {:error, {:pdu_unknown_function_code, _}} = error -> error
        end
      rescue
        FunctionClauseError -> {:error, :pdu_decode_error}
      end
    else
      {:error, {:pdu_unknown_function_code, _}} = error -> error
      {:error, :adu_binary_is_short} = error -> error
      long_binary when is_binary(long_binary) -> {:error, :adu_binary_is_long}
      {:error, :adu_crc_error} = error -> error
    end
  end

  defp crc(binary) do
    <<:cerlc.calc_crc(binary, @crc_defn)::little-size(16)>>
  end
end
