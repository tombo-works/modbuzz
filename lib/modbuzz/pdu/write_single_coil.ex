defmodule Modbuzz.PDU.WriteSingleCoil do
  defstruct [:output_address, :output_value]
end

defimpl Modbuzz.PDU, for: Modbuzz.PDU.WriteSingleCoil do
  @write_single_coil 0x05

  def encode(struct) do
    output_value = if struct.output_value, do: 0xFF00, else: 0x0000
    <<@write_single_coil::8, struct.output_address::16, output_value::16>>
  end

  def decode(_struct, <<@write_single_coil::8, _output_address::16, _output_value::16>>) do
    :ok
  end
end
