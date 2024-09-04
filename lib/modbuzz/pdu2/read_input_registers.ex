defmodule Modbuzz.PDU2.ReadInputRegisters do
  @moduledoc false

  defmodule Req do
    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_input_registers: 0x0001..0x007D
          }

    defstruct [:starting_address, :quantity_of_input_registers]

    defimpl Modbuzz.PDU2.Protocol do
      @function_code 0x04

      @doc """
          iex> req = %Modbuzz.PDU2.ReadInputRegisters.Req{
          ...>   starting_address: 9 - 1,
          ...>   quantity_of_input_registers: 1
          ...> }
          iex> Modbuzz.PDU2.Protocol.encode(req)
          <<#{@function_code}, 0x0008::16, 0x0001::16>>
      """
      def encode(struct) do
        <<@function_code, struct.starting_address::16, struct.quantity_of_input_registers::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU2.ReadInputRegisters.Req{}
          iex> Modbuzz.PDU2.Protocol.decode(req, <<#{@function_code}, 0x0008::16, 0x0001::16>>)
          %Modbuzz.PDU2.ReadInputRegisters.Req{starting_address: 9 - 1, quantity_of_input_registers: 1}
      """
      def decode(
            struct,
            <<@function_code, starting_address::16, quantity_of_input_registers::16>>
          ) do
        %{
          struct
          | starting_address: starting_address,
            quantity_of_input_registers: quantity_of_input_registers
        }
      end
    end
  end

  defmodule Res do
    @type t :: %__MODULE__{
            byte_count: byte(),
            input_registers: [0x0000..0xFFFF]
          }

    defstruct [:byte_count, :input_registers]

    defimpl Modbuzz.PDU2.Protocol do
      @function_code 0x04

      @doc """
          iex> res = %Modbuzz.PDU2.ReadInputRegisters.Res{
          ...>   byte_count: 0x02,
          ...>   input_registers: [10]
          ...> }
          iex> Modbuzz.PDU2.Protocol.encode(res)
          <<#{@function_code}, 0x02, 0x00, 0x0A>>
      """
      def encode(struct) do
        binary = struct.input_registers |> Modbuzz.PDU.Helper.to_binary()
        <<@function_code, struct.byte_count, binary::binary-size(struct.byte_count)>>
      end

      @doc """
          iex> res = %Modbuzz.PDU2.ReadInputRegisters.Res{}
          iex> Modbuzz.PDU2.Protocol.decode(res, <<#{@function_code}, 0x02, 0x00, 0x0A>>)
          %Modbuzz.PDU2.ReadInputRegisters.Res{
            byte_count: 0x02,
            input_registers: [10]
          }
      """
      def decode(struct, <<@function_code, byte_count, input_registers::binary-size(byte_count)>>) do
        %{
          struct
          | byte_count: byte_count,
            input_registers: Modbuzz.PDU.Helper.to_registers(input_registers)
        }
      end
    end
  end

  defmodule Err do
    @type t :: %__MODULE__{
            exception_code: 0x01..0x04
          }

    defstruct [:exception_code]

    defimpl Modbuzz.PDU2.Protocol do
      @error_code 0x04 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU2.ReadInputRegisters.Err{exception_code: 0x01}
          iex> Modbuzz.PDU2.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU2.ReadInputRegisters.Err{}
          iex> Modbuzz.PDU2.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU2.ReadInputRegisters.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
