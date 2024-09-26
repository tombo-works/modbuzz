defmodule Modbuzz.PDUTest do
  use ExUnit.Case

  for type <- [Req, Res, Err],
      {_modbus_function_code, modbus_function} <- Modbuzz.MixProject.pdu_seed() do
    doctest Module.concat([Modbuzz.PDU.Protocol.Modbuzz.PDU, modbus_function, type])
  end
end
