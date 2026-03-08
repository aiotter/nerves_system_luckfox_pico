#!/bin/sh

set -e

PREBUILT_ROOT="$NERVES_DEFCONFIG_DIR/.nerves/luckfox_prebuilt"
PREBUILT_IDBLOCK_IMG="$PREBUILT_ROOT/idblock.img"
PREBUILT_UBOOT_IMG="$PREBUILT_ROOT/uboot.img"
PREBUILT_ZIMAGE="$PREBUILT_ROOT/zImage"
PREBUILT_KERNEL_DTB="$PREBUILT_ROOT/kernel.dtb"
PREBUILT_USERDATA_IMG="$PREBUILT_ROOT/userdata.img"
NERVES_BR_PATCH="$NERVES_DEFCONFIG_DIR/patches/nerves_system_br/0001-merge-squashfs-default-to-xz.patch"

require_prebuilt() {
    if [ ! -f "$1" ]; then
        echo "ERROR: missing SDK prebuilt artifact: $1"
        exit 1
    fi
}

if [ ! -f "$NERVES_BR_PATCH" ]; then
    echo "ERROR: missing patch: $NERVES_BR_PATCH"
    exit 1
fi

if [ ! -f "$BR2_EXTERNAL_NERVES_PATH/scripts/merge-squashfs" ]; then
    echo "ERROR: merge-squashfs not found in BR2 external path"
    exit 1
fi

if ! grep -q 'MKSQUASHFS_FLAGS="${NERVES_MKSQUASHFS_FLAGS}"' "$BR2_EXTERNAL_NERVES_PATH/scripts/merge-squashfs"; then
    patch -d "$BR2_EXTERNAL_NERVES_PATH" -p1 < "$NERVES_BR_PATCH"
fi

# Copy the fwup includes to the images dir
cp -rf "$NERVES_DEFCONFIG_DIR/fwup_include" "$BINARIES_DIR"

# Export prebuilt Rockchip SD boot blobs.
require_prebuilt "$PREBUILT_IDBLOCK_IMG"
require_prebuilt "$PREBUILT_UBOOT_IMG"
require_prebuilt "$PREBUILT_ZIMAGE"
require_prebuilt "$PREBUILT_KERNEL_DTB"
require_prebuilt "$PREBUILT_USERDATA_IMG"

cp -f "$PREBUILT_IDBLOCK_IMG" "$BINARIES_DIR/idblock.img"
cp -f "$PREBUILT_UBOOT_IMG" "$BINARIES_DIR/uboot.img"
cp -f "$PREBUILT_ZIMAGE" "$BINARIES_DIR/zImage"
cp -f "$PREBUILT_KERNEL_DTB" "$BINARIES_DIR/kernel.dtb"
cp -f "$PREBUILT_USERDATA_IMG" "$BINARIES_DIR/userdata.img"
