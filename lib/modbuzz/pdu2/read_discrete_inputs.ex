defmodule Modbuzz.PDU2.ReadDiscreteInputs do
  @moduledoc false

  defmodule Req do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_inputs: 1..2000
          }

    defstruct [:starting_address, :quantity_of_inputs]

    defimpl Modbuzz.PDU2.Protocol do
      @function_code 0x02

      @doc """
          iex> req = %Modbuzz.PDU2.ReadDiscreteInputs.Req{
          ...>   starting_address: 197 - 1,
          ...>   quantity_of_inputs: 22
          ...> }
          iex> Modbuzz.PDU2.Protocol.encode(req)
          <<#{@function_code}, 0x00C4::16, 0x0016::16>>
      """
      def encode(struct) do
        <<@function_code, struct.starting_address::16, struct.quantity_of_inputs::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU2.ReadDiscreteInputs.Req{}
          iex> Modbuzz.PDU2.Protocol.decode(req, <<#{@function_code}, 0x00C4::16, 0x0016::16>>)
          %Modbuzz.PDU2.ReadDiscreteInputs.Req{starting_address: 197 - 1, quantity_of_inputs: 22}
      """
      def decode(struct, <<@function_code, starting_address::16, quantity_of_inputs::16>>) do
        %{struct | starting_address: starting_address, quantity_of_inputs: quantity_of_inputs}
      end
    end
  end

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            byte_count: byte(),
            input_status: [] | [boolean()]
          }

    defstruct [:byte_count, :input_status]

    defimpl Modbuzz.PDU2.Protocol do
      @function_code 0x02

      @doc """
          iex> res = %Modbuzz.PDU2.ReadDiscreteInputs.Res{
          ...>   byte_count: 0x03,
          ...>   input_status: [
          ...>     false, false, true, true, false, true, false, true,
          ...>     true, true, false, true, true, false, true, true,
          ...>     true, false, true, false, true, true
          ...>   ]
          ...> }
          iex> Modbuzz.PDU2.Protocol.encode(res)
          <<#{@function_code}, 0x03, 0xAC, 0xDB, 0x35>>
      """
      def encode(struct) do
        binary = struct.input_status |> Modbuzz.PDU.Helper.to_binary()
        <<@function_code, struct.byte_count, binary::binary-size(struct.byte_count)>>
      end

      @doc """
          iex> res = %Modbuzz.PDU2.ReadDiscreteInputs.Res{}
          iex> Modbuzz.PDU2.Protocol.decode(res, <<#{@function_code}, 0x03, 0xAC, 0xDB, 0x35>>)
          %Modbuzz.PDU2.ReadDiscreteInputs.Res{
            byte_count: 0x03,
            input_status: [
              false, false, true, true, false, true, false, true,
              true, true, false, true, true, false, true, true,
              true, false, true, false, true, true, false, false
            ]
          }
      """
      def decode(struct, <<@function_code, byte_count, input_status::binary-size(byte_count)>>) do
        %{
          struct
          | byte_count: byte_count,
            input_status: Modbuzz.PDU.Helper.to_booleans(input_status)
        }
      end
    end
  end

  defmodule Err do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            exception_code: 0x01..0x04
          }

    defstruct [:exception_code]

    defimpl Modbuzz.PDU2.Protocol do
      @error_code 0x02 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU2.ReadDiscreteInputs.Err{exception_code: 0x01}
          iex> Modbuzz.PDU2.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU2.ReadDiscreteInputs.Err{}
          iex> Modbuzz.PDU2.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU2.ReadDiscreteInputs.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
