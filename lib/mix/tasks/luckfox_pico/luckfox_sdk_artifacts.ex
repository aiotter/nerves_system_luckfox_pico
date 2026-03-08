defmodule Mix.Tasks.LuckfoxPico.LuckfoxSdkArtifacts do
  use Mix.Task

  @shortdoc "Builds Luckfox SDK artifacts and extracts required images/config"

  @impl Mix.Task
  def run(_args) do
    board = project_config!(:luckfox_pico_board)
    sdk_ref = project_config!(:luckfox_pico_sdk_ref)
    run_streaming_cmd!("make", [
      "LUCKFOX_BOARD=#{board}",
      "LUCKFOX_SDK_GIT_REF=#{sdk_ref}"
    ])
  end

  defp project_config!(key) do
    case Mix.Project.config()[key] do
      nil -> Mix.raise("Missing project config: #{key}")
      value -> to_string(value)
    end
  end

  defp run_streaming_cmd!(cmd, args) do
    case System.cmd(cmd, args, stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_output, 0} ->
        :ok

      {_output, status} ->
        Mix.raise("Command failed: #{cmd} #{Enum.join(args, " ")} (exit #{status})")
    end
  end
end
