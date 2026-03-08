defmodule Mix.Tasks.LuckfoxPico.GenerateFwupConfigs do
  use Mix.Task

  @shortdoc "Generates .nerves/fwup.conf and .nerves/fw_env.config from BoardConfig.mk"

  @impl Mix.Task
  def run(_args) do
    root = File.cwd!()
    board_config_path = Path.join(root, ".nerves/BoardConfig.mk")
    template_path = Path.join(root, "fwup.conf.eex")
    output_path = Path.join(root, ".nerves/fwup.conf")
    fw_env_config_path = Path.join(root, ".nerves/fw_env.config")

    unless File.exists?(board_config_path) do
      Mix.raise("BoardConfig not found: #{board_config_path}")
    end

    board_config = File.read!(board_config_path)
    boot_medium = extract_export!(board_config, "RK_BOOT_MEDIUM")

    if boot_medium != "sd_card" do
      Mix.raise("Only sd_card board configs are supported. RK_BOOT_MEDIUM=#{boot_medium}")
    end

    partition_cmd = extract_export!(board_config, "RK_PARTITION_CMD_IN_ENV")
    parts = parse_partition_cmd!(partition_cmd)
    env_part = get_partition!(parts, "env")
    idblock_part = get_partition!(parts, "idblock")
    uboot_part = get_partition!(parts, "uboot")
    boot_part = get_partition!(parts, "boot")
    oem_part = get_partition!(parts, "oem")
    userdata_part = get_partition!(parts, "userdata")
    rootfs_part = get_partition!(parts, "rootfs")

    env_offset_blk = kib_to_blk(elem(env_part, 0))
    env_count_blk = kib_to_blk(elem(env_part, 1))
    idblock_offset_blk = kib_to_blk(elem(idblock_part, 0))
    uboot_offset_blk = kib_to_blk(elem(uboot_part, 0))
    boot_offset_blk = kib_to_blk(elem(boot_part, 0))
    boot_count_blk = kib_to_blk(elem(boot_part, 1))
    oem_offset_blk = kib_to_blk(elem(oem_part, 0))
    oem_count_blk = kib_to_blk(elem(oem_part, 1))
    userdata_offset_blk = kib_to_blk(elem(userdata_part, 0))
    userdata_count_blk = kib_to_blk(elem(userdata_part, 1))
    rootfs_offset_blk = kib_to_blk(elem(rootfs_part, 0))
    rootfs_count_blk = kib_to_blk(elem(rootfs_part, 1))
    boot_partnum = elem(boot_part, 2)
    userdata_partnum = elem(userdata_part, 2)
    rootfs_partnum = elem(rootfs_part, 2)
    fw_devpath = "/dev/mmcblk1"
    userdata_devpath = "/dev/mmcblk1p#{userdata_partnum}"
    rootfs_devpath = "/dev/mmcblk1p#{rootfs_partnum}"
    blkdevparts = "mmcblk1:#{partition_cmd}"

    assigns = [
      board_config_path: board_config_path,
      board_name: Path.basename(board_config_path, ".mk"),
      fw_devpath: fw_devpath,
      userdata_devpath: userdata_devpath,
      rootfs_devpath: rootfs_devpath,
      blkdevparts: blkdevparts,
      env_offset_blk: env_offset_blk,
      env_count_blk: env_count_blk,
      idblock_offset_blk: idblock_offset_blk,
      uboot_offset_blk: uboot_offset_blk,
      boot_offset_blk: boot_offset_blk,
      boot_count_blk: boot_count_blk,
      boot_partnum: boot_partnum,
      oem_offset_blk: oem_offset_blk,
      oem_count_blk: oem_count_blk,
      userdata_offset_blk: userdata_offset_blk,
      userdata_count_blk: userdata_count_blk,
      rootfs_offset_blk: rootfs_offset_blk,
      rootfs_count_blk: rootfs_count_blk
    ]

    rendered = EEx.eval_file(template_path, assigns)
    File.mkdir_p!(Path.dirname(output_path))
    File.write!(output_path, rendered)

    fw_env_config =
      render_fw_env_config(board_config_path, fw_devpath, kib_to_bytes(elem(env_part, 0)), kib_to_bytes(elem(env_part, 1)))

    File.mkdir_p!(Path.dirname(fw_env_config_path))
    File.write!(fw_env_config_path, fw_env_config)
  end

  defp render_fw_env_config(board_config_path, fw_devpath, env_offset_bytes, env_size_bytes) do
    """
    # Auto-generated from:
    #   #{board_config_path}
    # Do not edit generated output directly. Update board selection and regenerate.

    #{fw_devpath} 0x#{Integer.to_string(env_offset_bytes, 16)} 0x#{Integer.to_string(env_size_bytes, 16)}
    """
  end

  defp parse_partition_cmd!(partition_cmd) do
    partition_cmd
    |> String.split(",", trim: true)
    |> Enum.reduce({%{}, 0, 1}, fn entry, {acc, cursor_kib, partnum} ->
      case Regex.run(~r/^([^()]+)\(([^)]+)\)$/, String.trim(entry), capture: :all_but_first) do
        [definition, name] ->
          definition = String.trim(definition)
          name = String.trim(name)

          {size_kib, offset_kib} =
            case String.split(definition, "@", parts: 2) do
              [size, offset] ->
                {to_kib!(size), to_kib!(offset)}

              [size] ->
                {to_kib!(size), cursor_kib}
            end

          {Map.put(acc, name, {offset_kib, size_kib, partnum}), offset_kib + size_kib,
           partnum + 1}

        _ ->
          Mix.raise("Failed to parse partition entry: #{entry}")
      end
    end)
    |> elem(0)
  end

  defp get_partition!(parts, name) do
    case Map.fetch(parts, name) do
      {:ok, part} -> part
      :error -> Mix.raise("Required partition not found in BoardConfig: #{name}")
    end
  end

  defp to_kib!(value) do
    case Regex.run(~r/^\s*(\d+)\s*([KkMmGg]?)\s*$/, String.trim(value), capture: :all_but_first) do
      [n, ""] -> String.to_integer(n)
      [n, "K"] -> String.to_integer(n)
      [n, "k"] -> String.to_integer(n)
      [n, "M"] -> String.to_integer(n) * 1024
      [n, "m"] -> String.to_integer(n) * 1024
      [n, "G"] -> String.to_integer(n) * 1024 * 1024
      [n, "g"] -> String.to_integer(n) * 1024 * 1024
      _ -> Mix.raise("Unsupported partition size unit: #{value}")
    end
  end

  defp kib_to_blk(kib), do: kib * 2
  defp kib_to_bytes(kib), do: kib * 1024

  defp extract_export!(board_config, key) do
    case Regex.run(~r/^\s*export\s+#{key}=(.+)\s*$/m, board_config, capture: :all_but_first) do
      [value] -> strip_shell_quotes(String.trim(value))
      _ -> Mix.raise("Missing export #{key} in BoardConfig")
    end
  end

  defp strip_shell_quotes(value) do
    cond do
      String.length(value) >= 2 and String.starts_with?(value, "\"") and
          String.ends_with?(value, "\"") ->
        String.slice(value, 1..-2//1)

      String.length(value) >= 2 and String.starts_with?(value, "'") and
          String.ends_with?(value, "'") ->
        String.slice(value, 1..-2//1)

      true ->
        value
    end
  end
end
