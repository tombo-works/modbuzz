defmodule Modbuzz.PDU.WriteMultipleRegisters do
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
          quantity_of_registers: 0x0001..0x007B,
          registers_value: [0x0000..0xFFFF]
        }
  defstruct [:starting_address, :quantity_of_registers, :registers_value]

  defimpl Modbuzz.PDU do
    @function_code 0x10
    @error_code @function_code + 0x80

    @doc """
        iex> request = %Modbuzz.PDU.WriteMultipleRegisters{
        ...>   starting_address: 2 - 1,
        ...>   quantity_of_registers: 2,
        ...>   registers_value: [0x000A, 0x0102]
        ...> }
        iex> Modbuzz.PDU.encode(request)
        <<#{@function_code}, 0x0001::16, 0x0002::16, 0x04, 0x000A::16, 0x0102::16>>
    """
    def encode(struct) do
      binary = struct.registers_value |> Modbuzz.PDU.Helper.to_binary()

      <<@function_code::8, struct.starting_address::16, struct.quantity_of_registers::16,
        byte_size(binary)>> <> binary
    end

    @doc """
        iex> request = %Modbuzz.PDU.WriteMultipleRegisters{
        ...>   starting_address: 2 - 1,
        ...>   quantity_of_registers: 2,
        ...>   registers_value: [0x000A, 0x0102]
        ...> }
        iex> Modbuzz.PDU.decode(request, <<#{@function_code}, 0x0001::16, 0x0002::16>>)
        {:ok, nil}
        iex> Modbuzz.PDU.decode(request, <<#{@error_code}, 0x01>>)
        {:error, [exception_code: 1]}
    """
    def decode(_struct, <<@function_code::8, _starting_address::16, _quantity_of_registers::16>>) do
      {:ok, nil}
    end

    def decode(_struct, <<@error_code::8, exception_code::8>>) do
      {:error, exception_code: exception_code}
    end
  end
end
