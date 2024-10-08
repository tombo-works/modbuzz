defmodule Modbuzz.PDU.Helper do
  @moduledoc false

  import Bitwise

  def module_one_line_doc(module) when is_atom(module) do
    ["Modbuzz", "PDU", modbus_function, type] = Module.split(module)
    "#{type} struct for #{modbus_function}."
  end

  @spec to_boolean(0xFF00 | 0x0000) :: boolean()
  def to_boolean(0xFF00), do: true
  def to_boolean(0x0000), do: false

  @spec to_integer(boolean()) :: 0xFF00 | 0x0000
  def to_integer(true), do: 0xFF00
  def to_integer(false), do: 0x0000

  @spec to_booleans(binary()) :: [] | [boolean()]
  def to_booleans(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.flat_map(&for(i <- 0..7, do: (&1 >>> i &&& 1) == 1))
  end

  @spec to_registers(binary()) :: [] | [non_neg_integer()]
  def to_registers(<<>>), do: []

  def to_registers(binary) when is_binary(binary) do
    <<register::16, rest::binary>> = binary
    [register | to_registers(rest)]
  end

  @spec to_binary([]) :: binary()
  def to_binary([] = list) when is_list(list) do
    <<>>
  end

  @spec to_binary([boolean()]) :: binary()
  def to_binary([h | _t] = list) when is_list(list) and is_boolean(h) do
    list
    |> Enum.chunk_every(8, 8, Stream.cycle([false]))
    |> Enum.map(fn list ->
      list
      |> Enum.with_index()
      |> Enum.reduce(0, fn
        {true, index}, acc -> 1 <<< index ||| acc
        {false, _index}, acc -> acc
      end)
    end)
    |> Enum.map_join(&<<&1>>)
  end

  @spec to_binary([0x0000..0xFFFF]) :: binary()
  def to_binary([h | _t] = list) when is_list(list) and is_integer(h) do
    list |> Enum.map_join(&<<&1::16>>)
  end
end
