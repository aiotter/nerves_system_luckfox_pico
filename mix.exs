defmodule NervesSystemLuckfoxPico.MixProject do
  use Mix.Project

  @github_organization "aiotter"
  @app :nerves_system_luckfox_pico_mini
  @source_url "https://github.com/#{@github_organization}/#{@app}"
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      compilers: Mix.compilers() ++ [:luckfox_pico, :nerves_package],
      nerves_package: nerves_package(),
      description: description(),
      package: package(),
      deps: deps(),
      luckfox_pico_board: "RV1103_Luckfox_Pico_Mini",
      luckfox_pico_sdk_ref: "994243753789e1b40ef91122e8b3688aae8f01b8",
      aliases: [
        loadconfig: [&bootstrap/1]
      ],
      docs: docs()
    ]
  end

  def application do
    []
  end

  defp bootstrap(args) do
    set_target()
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  def cli do
    [preferred_envs: %{docs: :docs, "hex.build": :docs, "hex.publish": :docs}]
  end

  defp nerves_package do
    [
      type: :system,
      artifact_sites: [
        {:github_releases, "#{@github_organization}/#{@app}"}
      ],
      build_runner: Nerves.Artifact.BuildRunners.Docker,
      build_runner_opts: build_runner_opts(),
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      # The :env key is an optional experimental feature for adding environment
      # variables to the crosscompile environment. These are intended for
      # llvm-based tooling that may need more precise processor information.
      env: [
        {"TARGET_ARCH", "arm"},
        {"TARGET_CPU", "cortex_a7"},
        {"TARGET_OS", "linux"},
        {"TARGET_ABI", "gnueabihf"}
        # {"TARGET_GCC_FLAGS", "-mcpu=cortex-a7 -marm -mfloat-abi=hard"}
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, "~> 1.11", runtime: false},
      {:nerves_system_br, "1.33.2", runtime: false},
      {:nerves_toolchain_armv7_nerves_linux_gnueabihf, "~> 13.2", runtime: false},
      {:nerves_system_linter, "~> 0.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    Nerves System - LuckFox Pico
    """
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      assets: %{"assets" => "./assets"},
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp package do
    [
      files: package_files(),
      licenses: ["GPL-2.0-only", "GPL-2.0-or-later"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp package_files do
    [
      "busybox-luckfox.fragment",
      "Config.in",
      "external.mk",
      "fwup.conf.eex",
      "fwup_include",
      "docker",
      "lib",
      "Makefile",
      "mix.exs",
      "nerves_defconfig",
      "patches",
      "post-build.sh",
      "post-createfs.sh",
      "README.md",
      "rootfs_overlay",
      "VERSION"
    ]
  end

  defp build_runner_opts() do
    # Download source files first to get download errors right away.
    [make_args: primary_site() ++ ["source", "all", "legal-info"]]
  end

  defp primary_site() do
    case System.get_env("BR2_PRIMARY_SITE") do
      nil -> []
      primary_site -> ["BR2_PRIMARY_SITE=#{primary_site}"]
    end
  end

  defp set_target() do
    if function_exported?(Mix, :target, 1) do
      apply(Mix, :target, [:target])
    else
      System.put_env("MIX_TARGET", "target")
    end
  end
end
