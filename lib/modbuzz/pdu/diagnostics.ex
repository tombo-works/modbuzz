defmodule Modbuzz.PDU.Diagnostics do
  @moduledoc false

  defmodule Req do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            sub_function: 0x0000..0xFFFF,
            data: 0x0000..0xFFFF
          }

    defstruct [:sub_function, :data]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x08

      @doc """
          iex> req = %Modbuzz.PDU.Diagnostics.Req{
          ...>   sub_function: 0x0000,
          ...>   data: 0xA537
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(req)
          <<#{@function_code}, 0x0000::16, 0xA537::16>>
      """
      def encode(struct) do
        <<@function_code, struct.sub_function::16, struct.data::16>>
      end

      @doc """
          iex> req = %Modbuzz.PDU.Diagnostics.Req{}
          iex> Modbuzz.PDU.Protocol.decode(req, <<#{@function_code}, 0x0000::16, 0xA537::16>>)
          %Modbuzz.PDU.Diagnostics.Req{sub_function: 0x0000, data: 0xA537}
      """
      def decode(struct, <<@function_code, sub_function::16, data::16>>) do
        %{struct | sub_function: sub_function, data: data}
      end

      def expected_binary_size(_struct, <<@function_code, _rest::binary>>) do
        1 + 2 + 2
      end
    end
  end

  defmodule Res do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            sub_function: 0x0000..0xFFFF,
            data: 0x0000..0xFFFF
          }

    defstruct [:sub_function, :data]

    defimpl Modbuzz.PDU.Protocol do
      @function_code 0x08

      @doc """
          iex> res = %Modbuzz.PDU.Diagnostics.Res{
          ...>   sub_function: 0x0000,
          ...>   data: 0xA537
          ...> }
          iex> Modbuzz.PDU.Protocol.encode(res)
          <<#{@function_code}, 0x0000::16, 0xA537::16>>
      """
      def encode(struct) do
        <<@function_code, struct.sub_function::16, struct.data::16>>
      end

      @doc """
          iex> res = %Modbuzz.PDU.Diagnostics.Res{}
          iex> Modbuzz.PDU.Protocol.decode(res, <<#{@function_code}, 0x0000::16, 0xA537::16>>)
          %Modbuzz.PDU.Diagnostics.Res{
            sub_function: 0x0000,
            data: 0xA537
          }
      """
      def decode(struct, <<@function_code, sub_function::16, data::16>>) do
        %{struct | sub_function: sub_function, data: data}
      end

      def expected_binary_size(_struct, <<@function_code, _rest::binary>>) do
        1 + 2 + 2
      end
    end
  end

  defmodule Err do
    @moduledoc Modbuzz.PDU.Helper.module_one_line_doc(__MODULE__)

    @type t :: %__MODULE__{
            exception_code: 0x01 | 0x03 | 0x04
          }

    defstruct [:exception_code]

    defimpl Modbuzz.PDU.Protocol do
      @error_code 0x08 + 0x80

      @doc """
          iex> err = %Modbuzz.PDU.Diagnostics.Err{exception_code: 0x01}
          iex> Modbuzz.PDU.Protocol.encode(err)
          <<#{@error_code}, 0x01>>
      """
      def encode(struct) do
        <<@error_code, struct.exception_code>>
      end

      @doc """
          iex> err = %Modbuzz.PDU.Diagnostics.Err{}
          iex> Modbuzz.PDU.Protocol.decode(err, <<#{@error_code}, 0x01>>)
          %Modbuzz.PDU.Diagnostics.Err{exception_code: 0x01}
      """
      def decode(struct, <<@error_code, exception_code>>) do
        %{struct | exception_code: exception_code}
      end

      def expected_binary_size(_struct, <<@error_code, _rest::binary>>) do
        1 + 1
      end
    end
  end
end
