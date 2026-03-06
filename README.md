# NervesSystemLuckfoxPico

Nerves system for Luckfox Pico (RV1106).

## Support Status

- Supported: microSD boot models
- Not supported: SPI NAND boot models (for now)
- Scope: this repository currently focuses on SD-card based development (initial programming + OTA flow)

## Boot Blobs For First Flash

`task complete` writes Rockchip boot blobs (`idblock.img`, `uboot.img`) in addition to the Nerves partitions.

`loadconfig` runs these steps before the Buildroot build:

1. Build Docker image from [Dockerfile](Dockerfile) (`luckfoxtech/luckfox_pico` stage generates `idblock.img` / `uboot.img` / `BoardConfig.mk`)
2. Copy `BoardConfig.mk` from that image to `.nerves/BoardConfig.mk`
3. Generate `.nerves/fwup.conf` from [fwup.conf.eex](fwup.conf.eex) in Elixir

During `post-build.sh`, this repository copies prebuilt `idblock.img` / `uboot.img` to Buildroot `images/`.
The generated `.nerves/fwup.conf` is consumed by `post-createfs.sh`.

## Build Container

This system always uses Docker build_runner and the repository `Dockerfile`.
The Dockerfile stages are:

1. `luckfoxtech/luckfox_pico` for `idblock.img`/`uboot.img` build
2. `ghcr.io/nerves-project/nerves_system_br` for the final Nerves build environment

## Switch Board Model

Set `LUCKFOX_BOARD_CONFIG_REL` before `mix firmware` (or change defaults in [mix.exs](mix.exs)):

`LUCKFOX_BOARD_CONFIG_REL=project/cfg/BoardConfig_IPC/<your-board-config>.mk`

Example:

`LUCKFOX_BOARD_CONFIG_REL=project/cfg/BoardConfig_IPC/BoardConfig-SD_CARD-Buildroot-RV1103_Luckfox_Pico_Mini-IPC.mk`

Notes:

- Only `sd_card` BoardConfig is supported by this Nerves system flow.
- Rebuild happens automatically in `loadconfig` when `LUCKFOX_BOARD_CONFIG_REL` or `LUCKFOX_SDK_GIT_REF` changes.
- `fwup.conf` is generated automatically from the selected BoardConfig, so partition offsets update with the model.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nerves_system_luckfox_pico` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nerves_system_luckfox_pico, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/nerves_system_luckfox_pico>.
