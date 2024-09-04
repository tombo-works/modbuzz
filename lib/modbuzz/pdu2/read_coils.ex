defmodule Modbuzz.PDU.ReadCoils do
  @moduledoc false

  defmodule Req do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            starting_address: 0x0000..0xFFFF,
            quantity_of_coils: 1..2000
          }

    defstruct [:starting_address, :quantity_of_coils]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x01

      @doc """
          iex> req = %Modbuzz.PDU.ReadCoils.Req{
          ...>   starting_address: 20 - 1,
          ...>   quantity_of_coils: 19
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(req)
          <<#{@function_code}, 0x0013::16, 0x0013::16>>
      """
      def encode(struct) do
        <<@function_code, struct.starting_address::16, struct.quantity_of_coils::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU.ReadCoils.Req{}
          iex> Modbuzz.PDU.Protocol.decode(req, <<#{@function_code}, 0x0013::16, 0x0013::16>>)
          %Modbuzz.PDU.ReadCoils.Req{starting_address: 20 - 1, quantity_of_coils: 19}
      """
      def decode(struct, <<@function_code, starting_address::16, quantity_of_coils::16>>) do
        %{struct | starting_address: starting_address, quantity_of_coils: quantity_of_coils}
      end
    end
  end

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc2(__MODULE__)

    @type t :: %__MODULE__{
            byte_count: byte(),
            coil_status: [] | [boolean()]
          }

    defstruct [:byte_count, :coil_status]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x01

      @doc """
          iex> res = %Modbuzz.PDU.ReadCoils.Res{
          ...>   byte_count: 0x03,
          ...>   coil_status: [
          ...>     true, false, true, true, false, false, true, true,
          ...>     true, true, false, true, false, true, true, false,
          ...>     true, false, true, false, false, false, false, false
          ...>   ]
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(res)
          <<#{@function_code}, 0x03, 0xCD, 0x6B, 0x05>>
      """
      def encode(struct) do
        binary = struct.coil_status |> Modbuzz.PDU.Helper.to_binary()
        <<@function_code, struct.byte_count, binary::binary-size(struct.byte_count)>>
      end

      @doc """
          iex> res = %Modbuzz.PDU.ReadCoils.Res{}
          iex> Modbuzz.PDU.Protocol.decode(res, <<#{@function_code}, 0x03, 0xCD, 0x6B, 0x05>>)
          %Modbuzz.PDU.ReadCoils.Res{
            byte_count: 0x03,
            coil_status: [
              true, false, true, true, false, false, true, true,
              true, true, false, true, false, true, true, false,
              true, false, true, false, false, false, false, false
            ]
          }
      """
      def decode(struct, <<@function_code, byte_count, coil_status::binary-size(byte_count)>>) do
        %{
          struct
          | byte_count: byte_count,
            coil_status: Modbuzz.PDU.Helper.to_booleans(coil_status)
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
      @error_code 0x01 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU.ReadCoils.Err{exception_code: 0x01}
          iex> Modbuzz.PDU.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU.ReadCoils.Err{}
          iex> Modbuzz.PDU.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU.ReadCoils.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
