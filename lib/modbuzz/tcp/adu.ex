defmodule Modbuzz.TCP.ADU do
  @moduledoc false

  alias Modbuzz.PDU

  @type t :: %__MODULE__{
          transaction_id: 0x0000..0xFFFF,
          protocol_id: 0x0000..0xFFFF,
          # pdu max is 253 bytes, so length max is 254 (1 byte for unit_id + pdu)
          length: 0x0000..0x00FE,
          unit_id: 0x00..0xFF,
          pdu: Modbuzz.PDU.Protocol.t() | {:unknown_function_code, non_neg_integer()} | nil
        }
  defstruct transaction_id: 0x0000, protocol_id: 0x0000, length: 0x0000, unit_id: 0x00, pdu: nil

  @unit_id_length 1
  @function_code_length 1
  @mbap_length 7

  defguardp is_modbus_protocol(protocol_id) when protocol_id == 0x0000

  defguardp is_valid_length(length)
            when @unit_id_length + @function_code_length <= length and length <= 0x00FE

  def max_frame_length, do: @mbap_length + PDU.max_frame_length()

  def increment_transaction_id(transaction_id) do
    if transaction_id >= 0xFFFF, do: 0, else: transaction_id + 1
  end

  def new(pdu, transaction_id, unit_id) when is_struct(pdu) do
    %__MODULE__{
      transaction_id: transaction_id,
      unit_id: unit_id,
      pdu: pdu
    }
  end

  def encode(%__MODULE__{} = adu) do
    unit_id_length = 1
    pdu_binary = PDU.encode(adu.pdu)
    pdu_binary_length = byte_size(pdu_binary)

    <<adu.transaction_id::16, adu.protocol_id::16, unit_id_length + pdu_binary_length::16,
      adu.unit_id, pdu_binary::binary-size(pdu_binary_length)>>
  end

  @spec decode_request(binary :: binary(), list()) ::
          {:ok, {[{:ok, t()}], binary()}}
          | {:error, {:adu_invalid_protocol, non_neg_integer()}}
          | {:error, {:adu_invalid_length, non_neg_integer()}}
          | {:error, {:pdu_unknown_function_code, non_neg_integer()}}
  def decode_request(
        <<_transaction_id::16, protocol_id::16, length::16, _rest::binary>> = binary,
        acc
      )
      when is_modbus_protocol(protocol_id) and is_valid_length(length) do
    # trnsaction_id: 2 bytes
    # protcol_id:        2 bytes
    # length:                2 bytes
    adu_frame_size = 2 + 2 + 2 + length

    if byte_size(binary) < adu_frame_size do
      {:ok, {Enum.reverse(acc), binary}}
    else
      <<adu_binary::binary-size(adu_frame_size), rest::binary>> = binary

      case decode_request(adu_binary) do
        {:error, {:pdu_unknown_function_code, _}} = error ->
          error

        adu_tuple ->
          decode_request(rest, [adu_tuple | acc])
      end
    end
  end

  def decode_request(
        <<_transaction_id::16, protocol_id::16, _length::16, _rest::binary>>,
        _acc
      )
      when not is_modbus_protocol(protocol_id) do
    {:error, {:adu_invalid_protocol, protocol_id}}
  end

  def decode_request(
        <<_transaction_id::16, _protocol_id::16, length::16, _rest::binary>>,
        _acc
      )
      when not is_valid_length(length) do
    {:error, {:adu_invalid_length, length}}
  end

  def decode_request(binary, acc) do
    {:ok, {Enum.reverse(acc), binary}}
  end

  @spec decode_response(binary :: binary(), list()) ::
          {:ok, {[{:ok, t()} | {:error, t()}], binary()}}
          | {:error, {:adu_invalid_protocol, non_neg_integer()}}
          | {:error, {:adu_invalid_length, non_neg_integer()}}
          | {:error, {:pdu_unknown_function_code, non_neg_integer()}}
  def decode_response(
        <<_transaction_id::16, protocol_id::16, length::16, _rest::binary>> = binary,
        acc
      )
      when is_modbus_protocol(protocol_id) and is_valid_length(length) do
    # trnsaction_id: 2 bytes
    # protcol_id:        2 bytes
    # length:                2 bytes
    adu_frame_size = 2 + 2 + 2 + length

    if byte_size(binary) < adu_frame_size do
      {:ok, {Enum.reverse(acc), binary}}
    else
      <<adu_binary::binary-size(adu_frame_size), rest::binary>> = binary

      case decode_response(adu_binary) do
        {:error, {:pdu_unknown_function_code, _}} = error ->
          error

        adu_tuple ->
          decode_response(rest, [adu_tuple | acc])
      end
    end
  end

  def decode_response(
        <<_transaction_id::16, protocol_id::16, _length::16, _rest::binary>>,
        _acc
      )
      when not is_modbus_protocol(protocol_id) do
    {:error, {:adu_invalid_protocol, protocol_id}}
  end

  def decode_response(
        <<_transaction_id::16, _protocol_id::16, length::16, _rest::binary>>,
        _acc
      )
      when not is_valid_length(length) do
    {:error, {:adu_invalid_length, length}}
  end

  def decode_response(binary, acc) do
    {:ok, {Enum.reverse(acc), binary}}
  end

  @spec decode_request(binary :: binary()) ::
          {:ok, t()}
          | {:error, {:pdu_unknown_function_code, non_neg_integer()}}
  defp decode_request(
         <<transaction_id::16, protocol_id::16, length::16, unit_id,
           pdu_binary::binary-size(length - 1)>>
       )
       when is_valid_length(length) do
    adu = %__MODULE__{
      transaction_id: transaction_id,
      protocol_id: protocol_id,
      length: length,
      unit_id: unit_id
    }

    case PDU.decode_request(pdu_binary) do
      {:ok, pdu} when is_struct(pdu) -> {:ok, %{adu | pdu: pdu}}
      {:error, {:pdu_unknown_function_code, _}} = error -> error
    end
  end

  @spec decode_response(binary :: binary()) ::
          {:ok, t()}
          | {:error, t()}
          | {:error, {:pdu_unknown_function_code, non_neg_integer()}}
  defp decode_response(
         <<transaction_id::16, protocol_id::16, length::16, unit_id,
           pdu_binary::binary-size(length - 1)>>
       )
       when is_valid_length(length) do
    adu = %__MODULE__{
      transaction_id: transaction_id,
      protocol_id: protocol_id,
      length: length,
      unit_id: unit_id
    }

    case PDU.decode_response(pdu_binary) do
      {:ok, pdu} when is_struct(pdu) -> {:ok, %{adu | pdu: pdu}}
      {:error, pdu} when is_struct(pdu) -> {:error, %{adu | pdu: pdu}}
      {:error, {:pdu_unknown_function_code, _}} = error -> error
    end
  end
end
