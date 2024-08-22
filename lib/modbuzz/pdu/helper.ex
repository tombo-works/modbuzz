defmodule Modbuzz.PDU.Helper do
  @moduledoc false

  import Bitwise

  def module_one_line_doc(module) when is_atom(module) do
    type = module |> Module.split() |> List.last()
    "`Modbuzz.PDU` implementation of #{type}."
  end

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
end
