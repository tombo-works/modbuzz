defmodule Modbuzz.PDU.WriteMultipleRegisters do
  @moduledoc false

  defmodule Req do
    @moduledoc """
    Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    `byte_count` and `quantity_of_registers` are automatically calculated during encoding.
    """

    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_registers: 0x0001..0x007B,
            byte_count: byte(),
            register_values: [0x0000..0xFFFF]
          }

    defstruct [:starting_address, :quantity_of_registers, :byte_count, :register_values]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x10

      @doc """
          iex> req = %Modbuzz.PDU.WriteMultipleRegisters.Req{
          ...>   starting_address: 2 - 1,
          ...>   register_values: [0x000A, 0x0102]
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(req)
          <<#{@function_code}, 0x0001::16, 0x0002::16, 0x04, 0x000A::16, 0x0102::16>>
      """
      def encode(struct) do
        register_values = struct.register_values |> Modbuzz.PDU.Helper.to_binary()
        quantity_of_registers = Enum.count(struct.register_values)

        <<@function_code::8, struct.starting_address::16, quantity_of_registers::16,
          byte_size(register_values), register_values::binary>>
      end

      @doc """
          iex> req = %Modbuzz.PDU.WriteMultipleRegisters.Req{}
          iex> Modbuzz.PDU.Protocol.decode(req, <<#{@function_code}, 0x0001::16, 0x0002::16, 0x04, 0x000A::16, 0x0102::16>>)
          %Modbuzz.PDU.WriteMultipleRegisters.Req{
            starting_address: 2 - 1,
            quantity_of_registers: 2,
            byte_count: 4,
            register_values: [0x000A, 0x0102]
          }
      """
      def decode(
            struct,
            <<@function_code, starting_address::16, quantity_of_registers::16, byte_count,
              register_values::binary>>
          ) do
        register_values =
          Modbuzz.PDU.Helper.to_registers(register_values) |> Enum.take(quantity_of_registers)

        %{
          struct
          | starting_address: starting_address,
            quantity_of_registers: quantity_of_registers,
            byte_count: byte_count,
            register_values: register_values
        }
      end
    end
  end

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_registers: 0x0001..0x007B
          }

    defstruct [:starting_address, :quantity_of_registers]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x10

      @doc """
          iex> res = %Modbuzz.PDU.WriteMultipleRegisters.Res{
          ...>   starting_address: 2 - 1,
          ...>   quantity_of_registers: 2
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(res)
          <<#{@function_code}, 0x0001::16, 0x0002::16>>
      """
      def encode(struct) do
        <<@function_code, struct.starting_address::16, struct.quantity_of_registers::16>>
      end

      @doc """
          iex> res = %Modbuzz.PDU.WriteMultipleRegisters.Res{}
          iex> Modbuzz.PDU.Protocol.decode(res, <<#{@function_code}, 0x0001::16, 0x0002::16>>)
          %Modbuzz.PDU.WriteMultipleRegisters.Res{
            starting_address: 2 - 1,
            quantity_of_registers: 2
          }
      """
      def decode(struct, <<@function_code, starting_address::16, quantity_of_registers::16>>) do
        %{
          struct
          | starting_address: starting_address,
            quantity_of_registers: quantity_of_registers
        }
      end
    end
  end

  defmodule Err do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            exception_code: 0x01..0x04
          }

    defstruct [:exception_code]

    defimpl Modbuzz.PDU.Protocol do
      @error_code 0x10 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU.WriteMultipleRegisters.Err{exception_code: 0x01}
          iex> Modbuzz.PDU.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU.WriteMultipleRegisters.Err{}
          iex> Modbuzz.PDU.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU.WriteMultipleRegisters.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
