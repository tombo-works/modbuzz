defmodule Modbuzz.PDU.WriteMultipleCoils do
  @moduledoc """
  #{Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)}

  ## Request type

    - `t()`

  ## Response types

    - `{:ok, nil}`
    - `{:error, exception: 1..4}`

  """

  @type t :: %__MODULE__{
          starting_address: 0x0000..0xFFFF,
          quantity_of_outputs: 0x0001..0x07B0,
          outputs_value: [boolean()]
        }
  defstruct [:starting_address, :quantity_of_outputs, :outputs_value]

  defimpl Modbuzz.PDU do
    @function_code 0x0F
    @error_code @function_code + 0x80

    @doc """
        iex> request = %Modbuzz.PDU.WriteMultipleCoils{
        ...>   starting_address: 20 - 1,
        ...>   quantity_of_outputs: 10,
        ...>   outputs_value: [true, false, true, true, false, false, true, true, true, false]
        ...> }
        iex> Modbuzz.PDU.encode(request)
        <<#{@function_code}, 0x0013::16, 0x000A::16, 0x02, 0xCD, 0x01>>
    """
    def encode(struct) do
      outputs_value = struct.outputs_value |> Modbuzz.PDU.Helper.to_binary()

      <<@function_code::8, struct.starting_address::16, struct.quantity_of_outputs::16,
        byte_size(outputs_value)>> <> outputs_value
    end

    @doc """
        iex> request = %Modbuzz.PDU.WriteMultipleCoils{
        ...>   starting_address: 173 - 1,
        ...>   quantity_of_outputs: 10,
        ...>   outputs_value: true
        ...> }
        iex> Modbuzz.PDU.decode(request, <<#{@function_code}, 0x0013::16, 0x000A::16>>)
        {:ok, nil}
        iex> Modbuzz.PDU.decode(request, <<#{@error_code}, 0x01>>)
        {:error, [exception_code: 1]}
    """
    def decode(_struct, <<@function_code::8, _starting_address::16, _quantity_of_outputs::16>>) do
      {:ok, nil}
    end

    def decode(_struct, <<@error_code::8, exception_code::8>>) do
      {:error, exception_code: exception_code}
    end
  end
end
