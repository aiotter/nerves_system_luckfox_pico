# NervesSystemLuckfoxPico

Nerves system for Luckfox Pico Mini (RV1103).

## Support Status

- Supported: microSD boot models
- Not supported: SPI NAND boot models (for now)
- OTA partition strategy: single rootfs slot (`task upgrade` writes the active rootfs partition directly)
- A/B updates (dual rootfs slots with rollback) are not implemented yet

## Quick Notes

- Docker is required (SDK prebuilt image generation/extraction depends on Docker).

## Switch Board Model

Set `luckfox_pico_board` in [mix.exs](mix.exs):

`luckfox_pico_board: "RV1103_Luckfox_Pico_Mini"`

Example:

`luckfox_pico_board: "RV1106_Luckfox_Pico_Max"`

## Implementation Notes (for maintainers)

### Board selection and regeneration

- `luckfox_pico_board` is passed to Docker as `LUCKFOX_BOARD` and mapped to `BoardConfig-SD_CARD-Buildroot-${LUCKFOX_BOARD}-IPC.mk`.
- Only `sd_card` BoardConfig is supported by this Nerves system flow.
- Rebuild happens automatically in `loadconfig` when `luckfox_pico_board` or `LUCKFOX_SDK_GIT_REF` changes.
- `fwup.conf` is generated automatically from the selected BoardConfig, so partition offsets update with the model.

### Boot blobs and fwup config generation

Here, "SDK" means the official Luckfox build tree:
[LuckfoxTECH/luckfox-pico](https://github.com/LuckfoxTECH/luckfox-pico)
(`LUCKFOX_SDK_GIT_URL` / `LUCKFOX_SDK_GIT_REF` in [Dockerfile](Dockerfile)).

Rockchip boot blobs (`idblock.img`, `uboot.img`) are written to raw offsets on the
microSD device (not to a filesystem path). In this system, that happens on
initial flash task `complete` (for example `mix firmware.burn --task complete`).

`loadconfig` runs these steps before the Buildroot build:

1. Build Docker image from [Dockerfile](Dockerfile) (`luckfoxtech/luckfox_pico` stage runs SDK `build.sh uboot` and `build.sh kernel`, then exports `idblock.img` / `uboot.img` / `zImage` / `kernel.dtb` / `userdata.img` / `BoardConfig.mk`)
2. Copy `BoardConfig.mk` from that image to `.nerves/BoardConfig.mk`
3. Generate `.nerves/fwup.conf` and `.nerves/fw_env.config` in Elixir

During `post-build.sh`, this repository copies prebuilt `idblock.img` / `uboot.img` to Buildroot `images/`.
The generated `.nerves/fwup.conf` is consumed by `post-createfs.sh`, and `.nerves/fw_env.config` is installed to `/etc/fw_env.config`.

### Docker stages

The Dockerfile stages are:

1. `luckfoxtech/luckfox_pico` for `idblock.img`/`uboot.img` build
2. `ghcr.io/nerves-project/nerves_system_br` for the final Nerves build environment
