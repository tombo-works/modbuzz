defmodule Modbuzz.PDU.WriteSingleCoil do
  @moduledoc false
  defstruct [:output_address, :output_value]

  defimpl Modbuzz.PDU do
    @function_code 0x05
    @error_code @function_code + 0x80

    def encode(struct) do
      output_value = if struct.output_value, do: 0xFF00, else: 0x0000
      <<@function_code::8, struct.output_address::16, output_value::16>>
    end

    def decode(_struct, <<@function_code::8, _output_address::16, _output_value::16>>) do
      {:ok, nil}
    end

    def decode(_struct, <<@error_code::8, exception_code::8>>) do
      {:error, exception_code: exception_code}
    end
  end
end
