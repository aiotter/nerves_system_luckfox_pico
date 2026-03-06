# NervesSystemLuckfoxPico

Nerves system for Luckfox Pico (RV1106).

## Support Status

- Supported: microSD boot models
- Not supported: SPI NAND boot models (for now)
- Scope: this repository currently focuses on SD-card based development (initial programming + OTA flow)

## Boot Blobs For First Flash

`task complete` writes Rockchip boot blobs (`idblock.img`, `uboot.img`) in addition to the Nerves partitions.

During `post-build.sh`, it runs `luckfox-sdk.mk` to:

1. Build `idblock.img` / `uboot.img` once when missing
2. Generate `images/fwup.conf` from [fwup.conf.eex](fwup.conf.eex) using the selected BoardConfig (`RK_PARTITION_CMD_IN_ENV`)

The generated `images/fwup.conf` is used by `post-createfs.sh`.

SDK lookup order:

1. Existing local SDK checkout (workspace nearby paths)
2. Auto-cloned SDK in `/home/nerves/project/luckfox_pico_sdk` (inside Nerves build container)

To pin the SDK commit hash, set `LUCKFOX_SDK_GIT_REF` in [luckfox-board.mk](luckfox-board.mk) or pass `SDK_GIT_REF=<commit>` to make.

## Switch Board Model

Edit one line in [luckfox-board.mk](luckfox-board.mk):

`LUCKFOX_BOARD_CONFIG_REL ?= project/cfg/BoardConfig_IPC/<your-board-config>.mk`

Example:

`project/cfg/BoardConfig_IPC/BoardConfig-SD_CARD-Buildroot-RV1103_Luckfox_Pico_Mini-IPC.mk`

Notes:

- Only `sd_card` BoardConfig is supported by this Nerves system flow.
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
