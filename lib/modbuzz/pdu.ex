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
  end

  def to_error(%req{}, exception_code \\ @illegal_data_address) do
    Module.split(req)
    |> List.replace_at(-1, "Err")
    |> Module.concat()
    |> struct(%{exception_code: exception_code})
  end
end
