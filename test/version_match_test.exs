defmodule VersionMatchTest do
  use ExUnit.Case, async: true

  @mise_toml File.read!(Path.join(__DIR__, "../mise.toml"))
  @ci_yaml File.read!(Path.join(__DIR__, "../.github/workflows/ci.yaml"))

  defp mise_version(tool) do
    case Regex.run(~r/^#{tool}\s*=\s*"([^"]+)"/m, @mise_toml, capture: :all_but_first) do
      [version] -> version
      nil -> raise "Tool '#{tool}' not found in mise.toml"
    end
  end

  defp ci_env(name) do
    case Regex.run(~r/^\s*#{name}:\s*(\S+)/m, @ci_yaml, capture: :all_but_first) do
      [value] -> value
      nil -> raise "Environment variable '#{name}' not found in ci.yaml"
    end
  end

  test "erlang version matches between mise.toml and ci.yaml" do
    assert mise_version("erlang") == ci_env("OTP_VERSION")
  end

  test "elixir version matches between mise.toml and ci.yaml" do
    elixir_in_mise = mise_version("elixir") |> String.replace(~r/-otp-\d+$/, "")

    assert elixir_in_mise == ci_env("ELIXIR_VERSION")
  end
end
