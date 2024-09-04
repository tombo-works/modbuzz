defmodule Modbuzz.PDU2.WriteSingleRegister do
  @moduledoc false

  defmodule Req do
    @type t :: %__MODULE__{
            register_address: 0x0000..0xFFFF,
            register_value: 0x0000..0xFFFF
          }

    defstruct [:register_address, :register_value]

    defimpl Modbuzz.PDU2.Protocol do
      @function_code 0x06

      @doc """
          iex> req = %Modbuzz.PDU2.WriteSingleRegister.Req{
          ...>   register_address: 2 - 1,
          ...>   register_value: 3
          ...> }
          iex> Modbuzz.PDU2.Protocol.encode(req)
          <<#{@function_code}, 0x0001::16, 0x0003::16>>
      """
      def encode(struct) do
        <<@function_code::8, struct.register_address::16, struct.register_value::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU2.WriteSingleRegister.Req{}
          iex> Modbuzz.PDU2.Protocol.decode(req, <<#{@function_code}, 0x0001::16, 0x0003::16>>)
          %Modbuzz.PDU2.WriteSingleRegister.Req{register_address: 2 - 1, register_value: 3}
      """
      def decode(struct, <<@function_code, register_address::16, register_value::16>>) do
        %{struct | register_address: register_address, register_value: register_value}
      end
    end
  end

  defmodule Res do
    @type t :: %__MODULE__{
            register_address: 0x0000..0xFFFF,
            register_value: 0x0000..0xFFFF
          }

    defstruct [:register_address, :register_value]

    defimpl Modbuzz.PDU2.Protocol do
      @function_code 0x06

      @doc """
          iex> res = %Modbuzz.PDU2.WriteSingleRegister.Res{
          ...>   register_address: 2 - 1,
          ...>   register_value: 3
          ...> }
          iex> Modbuzz.PDU2.Protocol.encode(res)
          <<#{@function_code}, 0x00, 0x01, 0x00, 0x03>>
      """
      def encode(struct) do
        <<@function_code, struct.register_address::16, struct.register_value::16>>
      end

      @doc """
          iex> res = %Modbuzz.PDU2.WriteSingleRegister.Res{}
          iex> Modbuzz.PDU2.Protocol.decode(res, <<#{@function_code}, 0x00, 0x01, 0x00, 0x03>>)
          %Modbuzz.PDU2.WriteSingleRegister.Res{
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
    @type t :: %__MODULE__{
            exception_code: 0x01..0x04
          }

    defstruct [:exception_code]

    defimpl Modbuzz.PDU2.Protocol do
      @error_code 0x06 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU2.WriteSingleRegister.Err{exception_code: 0x01}
          iex> Modbuzz.PDU2.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU2.WriteSingleRegister.Err{}
          iex> Modbuzz.PDU2.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU2.WriteSingleRegister.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end
    end
  end
end
