defmodule Modbuzz.PDU.ReadHoldingRegisters do
  @moduledoc """
  #{Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)}

  ## Request type

    - `t()`

  ## Response types

    - `{:ok, [] | [0x0000..0xFFFF]}`
    - `{:error, exception: 1..4}`

  """

  @type t :: %__MODULE__{
          starting_address: 0x0000..0xFFFF,
          quantity_of_registers: 1..125
        }
  defstruct [:starting_address, :quantity_of_registers]

  defimpl Modbuzz.PDU do
    @function_code 0x03
    @error_code @function_code + 0x80

    @doc """
        iex> request = %Modbuzz.PDU.ReadHoldingRegisters{
        ...>   starting_address: 108 - 1,
        ...>   quantity_of_registers: 3
        ...> }
        iex> Modbuzz.PDU.encode(request)
        <<#{@function_code}, 0x006B::16, 0x0003::16>>
    """
    def encode(struct) do
      <<@function_code::8, struct.starting_address::16, struct.quantity_of_registers::16>>
    end

    @doc """
        iex> request = %Modbuzz.PDU.ReadHoldingRegisters{
        ...>   starting_address: 108 - 1,
        ...>   quantity_of_registers: 3
        ...> }
        iex> Modbuzz.PDU.decode(request, <<#{@function_code}, 0x06, 0x022B::16, 0x0000::16, 0x0064::16>>)
        {:ok, [555, 0, 100]}
        iex> Modbuzz.PDU.decode(request, <<#{@error_code}, 0x01>>)
        {:error, [exception_code: 1]}
    """
    def decode(
          struct,
          <<@function_code::8, byte_count::8, register_value::binary-size(byte_count)>>
        ) do
      register_value
      |> Modbuzz.PDU.Helper.to_registers()
      |> Enum.take(struct.quantity_of_registers)
      |> then(&{:ok, &1})
    end

    def decode(_struct, <<@error_code::8, exception_code::8>>) do
      {:error, exception_code: exception_code}
    end
  end
end
