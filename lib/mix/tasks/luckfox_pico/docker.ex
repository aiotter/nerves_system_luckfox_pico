defmodule Mix.Tasks.LuckfoxPico.Docker do
  use Mix.Task

  @shortdoc "Builds Luckfox blobs image and extracts prebuilt images/config"
  @docker_platform "linux/amd64"
  @prebuilt_root "/out"
  @version File.cwd!()
           |> Path.join("VERSION")
           |> File.read!()
           |> String.trim()

  @impl Mix.Task
  def run(_args) do
    root = File.cwd!()
    dockerfile = Path.join(root, "Dockerfile")
    board = project_config!(:luckfox_pico_board)
    sdk_ref = project_config!(:luckfox_pico_sdk_ref)
    image = docker_image(sdk_ref, board)

    run_streaming_cmd!("docker", [
      "build",
      "--platform",
      @docker_platform,
      "--file",
      dockerfile,
      "--tag",
      image,
      "--build-arg",
      "LUCKFOX_BOARD=#{board}",
      "--build-arg",
      "LUCKFOX_SDK_GIT_REF=#{sdk_ref}",
      root
    ])

    container_id =
      run_cmd!("docker", ["create", "--platform", @docker_platform, image])
      |> extract_container_id!()

    if container_id == "" do
      Mix.raise("Failed to create temporary Docker container for prebuilt extraction")
    end

    try do
      prebuilt_out = Path.join(root, ".nerves/luckfox_prebuilt")
      board_config_out = Path.join(root, ".nerves/BoardConfig.mk")
      File.mkdir_p!(prebuilt_out)
      File.mkdir_p!(Path.dirname(board_config_out))

      run_streaming_cmd!("docker", [
        "cp",
        "#{container_id}:#{@prebuilt_root}/idblock.img",
        Path.join(prebuilt_out, "idblock.img")
      ])

      run_streaming_cmd!("docker", [
        "cp",
        "#{container_id}:#{@prebuilt_root}/uboot.img",
        Path.join(prebuilt_out, "uboot.img")
      ])

      board_config_prebuilt = Path.join(prebuilt_out, "BoardConfig.mk")

      run_streaming_cmd!("docker", [
        "cp",
        "#{container_id}:#{@prebuilt_root}/BoardConfig.mk",
        board_config_prebuilt
      ])

      File.cp!(board_config_prebuilt, board_config_out)
    after
      _ = System.cmd("docker", ["rm", "-f", container_id], stderr_to_stdout: true)
    end
  end

  defp project_config!(key) do
    case Mix.Project.config()[key] do
      nil -> Mix.raise("Missing project config: #{key}")
      value -> to_string(value)
    end
  end

  defp extract_container_id!(output) do
    case Regex.scan(~r/\b[0-9a-f]{64}\b/, output) |> List.flatten() |> List.last() do
      nil ->
        IO.binwrite(output)
        Mix.raise("Failed to parse container id from docker create output")

      container_id ->
        container_id
    end
  end

  defp docker_image(sdk_ref, board_name) do
    "nerves_system_luckfox_pico-#{String.downcase(board_name)}:#{@version}-#{sdk_ref}"
  end

  defp run_cmd!(cmd, args) do
    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {output, 0} ->
        output

      {output, status} ->
        IO.binwrite(output)
        Mix.raise("Command failed: #{cmd} #{Enum.join(args, " ")} (exit #{status})")
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
