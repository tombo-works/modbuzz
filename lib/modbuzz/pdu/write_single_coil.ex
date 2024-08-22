defmodule Modbuzz.PDU.WriteSingleCoil do
  @moduledoc """
  #{Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)}

  ## Request type

    - `t()`

  ## Response types

    - `{:ok, nil}`
    - `{:error, exception: 1..4}`

  """

  @type t :: %__MODULE__{
          output_address: 0x0000..0xFFFF,
          output_value: boolean()
        }
  defstruct [:output_address, :output_value]

  defimpl Modbuzz.PDU do
    @function_code 0x05
    @error_code @function_code + 0x80

    @doc """
        iex> request = %Modbuzz.PDU.WriteSingleCoil{
        ...>   output_address: 173 - 1,
        ...>   output_value: true
        ...> }
        iex> Modbuzz.PDU.encode(request)
        <<#{@function_code}, 0x00AC::16, 0xFF00::16>>
    """
    def encode(struct) do
      output_value = if struct.output_value, do: 0xFF00, else: 0x0000
      <<@function_code::8, struct.output_address::16, output_value::16>>
    end

    @doc """
        iex> request = %Modbuzz.PDU.WriteSingleCoil{
        ...>   output_address: 173 - 1,
        ...>   output_value: true
        ...> }
        iex> Modbuzz.PDU.decode(request, <<#{@function_code}, 0x00AC::16, 0xFF00::16>>)
        {:ok, nil}
        iex> Modbuzz.PDU.decode(request, <<#{@error_code}, 0x01>>)
        {:error, [exception_code: 1]}
    """
    def decode(_struct, <<@function_code::8, _output_address::16, _output_value::16>>) do
      {:ok, nil}
    end

    def decode(_struct, <<@error_code::8, exception_code::8>>) do
      {:error, exception_code: exception_code}
    end
  end
end
