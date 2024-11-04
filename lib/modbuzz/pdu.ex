defmodule Modbuzz.PDU do
  @moduledoc false

  @illegal_data_address 0x02

  defdelegate encode_request!(struct), to: Modbuzz.PDU.Protocol, as: :encode
  defdelegate encode_response!(struct), to: Modbuzz.PDU.Protocol, as: :encode

  def encode_request(struct), do: {:ok, Modbuzz.PDU.Protocol.encode(struct)}
  def encode_response(struct), do: {:ok, Modbuzz.PDU.Protocol.encode(struct)}

  for {modbus_function_code, modbus_function} <- Modbuzz.MixProject.pdu_seed() do
    req_module = Module.concat([Modbuzz.PDU, modbus_function, Req])
    res_module = Module.concat([Modbuzz.PDU, modbus_function, Res])
    err_module = Module.concat([Modbuzz.PDU, modbus_function, Err])
    modbus_error_code = modbus_function_code + 0x80

    def decode_request(<<unquote(modbus_function_code), _rest::binary>> = binary) do
      {:ok, Modbuzz.PDU.Protocol.decode(%unquote(req_module){}, binary)}
    end

    def decode_response(<<unquote(modbus_function_code), _rest::binary>> = binary) do
      {:ok, Modbuzz.PDU.Protocol.decode(%unquote(res_module){}, binary)}
    end

    def decode_response(<<unquote(modbus_error_code), _rest::binary>> = binary) do
      {:error, Modbuzz.PDU.Protocol.decode(%unquote(err_module){}, binary)}
    end

    # NOTE: Folloing functions are for Modbuzz.RTU.ADU
    case modbus_function_code do
      mfc when mfc in [0x01, 0x02, 0x03, 0x04] ->
        def response_length(<<unquote(mfc), byte_count, _rest::binary>>) do
          # {:ok, function_code + byte count itself + byte_count}
          {:ok, 1 + 1 + byte_count}
        end

      mfc when mfc in [0x05, 0x06, 0x0F, 0x10] ->
        def response_length(<<unquote(mfc), _rest::binary>>) do
          # {:ok, function_code + address + value}
          {:ok, 1 + 2 + 2}
        end

      mfc when mfc in [0x08] ->
        def response_length(<<unquote(mfc), _rest::binary>>) do
          # {:ok, function_code + sub-function + data}
          {:ok, 1 + 2 + 2}
        end
    end
  end

  # NOTE: We need this fallback, because the binary is not always guaranteed to be correct.
  def response_length(<<_, _rest::binary>>), do: {:error, :unknown}

  def to_error(%req{}, exception_code \\ @illegal_data_address) do
    Module.split(req)
    |> List.replace_at(-1, "Err")
    |> Module.concat()
    |> struct(%{exception_code: exception_code})
  end
end
