FROM luckfoxtech/luckfox_pico:1.0

ARG LUCKFOX_SDK_GIT_URL=https://github.com/LuckfoxTECH/luckfox-pico.git
ARG LUCKFOX_SDK_GIT_REF=994243753789e1b40ef91122e8b3688aae8f01b8
ARG LUCKFOX_BOARD=RV1103_Luckfox_Pico_Mini

WORKDIR /home

RUN bash -eux <<'EOF'
  git init .
  git remote add origin "$LUCKFOX_SDK_GIT_URL"
  git fetch --depth=1 origin "$LUCKFOX_SDK_GIT_REF"
  git checkout --detach FETCH_HEAD
EOF

COPY docker/ /tmp/docker/

RUN bash -eux <<'EOF'
  git apply /tmp/docker/luckfox_pico_uboot_env_bootcmd.patch

  BOARD_CONFIG_PATH=project/cfg/BoardConfig_IPC/BoardConfig-SD_CARD-Buildroot-${LUCKFOX_BOARD}-IPC.mk
  ln -s "$BOARD_CONFIG_PATH" .BoardConfig.mk
  cp /tmp/docker/luckfox_pico_nerves.config sysdrv/source/uboot/u-boot/configs/luckfox_pico_nerves.config
  echo 'export RK_UBOOT_DEFCONFIG_FRAGMENT="${RK_UBOOT_DEFCONFIG_FRAGMENT} luckfox_pico_nerves.config"' >> .BoardConfig.mk

  source ./.BoardConfig.mk
  if [ -z "${RK_KERNEL_DEFCONFIG:-}" ]; then
    echo "ERROR: RK_KERNEL_DEFCONFIG is not set in .BoardConfig.mk"
    exit 1
  fi
  KERNEL_DEFCONFIG="sysdrv/source/kernel/arch/arm/configs/${RK_KERNEL_DEFCONFIG}"
  if [ ! -f "$KERNEL_DEFCONFIG" ]; then
    echo "ERROR: kernel defconfig not found: $KERNEL_DEFCONFIG"
    exit 1
  fi
  grep -Ev '^(CONFIG_CMA=|CONFIG_DMA_CMA=|CONFIG_CMA_INACTIVE=|CONFIG_RK_CMA_PROCFS=|CONFIG_DMABUF_HEAPS_ROCKCHIP_CMA_HEAP=|CONFIG_VIDEOBUF2_CMA_SG=|CONFIG_ROCKCHIP_RKNPU_DMA_HEAP=|CONFIG_CMA_SIZE_MBYTES=|# CONFIG_CMA is not set|# CONFIG_DMA_CMA is not set|# CONFIG_CMA_INACTIVE is not set|# CONFIG_RK_CMA_PROCFS is not set|# CONFIG_DMABUF_HEAPS_ROCKCHIP_CMA_HEAP is not set|# CONFIG_VIDEOBUF2_CMA_SG is not set|# CONFIG_ROCKCHIP_RKNPU_DMA_HEAP is not set)$' \
    "$KERNEL_DEFCONFIG" > /tmp/luckfox_kernel_defconfig
  cat /tmp/docker/luckfox_pico_nerves_kernel.fragment >> /tmp/luckfox_kernel_defconfig
  mv /tmp/luckfox_kernel_defconfig "$KERNEL_DEFCONFIG"
EOF

RUN ./build.sh uboot
RUN ./build.sh kernel

RUN bash -eux <<'EOF'
  source .BoardConfig.mk
  KERNEL_DTB_NAME="${RK_KERNEL_DTS%.dts}.dtb"
  KERNEL_DTB_SRC=$(find output -type f -name "$KERNEL_DTB_NAME" | head -n1 || true)
  if [ -z "$KERNEL_DTB_SRC" ] || [ ! -f "$KERNEL_DTB_SRC" ]; then
    echo "ERROR: kernel DTB not found after build: $KERNEL_DTB_NAME"
    exit 1
  fi
  KERNEL_ZIMAGE_SRC="sysdrv/source/objs_kernel/arch/arm/boot/zImage"
  if [ ! -f "$KERNEL_ZIMAGE_SRC" ]; then
    KERNEL_ZIMAGE_SRC="output/out/ramdisk/zImage"
  fi
  if [ ! -f "$KERNEL_ZIMAGE_SRC" ]; then
    KERNEL_ZIMAGE_SRC=$(find sysdrv/source -type f -path "*/arch/arm/boot/zImage" | head -n1 || true)
  fi
  if [ ! -f "$KERNEL_ZIMAGE_SRC" ]; then
    KERNEL_ZIMAGE_SRC=$(find output -type f -path "*/ramdisk/zImage" | head -n1 || true)
  fi
  if [ -z "$KERNEL_ZIMAGE_SRC" ] || [ ! -f "$KERNEL_ZIMAGE_SRC" ]; then
    echo "ERROR: kernel zImage not found after build"
    exit 1
  fi

  if [ ! -f output/image/idblock.img ] && [ -f output/image/MiniLoaderAll.bin ]; then
    cp -f output/image/MiniLoaderAll.bin output/image/idblock.img
  fi

  USERDATA_PART_SIZE=$(sysdrv/tools/pc/toolkits/get_part_info.sh PART_SIZE "$RK_PARTITION_CMD_IN_ENV" userdata "$RK_BOOT_MEDIUM")
  if [ -z "$USERDATA_PART_SIZE" ] || [ "$USERDATA_PART_SIZE" = "FAIL" ]; then
    echo "ERROR: userdata partition size not found from RK_PARTITION_CMD_IN_ENV=$RK_PARTITION_CMD_IN_ENV"
    exit 1
  fi
  USERDATA_SRC_DIR="output/out/userdata_seed"
  mkdir -p "$USERDATA_SRC_DIR"
  sysdrv/tools/pc/e2fsprogs/mkfs_ext4.sh "$USERDATA_SRC_DIR" output/image/userdata.img "$USERDATA_PART_SIZE"
  if [ ! -f output/image/userdata.img ]; then
    echo "ERROR: userdata.img not found after mkfs_ext4"
    exit 1
  fi

  mkdir /out
  cp output/image/idblock.img /out/idblock.img
  cp output/image/uboot.img /out/uboot.img
  cp "$KERNEL_ZIMAGE_SRC" /out/zImage
  cp "$KERNEL_DTB_SRC" /out/kernel.dtb
  cp output/image/userdata.img /out/userdata.img
  cp .BoardConfig.mk /out/BoardConfig.mk
EOF
