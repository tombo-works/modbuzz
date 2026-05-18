defmodule Modbuzz.RTU.ADU do
  @moduledoc false

  alias Modbuzz.PDU

  # unit_id: 1, functions_code: 1, crc: 2, so minimum frame length is 4
  @min_frame_length 4

  @crc_defn :cerlc.init(:crc16_modbus)
  @crc_length 2

  @type t :: %__MODULE__{unit_id: 0x00..0xF7, pdu: struct() | nil, crc_valid?: boolean()}
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

  def decode_request(binary) when is_binary(binary) and byte_size(binary) < @min_frame_length do
    {:error, :binary_is_short}
  end

  def decode_request(<<unit_id, binary::binary>>) do
    with {:ok, pdu_length} <- Modbuzz.PDU.request_length(binary),
         true <- byte_size(binary) >= pdu_length + @crc_length || {:error, :binary_is_short},
         <<pdu_binary::binary-size(pdu_length), crc::binary-size(@crc_length)>> <- binary,
         true <- crc(<<unit_id, pdu_binary::binary>>) == crc || {:error, :crc_error},
         {:ok, pdu} <- PDU.decode_request(pdu_binary) do
      {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
    else
      {:error, :binary_is_short} ->
        {:error, :binary_is_short}

      {:error, :unknown} ->
        {:error, :unknown}

      long_binary when is_binary(long_binary) ->
        {:error, :binary_is_long}

      {:error, :crc_error} ->
        {:error, %__MODULE__{unit_id: unit_id, crc_valid?: false}}
    end
  end

  def decode_response(binary) when is_binary(binary) and byte_size(binary) < @min_frame_length do
    {:error, :binary_is_short}
  end

  def decode_response(<<unit_id, binary::binary>>) do
    with {:ok, pdu_length} <- Modbuzz.PDU.response_length(binary),
         true <- byte_size(binary) >= pdu_length + @crc_length || {:error, :binary_is_short},
         <<pdu_binary::binary-size(pdu_length), crc::binary-size(@crc_length)>> <- binary,
         true <- crc(<<unit_id, pdu_binary::binary>>) == crc || {:error, :crc_error},
         {:ok, pdu} <- PDU.decode_response(pdu_binary) do
      {:ok, %__MODULE__{unit_id: unit_id, pdu: pdu}}
    else
      {:error, :unknown} ->
        {:error, :unknown}

      {:error, :binary_is_short} ->
        {:error, :binary_is_short}

      long_binary when is_binary(long_binary) ->
        {:error, :binary_is_long}

      {:error, :crc_error} ->
        {:error, %__MODULE__{unit_id: unit_id, crc_valid?: false}}

      {:error, pdu} when is_struct(pdu) ->
        {:error, %__MODULE__{unit_id: unit_id, pdu: pdu}}
    end
  end

  defp crc(binary) do
    <<:cerlc.calc_crc(binary, @crc_defn)::little-size(16)>>
  end
end
