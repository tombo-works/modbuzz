defmodule Modbuzz.PDU do
  @moduledoc false

  defdelegate encode_request!(struct), to: Modbuzz.PDU.Protocol, as: :encode
  defdelegate encode_response!(struct), to: Modbuzz.PDU.Protocol, as: :encode

  def encode_request(struct), do: {:ok, Modbuzz.PDU.Protocol.encode(struct)}
  def encode_response(struct), do: {:ok, Modbuzz.PDU.Protocol.encode(struct)}

  for {modbus_function_code, modbus_function} <- [
        {0x01, ReadCoils},
        {0x02, ReadDiscreteInputs},
        {0x03, ReadHoldingRegisters},
        {0x04, ReadInputRegisters},
        {0x05, WriteSingleCoil},
        {0x06, WriteSingleRegister},
        {0x0F, WriteMultipleCoils},
        {0x10, WriteMultipleRegisters}
      ] do
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
end
