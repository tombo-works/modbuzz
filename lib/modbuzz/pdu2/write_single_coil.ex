defmodule Modbuzz.PDU.WriteSingleCoil do
  @moduledoc false

  defmodule Req do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            output_address: 0x0000..0xFFFF,
            output_value: boolean()
          }

    defstruct [:output_address, :output_value]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x05

      @doc """
          iex> req = %Modbuzz.PDU.WriteSingleCoil.Req{
          ...>   output_address: 173 - 1,
          ...>   output_value: true
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(req)
          <<#{@function_code}, 0x00AC::16, 0xFF00::16>>
      """
      def encode(struct) do
        output_value = if struct.output_value, do: 0xFF00, else: 0x0000
        <<@function_code::8, struct.output_address::16, output_value::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU.WriteSingleCoil.Req{}
          iex> Modbuzz.PDU.Protocol.decode(req, <<#{@function_code}, 0x00AC::16, 0xFF00::16>>)
          %Modbuzz.PDU.WriteSingleCoil.Req{output_address: 173 - 1, output_value: true}
      """
      def decode(struct, <<@function_code, output_address::16, output_value::16>>) do
        output_value = Modbuzz.PDU.Helper.to_boolean(output_value)
        %{struct | output_address: output_address, output_value: output_value}
      end
    end
  end

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            output_address: 0x0000..0xFFFF,
            output_value: boolean()
          }

    defstruct [:output_address, :output_value]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x05

      @doc """
          iex> res = %Modbuzz.PDU.WriteSingleCoil.Res{
          ...>   output_address: 173 - 1,
          ...>   output_value: true
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(res)
          <<#{@function_code}, 0x00, 0xAC, 0xFF, 0x00>>
      """
      def encode(struct) do
        output_value = Modbuzz.PDU.Helper.to_integer(struct.output_value)
        <<@function_code, struct.output_address::16, output_value::16>>
      end

      @doc """
          iex> res = %Modbuzz.PDU.WriteSingleCoil.Res{}
          iex> Modbuzz.PDU.Protocol.decode(res, <<#{@function_code}, 0x00, 0xAC, 0xFF, 0x00>>)
          %Modbuzz.PDU.WriteSingleCoil.Res{
            output_address: 173 - 1,
            output_value: true
          }
      """
      def decode(struct, <<@function_code, output_address::16, output_value::16>>) do
        %{
          struct
          | output_address: output_address,
            output_value: Modbuzz.PDU.Helper.to_boolean(output_value)
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

    defimpl Modbuzz.PDU.Protocol do
      @error_code 0x05 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU.WriteSingleCoil.Err{exception_code: 0x01}
          iex> Modbuzz.PDU.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU.WriteSingleCoil.Err{}
          iex> Modbuzz.PDU.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU.WriteSingleCoil.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
