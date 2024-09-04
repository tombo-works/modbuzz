defmodule Modbuzz.PDU2 do
  @moduledoc false

  defdelegate encode_request(struct), to: Modbuzz.PDU2.Protocol, as: :encode
  defdelegate encode_response(struct), to: Modbuzz.PDU2.Protocol, as: :encode

  for {modbus_function, modbus_function_code} <- [
        {ReadCoils, 0x01},
        {ReadDiscreteInputs, 0x02},
        {ReadHoldingRegisters, 0x03},
        {ReadInputRegisters, 0x04},
        {WriteSingleCoil, 0x05},
        {WriteSingleRegister, 0x06},
        {WriteMultipleCoils, 0x0F},
        {WriteMultipleRegisters, 0x10}
      ] do
    req_module = Module.concat([Modbuzz.PDU2, modbus_function, Req])
    res_module = Module.concat([Modbuzz.PDU2, modbus_function, Res])
    err_module = Module.concat([Modbuzz.PDU2, modbus_function, Err])
    modbus_error_code = modbus_function_code + 0x80

    def decode_request(binary = <<unquote(modbus_function_code), _rest::binary>>) do
      Modbuzz.PDU2.Protocol.decode(%unquote(req_module){}, binary)
    end

    def decode_response(binary = <<unquote(modbus_function_code), _rest::binary>>) do
      Modbuzz.PDU2.Protocol.decode(%unquote(res_module){}, binary)
    end

    def decode_response(binary = <<unquote(modbus_error_code), _rest::binary>>) do
      Modbuzz.PDU2.Protocol.decode(%unquote(err_module){}, binary)
    end
  end
end
