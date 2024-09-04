defmodule Modbuzz.PDU2Test do
  use ExUnit.Case

  for type <- [Req, Res, Err],
      modbus_function <- [
        ReadCoils,
        ReadDiscreteInputs,
        ReadHoldingRegisters,
        WriteSingleCoil
      ] do
    doctest Module.concat([Modbuzz.PDU2.Protocol.Modbuzz.PDU2, modbus_function, type])
  end
end
