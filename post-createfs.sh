#!/bin/sh

set -e

FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/.nerves/fwup.conf
if [ ! -f "$FWUP_CONFIG" ]; then
    echo "ERROR: generated fwup.conf not found: $FWUP_CONFIG"
    echo "Run post-build asset preparation first."
    exit 1
fi

# Run the common post-image processing for nerves
$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh $TARGET_DIR $FWUP_CONFIG
