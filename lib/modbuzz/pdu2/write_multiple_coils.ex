defmodule Modbuzz.PDU.WriteMultipleCoils do
  @moduledoc false

  defmodule Req do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_outputs: 0x0001..0x07B0,
            byte_count: byte(),
            output_values: [boolean()]
          }

    defstruct [:starting_address, :quantity_of_outputs, :byte_count, :output_values]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x0F

      @doc """
          iex> req = %Modbuzz.PDU.WriteMultipleCoils.Req{
          ...>   starting_address: 20 - 1,
          ...>   output_values: [true, false, true, true, false, false, true, true, true, false]
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(req)
          <<#{@function_code}, 0x0013::16, 0x000A::16, 0x02, 0xCD01::16>>
      """
      def encode(struct) do
        output_values = struct.output_values |> Modbuzz.PDU.Helper.to_binary()
        quantity_of_outputs = Enum.count(struct.output_values)

        <<@function_code::8, struct.starting_address::16, quantity_of_outputs::16,
          byte_size(output_values), output_values::binary>>
      end

      @doc """
          iex> req = %Modbuzz.PDU.WriteMultipleCoils.Req{}
          iex> Modbuzz.PDU.Protocol.decode(req, <<#{@function_code}, 0x0013::16, 0x000A::16, 0x02, 0xCD01::16>>)
          %Modbuzz.PDU.WriteMultipleCoils.Req{
            starting_address: 20 - 1,
            quantity_of_outputs: 10,
            byte_count: 2,
            output_values: [true, false, true, true, false, false, true, true, true, false]
          }
      """
      def decode(
            struct,
            <<@function_code, starting_address::16, quantity_of_outputs::16, byte_count,
              output_values::binary>>
          ) do
        output_values =
          Modbuzz.PDU.Helper.to_booleans(output_values) |> Enum.take(quantity_of_outputs)

        %{
          struct
          | starting_address: starting_address,
            quantity_of_outputs: quantity_of_outputs,
            byte_count: byte_count,
            output_values: output_values
        }
      end
    end
  end

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_outputs: 0x0001..0x07B0
          }

    defstruct [:starting_address, :quantity_of_outputs]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x0F

      @doc """
          iex> res = %Modbuzz.PDU.WriteMultipleCoils.Res{
          ...>   starting_address: 20 - 1,
          ...>   quantity_of_outputs: 10
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(res)
          <<#{@function_code}, 0x0013::16, 0x000A::16>>
      """
      def encode(struct) do
        <<@function_code, struct.starting_address::16, struct.quantity_of_outputs::16>>
      end

      @doc """
          iex> res = %Modbuzz.PDU.WriteMultipleCoils.Res{}
          iex> Modbuzz.PDU.Protocol.decode(res, <<#{@function_code}, 0x0013::16, 0x000A::16>>)
          %Modbuzz.PDU.WriteMultipleCoils.Res{
            starting_address: 20 - 1,
            quantity_of_outputs: 10
          }
      """
      def decode(struct, <<@function_code, starting_address::16, quantity_of_outputs::16>>) do
        %{struct | starting_address: starting_address, quantity_of_outputs: quantity_of_outputs}
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
      @error_code 0x0F + 0x80

      @doc """
          iex> err = %Modbuzz.PDU.WriteMultipleCoils.Err{exception_code: 0x01}
          iex> Modbuzz.PDU.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU.WriteMultipleCoils.Err{}
          iex> Modbuzz.PDU.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU.WriteMultipleCoils.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
