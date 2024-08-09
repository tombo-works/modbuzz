defmodule ModbuzzTest do
  use ExUnit.Case
  doctest Modbuzz

  test "greets the world" do
    assert Modbuzz.hello() == :world
  end
end
