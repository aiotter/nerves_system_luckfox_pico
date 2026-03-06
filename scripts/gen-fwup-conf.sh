#!/bin/sh

set -eu

BOARD_CONFIG="$1"
OUTPUT="$2"

if [ ! -f "$BOARD_CONFIG" ]; then
    echo "ERROR: Board config not found: $BOARD_CONFIG" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
TEMPLATE="$SCRIPT_DIR/../fwup.conf.eex"

if [ ! -f "$TEMPLATE" ]; then
    echo "ERROR: Template not found: $TEMPLATE" >&2
    exit 1
fi

# shellcheck source=/dev/null
. "$BOARD_CONFIG"

if [ "${RK_BOOT_MEDIUM:-}" != "sd_card" ]; then
    echo "ERROR: Only sd_card board configs are supported for fwup generation." >&2
    echo "RK_BOOT_MEDIUM=${RK_BOOT_MEDIUM:-unset}" >&2
    exit 1
fi

PARTITIONS="${RK_PARTITION_CMD_IN_ENV:-}"
if [ -z "$PARTITIONS" ]; then
    echo "ERROR: RK_PARTITION_CMD_IN_ENV is empty in $BOARD_CONFIG" >&2
    exit 1
fi

to_kib() {
    v="$1"
    n="${v%[KkMmGg]}"
    u="${v#$n}"

    case "$u" in
        ""|"K"|"k")
            echo "$n"
            ;;
        "M"|"m")
            echo $((n * 1024))
            ;;
        "G"|"g")
            echo $((n * 1024 * 1024))
            ;;
        *)
            echo "ERROR: Unsupported size unit in '$v'" >&2
            exit 1
            ;;
    esac
}

part_info=""
cursor_kib=0
IFS=,
for part in $PARTITIONS; do
    name=$(echo "$part" | sed -n 's/.*(\([^)]*\)).*/\1/p')
    if [ -z "$name" ]; then
        echo "ERROR: Failed to parse partition name from '$part'" >&2
        exit 1
    fi

    def="${part%%(*}"
    case "$def" in
        *@*)
            size="${def%%@*}"
            offset="${def#*@}"
            offset_kib=$(to_kib "$offset")
            ;;
        *)
            size="$def"
            offset_kib="$cursor_kib"
            ;;
    esac

    size_kib=$(to_kib "$size")
    cursor_kib=$((offset_kib + size_kib))
    part_info="${part_info}${name}:${offset_kib}:${size_kib}
"
done
IFS=' '

get_part_field() {
    p="$1"
    f="$2"
    echo "$part_info" | awk -F: -v part="$p" -v field="$f" '$1 == part { print $field; exit }'
}

require_part() {
    p="$1"
    val=$(get_part_field "$p" 2 || true)
    if [ -z "$val" ]; then
        echo "ERROR: Required partition '$p' not found in $BOARD_CONFIG" >&2
        exit 1
    fi
}

require_part env
require_part idblock
require_part uboot
require_part boot
require_part rootfs

env_offset_kib=$(get_part_field env 2)
env_size_kib=$(get_part_field env 3)
idblock_offset_kib=$(get_part_field idblock 2)
uboot_offset_kib=$(get_part_field uboot 2)
boot_offset_kib=$(get_part_field boot 2)
boot_size_kib=$(get_part_field boot 3)
rootfs_offset_kib=$(get_part_field rootfs 2)

env_offset_blk=$((env_offset_kib * 2))
env_count_blk=$((env_size_kib * 2))
idblock_offset_blk=$((idblock_offset_kib * 2))
uboot_offset_blk=$((uboot_offset_kib * 2))
boot_offset_blk=$((boot_offset_kib * 2))
boot_count_blk=$((boot_size_kib * 2))
rootfs_offset_blk=$((rootfs_offset_kib * 2))

# Keep rootfs/app sizes Nerves-friendly while preserving board-specific offsets.
rootfs_count_blk=$((256 * 1024 * 2))
app_offset_blk=$((rootfs_offset_blk + rootfs_count_blk))
app_count_blk=$((512 * 1024 * 2))

board_name=$(basename "$BOARD_CONFIG" .mk)
mkdir -p "$(dirname "$OUTPUT")"

escape_sed() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

BOARD_CONFIG_ESC=$(escape_sed "$BOARD_CONFIG")
BOARD_NAME_ESC=$(escape_sed "$board_name")

sed \
    -e "s/@@BOARD_CONFIG_PATH@@/$BOARD_CONFIG_ESC/g" \
    -e "s/@@BOARD_NAME@@/$BOARD_NAME_ESC/g" \
    -e "s/@@ENV_OFFSET_BLK@@/$env_offset_blk/g" \
    -e "s/@@ENV_COUNT_BLK@@/$env_count_blk/g" \
    -e "s/@@IDBLOCK_OFFSET_BLK@@/$idblock_offset_blk/g" \
    -e "s/@@UBOOT_OFFSET_BLK@@/$uboot_offset_blk/g" \
    -e "s/@@BOOT_OFFSET_BLK@@/$boot_offset_blk/g" \
    -e "s/@@BOOT_COUNT_BLK@@/$boot_count_blk/g" \
    -e "s/@@ROOTFS_OFFSET_BLK@@/$rootfs_offset_blk/g" \
    -e "s/@@ROOTFS_COUNT_BLK@@/$rootfs_count_blk/g" \
    -e "s/@@APP_OFFSET_BLK@@/$app_offset_blk/g" \
    -e "s/@@APP_COUNT_BLK@@/$app_count_blk/g" \
    "$TEMPLATE" > "$OUTPUT"
