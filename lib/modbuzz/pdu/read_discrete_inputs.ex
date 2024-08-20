defmodule Modbuzz.PDU.ReadDiscreteInputs do
  @moduledoc false
  defstruct [:starting_address, :quantity_of_inputs]

  defimpl Modbuzz.PDU do
    @function_code 0x02
    @error_code @function_code + 0x80

    def encode(struct) do
      <<@function_code::8, struct.starting_address::16, struct.quantity_of_inputs::16>>
    end

    def decode(
          struct,
          <<@function_code::8, byte_count::8, input_status::binary-size(byte_count)>>
        ) do
      input_status
      |> Modbuzz.PDU.Helper.bin_to_boolean_bits()
      |> Enum.take(struct.quantity_of_inputs)
      |> then(&{:ok, &1})
    end

    def decode(_struct, <<@error_code::8, exception_code::8>>) do
      {:error, exception_code: exception_code}
    end
  end
end
