defmodule Modbuzz.PDU.Helper do
  @moduledoc false

  import Bitwise

  @spec bin_to_boolean_bits(binary()) :: [] | [boolean()]
  def bin_to_boolean_bits(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.flat_map(&for(i <- 0..7, do: (&1 >>> i &&& 1) == 1))
  end
end
