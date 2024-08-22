defmodule Modbuzz.PDUTest do
  use ExUnit.Case

  doctest Modbuzz.PDU.Modbuzz.PDU.ReadCoils
  doctest Modbuzz.PDU.Modbuzz.PDU.ReadDiscreteInputs
  doctest Modbuzz.PDU.Modbuzz.PDU.ReadHoldingRegisters
  doctest Modbuzz.PDU.Modbuzz.PDU.ReadInputRegisters
  doctest Modbuzz.PDU.Modbuzz.PDU.WriteSingleCoil
  doctest Modbuzz.PDU.Modbuzz.PDU.WriteSingleRegister
end
