defmodule Modbuzz.PDU.ReadHoldingRegisters do
  @moduledoc false

  defmodule Req do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_registers: 1..125
          }

    defstruct [:starting_address, :quantity_of_registers]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x03

      @doc """
          iex> req = %Modbuzz.PDU.ReadHoldingRegisters.Req{
          ...>   starting_address: 108 - 1,
          ...>   quantity_of_registers: 3
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(req)
          <<#{@function_code}, 0x006B::16, 0x0003::16>>
      """
      def encode(struct) do
        <<@function_code, struct.starting_address::16, struct.quantity_of_registers::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU.ReadHoldingRegisters.Req{}
          iex> Modbuzz.PDU.Protocol.decode(req, <<#{@function_code}, 0x006B::16, 0x0003::16>>)
          %Modbuzz.PDU.ReadHoldingRegisters.Req{starting_address: 108 - 1, quantity_of_registers: 3}
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

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            byte_count: byte(),
            register_value: 0x0000..0xFFFF
          }

    defstruct [:byte_count, :register_value]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x03

      @doc """
          iex> res = %Modbuzz.PDU.ReadHoldingRegisters.Res{
          ...>   byte_count: 0x06,
          ...>   register_value: [555, 0, 100]
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(res)
          <<#{@function_code}, 0x06, 0x02, 0x2B, 0x00, 0x00, 0x00, 0x64>>
      """
      def encode(struct) do
        binary = struct.register_value |> Modbuzz.PDU.Helper.to_binary()
        <<@function_code, struct.byte_count, binary::binary-size(struct.byte_count)>>
      end

      @doc """
          iex> res = %Modbuzz.PDU.ReadHoldingRegisters.Res{}
          iex> Modbuzz.PDU.Protocol.decode(res, <<#{@function_code}, 0x06, 0x02, 0x2B, 0x00, 0x00, 0x00, 0x64>>)
          %Modbuzz.PDU.ReadHoldingRegisters.Res{
            byte_count: 0x06,
            register_value: [555, 0, 100]
          }
      """
      def decode(struct, <<@function_code, byte_count, register_value::binary-size(byte_count)>>) do
        %{
          struct
          | byte_count: byte_count,
            register_value: Modbuzz.PDU.Helper.to_registers(register_value)
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
      @error_code 0x03 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU.ReadHoldingRegisters.Err{exception_code: 0x01}
          iex> Modbuzz.PDU.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU.ReadHoldingRegisters.Err{}
          iex> Modbuzz.PDU.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU.ReadHoldingRegisters.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
