defmodule Modbuzz.PDU.WriteSingleRegister do
  @moduledoc """
  #{Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)}

  ## Request type

    - `t()`

  ## Response types

    - `{:ok, nil}`
    - `{:error, exception: 1..4}`

  """

  @type t :: %__MODULE__{
          register_address: 0x0000..0xFFFF,
          register_value: 0x0000..0xFFFF
        }
  defstruct [:register_address, :register_value]

  defimpl Modbuzz.PDU do
    @function_code 0x06
    @error_code @function_code + 0x80

    @doc """
        iex> request = %Modbuzz.PDU.WriteSingleRegister{
        ...>   register_address: 2 - 1,
        ...>   register_value: 3
        ...> }
        iex> Modbuzz.PDU.encode(request)
        <<#{@function_code}, 0x0001::16, 0x0003::16>>
    """
    def encode(struct) do
      <<@function_code::8, struct.register_address::16, struct.register_value::16>>
    end

    @doc """
        iex> request = %Modbuzz.PDU.WriteSingleRegister{
        ...>   register_address: 2 - 1,
        ...>   register_value: 3
        ...> }
        iex> Modbuzz.PDU.decode(request, <<#{@function_code}, 0x0001::16, 0x0003::16>>)
        {:ok, nil}
        iex> Modbuzz.PDU.decode(request, <<#{@error_code}, 0x01>>)
        {:error, [exception_code: 1]}
    """
    def decode(_struct, <<@function_code::8, _register_address::16, _register_value::16>>) do
      {:ok, nil}
    end

    def decode(_struct, <<@error_code::8, exception_code::8>>) do
      {:error, exception_code: exception_code}
    end
  end
end
