defmodule Modbuzz.PDU do
  @moduledoc false

  defdelegate encode(struct), to: Modbuzz.PDU.Protocol, as: :encode

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

    def request_length(<<unquote(modbus_function_code), _rest::binary>> = binary) do
      {:ok, Modbuzz.PDU.Protocol.expected_binary_size(%unquote(req_module){}, binary)}
    end

    def response_length(<<unquote(modbus_function_code), _rest::binary>> = binary) do
      {:ok, Modbuzz.PDU.Protocol.expected_binary_size(%unquote(res_module){}, binary)}
    end

    def response_length(<<unquote(modbus_error_code), _rest::binary>> = binary) do
      {:ok, Modbuzz.PDU.Protocol.expected_binary_size(%unquote(err_module){}, binary)}
    end
  end

  # NOTE: We need this fallback, because the binary is not always guaranteed to be correct.
  def request_length(<<_, _rest::binary>>), do: {:error, :unknown}
  def response_length(<<_, _rest::binary>>), do: {:error, :unknown}

  def to_error(%req{}, exception_code) do
    exception_code =
      case exception_code do
        :server_device_failure -> 0x04
        :server_device_busy -> 0x06
      end

    Module.split(req)
    |> List.replace_at(-1, "Err")
    |> Module.concat()
    |> struct(%{exception_code: exception_code})
  end
end
