#!/bin/sh

set -e

# Copy the fwup includes to the images dir
cp -rf $NERVES_DEFCONFIG_DIR/fwup_include $BINARIES_DIR

# Build/export Rockchip SD boot blobs (idblock/uboot).
# If the SDK is missing locally, luckfox-sdk.mk will fetch it automatically.
make -f "$NERVES_DEFCONFIG_DIR/luckfox-sdk.mk" \
    prepare-assets \
    NERVES_DEFCONFIG_DIR="$NERVES_DEFCONFIG_DIR" \
    BINARIES_DIR="$BINARIES_DIR"
