defmodule Mix.Tasks.Compile.LuckfoxPico do
  use Mix.Task.Compiler

  @recursive true

  @impl Mix.Task.Compiler
  def run(_args) do
    Mix.Task.run("luckfox_pico.luckfox_sdk_artifacts", [])
    Mix.Task.run("luckfox_pico.generate_fwup_configs", [])
    {:ok, []}
  end
end
