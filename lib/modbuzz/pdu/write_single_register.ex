defmodule Modbuzz.PDU.WriteSingleRegister do
  @moduledoc false

  defmodule Req do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            register_address: 0x0000..0xFFFF,
            register_value: 0x0000..0xFFFF
          }

    defstruct [:register_address, :register_value]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x06

      @doc """
          iex> req = %Modbuzz.PDU.WriteSingleRegister.Req{
          ...>   register_address: 2 - 1,
          ...>   register_value: 3
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(req)
          <<#{@function_code}, 0x0001::16, 0x0003::16>>
      """
      def encode(struct) do
        <<@function_code::8, struct.register_address::16, struct.register_value::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU.WriteSingleRegister.Req{}
          iex> Modbuzz.PDU.Protocol.decode(req, <<#{@function_code}, 0x0001::16, 0x0003::16>>)
          %Modbuzz.PDU.WriteSingleRegister.Req{register_address: 2 - 1, register_value: 3}
      """
      def decode(struct, <<@function_code, register_address::16, register_value::16>>) do
        %{struct | register_address: register_address, register_value: register_value}
      end
    end
  end

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            register_address: 0x0000..0xFFFF,
            register_value: 0x0000..0xFFFF
          }

    defstruct [:register_address, :register_value]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x06

      @doc """
          iex> res = %Modbuzz.PDU.WriteSingleRegister.Res{
          ...>   register_address: 2 - 1,
          ...>   register_value: 3
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(res)
          <<#{@function_code}, 0x00, 0x01, 0x00, 0x03>>
      """
      def encode(struct) do
        <<@function_code, struct.register_address::16, struct.register_value::16>>
      end

      @doc """
          iex> res = %Modbuzz.PDU.WriteSingleRegister.Res{}
          iex> Modbuzz.PDU.Protocol.decode(res, <<#{@function_code}, 0x00, 0x01, 0x00, 0x03>>)
          %Modbuzz.PDU.WriteSingleRegister.Res{
            register_address: 2 - 1,
            register_value: 3
          }
      """
      def decode(struct, <<@function_code, register_address::16, register_value::16>>) do
        %{struct | register_address: register_address, register_value: register_value}
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
      @error_code 0x06 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU.WriteSingleRegister.Err{exception_code: 0x01}
          iex> Modbuzz.PDU.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU.WriteSingleRegister.Err{}
          iex> Modbuzz.PDU.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU.WriteSingleRegister.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
