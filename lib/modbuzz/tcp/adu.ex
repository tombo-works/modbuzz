defmodule Modbuzz.TCP.ADU do
  @moduledoc false

  alias Modbuzz.PDU

  @type t :: %__MODULE__{
          transaction_id: 0x0000..0xFFFF,
          protocol_id: 0x0000..0xFFFF,
          # pdu max is 253 bytes, so length max is 254 (1 byte for unit_id + pdu)
          length: 0x0000..0x00FE,
          unit_id: 0x00..0xFF,
          pdu: Modbuzz.PDU.Protocol.t() | nil
        }
  defstruct transaction_id: 0x0000, protocol_id: 0x0000, length: 0x0000, unit_id: 0x00, pdu: nil

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

  def decode_request(
        <<transaction_id::16, protocol_id::16, length::16, unit_id,
          pdu_binary::binary-size(length - 1), rest::binary>>,
        acc
      ) do
    adu = %__MODULE__{
      transaction_id: transaction_id,
      protocol_id: protocol_id,
      length: length,
      unit_id: unit_id
    }

    adu_tuple =
      case PDU.decode_request(pdu_binary) do
        {:ok, pdu} -> {:ok, %{adu | pdu: pdu}}
      end

    acc = [adu_tuple | acc]

    if rest == <<>>, do: Enum.reverse(acc), else: decode_request(rest, acc)
  end

  def decode_response(
        <<_transaction_id::16, _protocol_id::16, length::16, _rest::binary>> = binary,
        acc
      ) do
    adu_frame_size = 2 + 2 + 2 + length

    if byte_size(binary) >= adu_frame_size do
      <<adu_binary::binary-size(adu_frame_size), rest::binary>> = binary

      adu = decode_response(adu_binary)

      decode_response(rest, [adu | acc])
    else
      {Enum.reverse(acc), binary}
    end
  end

  def decode_response(binary, acc) do
    {Enum.reverse(acc), binary}
  end

  defp decode_response(
         <<transaction_id::16, protocol_id::16, length::16, unit_id,
           pdu_binary::binary-size(length - 1)>>
       ) do
    adu = %__MODULE__{
      transaction_id: transaction_id,
      protocol_id: protocol_id,
      length: length,
      unit_id: unit_id
    }

    case PDU.decode_response(pdu_binary) do
      {:ok, pdu} -> {:ok, %{adu | pdu: pdu}}
      {:error, pdu} -> {:error, %{adu | pdu: pdu}}
    end
  end
end
