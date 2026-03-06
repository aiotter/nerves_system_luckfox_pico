FROM luckfoxtech/luckfox_pico:1.0

ARG LUCKFOX_SDK_GIT_URL=https://github.com/LuckfoxTECH/luckfox-pico.git
ARG LUCKFOX_SDK_GIT_REF=994243753789e1b40ef91122e8b3688aae8f01b8
ARG LUCKFOX_BOARD=RV1106_Luckfox_Pico_Pro_Max

WORKDIR /home

RUN bash -eux <<EOF
  git init .
  git remote add origin "$LUCKFOX_SDK_GIT_URL"
  git fetch --depth=1 origin "$LUCKFOX_SDK_GIT_REF"
  git checkout --detach FETCH_HEAD
EOF

ENV LUCKFOX_BOARD_CONFIG_PATH=project/cfg/BoardConfig_IPC/BoardConfig-SD_CARD-Buildroot-${LUCKFOX_BOARD}-IPC.mk

RUN bash -eux <<EOF
  ln -s "$LUCKFOX_BOARD_CONFIG_PATH" .BoardConfig.mk

  ./build.sh uboot

  if [ ! -f output/image/idblock.img ] && [ -f output/image/MiniLoaderAll.bin ]; then
    cp -f output/image/MiniLoaderAll.bin output/image/idblock.img
  fi

  mkdir /out
  cp output/image/idblock.img /out/idblock.img
  cp output/image/uboot.img /out/uboot.img
  cp "$LUCKFOX_BOARD_CONFIG_PATH" /out/BoardConfig.mk
EOF
