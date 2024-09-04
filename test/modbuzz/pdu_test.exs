defmodule Modbuzz.PDUTest do
  use ExUnit.Case

  for type <- [Req, Res, Err],
      modbus_function <- [
        ReadCoils,
        ReadDiscreteInputs,
        ReadHoldingRegisters,
        ReadInputRegisters,
        WriteSingleCoil,
        WriteSingleRegister,
        WriteMultipleCoils,
        WriteMultipleRegisters
      ] do
    doctest Module.concat([Modbuzz.PDU.Protocol.Modbuzz.PDU, modbus_function, type])
  end
end
