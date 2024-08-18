defmodule Modbuzz.VersionMatchTest do
  use ExUnit.Case

  test "version match" do
    tool_versions_map =
      File.read!(".tool-versions")
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        cond do
          String.contains?(line, "erlang") ->
            [_, version] = String.split(line, " ")
            Map.put(acc, :erlang, version)

          String.contains?(line, "elixir") ->
            [_, version] = String.split(line, " ")
            [version, "otp", _] = String.split(version, "-")
            Map.put(acc, :elixir, version)

          true ->
            acc
        end
      end)

    ciyml_versions_map =
      File.read!(".github/workflows/ci.yaml")
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        cond do
          String.contains?(line, "OTP_VERSION: ") ->
            [_, version] = String.split(line, ": ")
            Map.put(acc, :erlang, version)

          String.contains?(line, "ELIXIR_VERSION: ") ->
            [_, version] = String.split(line, ": ")
            Map.put(acc, :elixir, version)

          true ->
            acc
        end
      end)

    assert tool_versions_map.erlang == ciyml_versions_map.erlang

    assert tool_versions_map.elixir == ciyml_versions_map.elixir
  end
end
