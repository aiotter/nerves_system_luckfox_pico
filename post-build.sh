#!/bin/sh

set -e

PREBUILT_ROOT="$NERVES_DEFCONFIG_DIR/.nerves/luckfox_prebuilt"
PREBUILT_IDBLOCK_IMG="$PREBUILT_ROOT/idblock.img"
PREBUILT_UBOOT_IMG="$PREBUILT_ROOT/uboot.img"

# Copy the fwup includes to the images dir
cp -rf "$NERVES_DEFCONFIG_DIR/fwup_include" "$BINARIES_DIR"

# Export prebuilt Rockchip SD boot blobs.
cp -f "$PREBUILT_IDBLOCK_IMG" "$BINARIES_DIR/idblock.img"
cp -f "$PREBUILT_UBOOT_IMG" "$BINARIES_DIR/uboot.img"
