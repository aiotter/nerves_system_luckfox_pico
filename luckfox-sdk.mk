NERVES_DEFCONFIG_DIR ?= $(CURDIR)
BINARIES_DIR ?=
SDK_GIT_URL ?= https://github.com/LuckfoxTECH/luckfox-pico.git
SDK_GIT_REF ?= $(LUCKFOX_SDK_GIT_REF)
SDK_FALLBACK_DIR ?= /home/nerves/project/luckfox_pico_sdk

-include $(NERVES_DEFCONFIG_DIR)/luckfox-board.mk

SDK_LOCAL_CANDIDATES := \
	$(NERVES_DEFCONFIG_DIR)/../../LuckfoxTECH/luckfox-pico \
	$(NERVES_DEFCONFIG_DIR)/../luckfox_pico_sdk \
	$(NERVES_DEFCONFIG_DIR)/../../luckfox_pico_sdk \
	$(SDK_FALLBACK_DIR)
SDK_CANDIDATES := $(filter-out ,$(SDK_LOCAL_CANDIDATES))
SDK_DIR = $(firstword $(foreach d,$(SDK_CANDIDATES),$(if $(wildcard $(d)/build.sh),$(d),)))

BOARD_CONFIG_REL := $(strip $(LUCKFOX_BOARD_CONFIG_REL))
ifeq ($(BOARD_CONFIG_REL),)
BOARD_CONFIG_REL := project/cfg/BoardConfig_IPC/BoardConfig-SD_CARD-Buildroot-RV1106_Luckfox_Pico_Pro_Max-IPC.mk
endif
BOARD_CONFIG = $(SDK_DIR)/$(BOARD_CONFIG_REL)
SDK_OUTPUT_DIR = $(SDK_DIR)/output/image
IDBLOCK_IMG = $(SDK_OUTPUT_DIR)/idblock.img
UBOOT_IMG = $(SDK_OUTPUT_DIR)/uboot.img
MINILOADER_BIN = $(SDK_OUTPUT_DIR)/MiniLoaderAll.bin
UBOOT_MAKEFILE = $(SDK_DIR)/sysdrv/source/uboot/u-boot/Makefile
FIT_CORE_SCRIPT = $(SDK_DIR)/sysdrv/source/uboot/u-boot/scripts/fit-core.sh
GEN_FWUP_SCRIPT := $(NERVES_DEFCONFIG_DIR)/scripts/gen-fwup-conf.sh
GENERATED_FWUP := $(NERVES_DEFCONFIG_DIR)/.nerves/fwup.conf
FALLBACK_HOST_CROSS ?= armv7-nerves-linux-gnueabihf
FALLBACK_GCC_EXTRA_FLAGS ?= -Wno-error -Wno-error=maybe-uninitialized -Wno-error=address -Wno-error=enum-int-mismatch

.PHONY: fetch-sdk ensure-sdk-toolchain ensure-blobs export-blobs generate-fwup prepare-assets

fetch-sdk:
	@sdk_dir=""; \
	for d in $(SDK_CANDIDATES); do \
		if [ -f "$$d/build.sh" ]; then \
			sdk_dir="$$d"; \
			break; \
		fi; \
	done; \
	if [ -z "$$sdk_dir" ]; then \
		echo "Luckfox SDK not found locally."; \
		echo "Cloning SDK to: $(SDK_FALLBACK_DIR)"; \
		if [ -e "$(SDK_FALLBACK_DIR)" ] && [ ! -d "$(SDK_FALLBACK_DIR)/.git" ]; then \
			echo "ERROR: fallback path exists but is not a git repository: $(SDK_FALLBACK_DIR)"; \
			exit 1; \
		fi; \
		if [ ! -d "$(SDK_FALLBACK_DIR)/.git" ]; then \
			git clone --depth=1 "$(SDK_GIT_URL)" "$(SDK_FALLBACK_DIR)"; \
		fi; \
		sdk_dir="$(SDK_FALLBACK_DIR)"; \
	fi; \
	if [ -n "$(SDK_GIT_REF)" ] && [ "$$sdk_dir" = "$(SDK_FALLBACK_DIR)" ] && [ -d "$(SDK_FALLBACK_DIR)/.git" ]; then \
		echo "Using SDK commit: $(SDK_GIT_REF)"; \
		cd "$(SDK_FALLBACK_DIR)" && git fetch --depth=1 origin "$(SDK_GIT_REF)" && git checkout -q FETCH_HEAD; \
	fi; \
	test -f "$$sdk_dir/build.sh" || { \
		echo "ERROR: luckfox_pico_sdk dependency not found."; \
		echo "Expected one of:"; \
		$(foreach d,$(SDK_CANDIDATES),echo "  - $(d)";) \
		exit 1; \
	}; \
	echo "Using Luckfox SDK: $$sdk_dir"

ensure-sdk-toolchain: fetch-sdk
	@test -n "$(SDK_DIR)" || { \
		echo "ERROR: luckfox_pico_sdk not found after fetch."; \
		exit 1; \
	}
	@test -f "$(BOARD_CONFIG)" || { \
		echo "ERROR: Board config not found: $(BOARD_CONFIG)"; \
		exit 1; \
	}
	@toolchain_prefix="$$(awk -F= '/^[[:space:]]*export[[:space:]]+RK_TOOLCHAIN_CROSS=/{gsub(/[[:space:]]/, "", $$2); print $$2; exit}' "$(BOARD_CONFIG)")"; \
	if [ -z "$$toolchain_prefix" ]; then \
		toolchain_prefix="arm-rockchip830-linux-uclibcgnueabihf"; \
	fi; \
	toolchain_bin_dir="$(SDK_DIR)/tools/linux/toolchain/$$toolchain_prefix/bin"; \
	toolchain_gcc="$$toolchain_bin_dir/$${toolchain_prefix}-gcc"; \
	if "$$toolchain_gcc" --version >/dev/null 2>&1; then \
		echo "Using SDK toolchain: $$toolchain_prefix"; \
	elif [ -n "$(HOST_DIR)" ] && [ -x "$(HOST_DIR)/bin/$(FALLBACK_HOST_CROSS)-gcc" ]; then \
		echo "SDK toolchain '$$toolchain_prefix' is unavailable. Falling back to $(FALLBACK_HOST_CROSS)."; \
		mkdir -p "$$toolchain_bin_dir"; \
		src_gcc="$(HOST_DIR)/bin/$(FALLBACK_HOST_CROSS)-gcc"; \
		if [ ! -x "$$src_gcc" ]; then \
			echo "ERROR: fallback gcc not executable: $$src_gcc"; \
			exit 1; \
		fi; \
			for tool in gcc g++ cpp ar as ld nm objcopy objdump ranlib readelf size strip strings; do \
				src="$(HOST_DIR)/bin/$(FALLBACK_HOST_CROSS)-$$tool"; \
				dst="$$toolchain_bin_dir/$${toolchain_prefix}-$$tool"; \
				if [ -x "$$src" ]; then \
					rm -f "$$dst"; \
					case "$$tool" in \
						gcc|g++|cpp) \
							printf '%s\n' '#!/bin/sh' "exec \"$$src\" \"\$$@\" $(FALLBACK_GCC_EXTRA_FLAGS)" > "$$dst"; \
							;; \
						*) \
							printf '%s\n' '#!/bin/sh' "exec \"$$src\" \"\$$@\"" > "$$dst"; \
							;; \
					esac; \
					chmod +x "$$dst"; \
				fi; \
			done; \
		"$$toolchain_gcc" --version >/dev/null 2>&1 || { \
			echo "ERROR: fallback toolchain setup failed: $$toolchain_gcc"; \
			exit 1; \
		}; \
	else \
		echo "ERROR: SDK toolchain '$$toolchain_prefix' is unavailable."; \
		echo "Expected: $$toolchain_gcc"; \
		echo "Fallback missing: $(HOST_DIR)/bin/$(FALLBACK_HOST_CROSS)-gcc"; \
		exit 1; \
	fi

ensure-blobs: ensure-sdk-toolchain
	@test -n "$(SDK_DIR)" || { \
		echo "ERROR: luckfox_pico_sdk not found after fetch."; \
		exit 1; \
	}
	@test -f "$(BOARD_CONFIG)" || { \
		echo "ERROR: Board config not found: $(BOARD_CONFIG)"; \
		exit 1; \
	}
	@if [ -f "$(UBOOT_MAKEFILE)" ]; then \
		if grep -q -- "-fshort-wchar -Werror" "$(UBOOT_MAKEFILE)"; then \
			tmp_makefile="$(UBOOT_MAKEFILE).nerves.tmp"; \
			sed 's/-fshort-wchar -Werror/-fshort-wchar -Wno-error/g' "$(UBOOT_MAKEFILE)" > "$$tmp_makefile"; \
			mv "$$tmp_makefile" "$(UBOOT_MAKEFILE)"; \
			echo "Patched U-Boot Makefile: disabled -Werror"; \
		fi; \
	fi
	@if [ ! -f "$(IDBLOCK_IMG)" ] || [ ! -f "$(UBOOT_IMG)" ]; then \
		echo "Building Luckfox U-Boot blobs (first time only)..."; \
		if [ -f "$(FIT_CORE_SCRIPT)" ]; then \
			if grep -q 'VERSION=`fdtget -ti $${ITB_UBOOT} / version`' "$(FIT_CORE_SCRIPT)"; then \
				tmp_fitcore="$(FIT_CORE_SCRIPT).nerves.tmp"; \
				sed \
					-e 's/VERSION=`fdtget -ti $${ITB_UBOOT} \/ version`/VERSION=`fdtget -ti $${ITB_UBOOT} \/ version 2>\/dev\/null || true`/g' \
					-e 's/VERSION=`fdtget -ti $${ITB_BOOT} \/ version`/VERSION=`fdtget -ti $${ITB_BOOT} \/ version 2>\/dev\/null || true`/g' \
					-e 's/VERSION=`fdtget -ti $${ITB_RECOVERY} \/ version`/VERSION=`fdtget -ti $${ITB_RECOVERY} \/ version 2>\/dev\/null || true`/g' \
					"$(FIT_CORE_SCRIPT)" > "$$tmp_fitcore"; \
				mv "$$tmp_fitcore" "$(FIT_CORE_SCRIPT)"; \
				echo "Patched fit-core.sh: tolerate missing fdtget"; \
			fi; \
		fi; \
		extra_path="$(SDK_DIR)/sysdrv/source/uboot/u-boot/scripts/dtc:$(HOST_DIR)/bin"; \
		echo "Using tool PATH prefix: $$extra_path"; \
		ln -sf "$(BOARD_CONFIG)" "$(SDK_DIR)/.BoardConfig.mk"; \
		cd "$(SDK_DIR)" && PATH="$$extra_path:$$PATH" ./build.sh uboot; \
		if [ ! -f "$(IDBLOCK_IMG)" ] && [ -f "$(MINILOADER_BIN)" ]; then \
			cp -f "$(MINILOADER_BIN)" "$(IDBLOCK_IMG)"; \
		fi; \
	fi
	@test -f "$(IDBLOCK_IMG)" || { \
		echo "ERROR: idblock image not found after build: $(IDBLOCK_IMG)"; \
		exit 1; \
	}
	@test -f "$(UBOOT_IMG)" || { \
		echo "ERROR: uboot image not found after build: $(UBOOT_IMG)"; \
		exit 1; \
	}

export-blobs: ensure-blobs
	@test -n "$(BINARIES_DIR)" || { \
		echo "ERROR: BINARIES_DIR is empty"; \
		exit 1; \
	}
	cp -f "$(IDBLOCK_IMG)" "$(BINARIES_DIR)/idblock.img"
	cp -f "$(UBOOT_IMG)" "$(BINARIES_DIR)/uboot.img"

generate-fwup: fetch-sdk
	@test -n "$(SDK_DIR)" || { \
		echo "ERROR: luckfox_pico_sdk not found after fetch."; \
		exit 1; \
	}
	@test -f "$(BOARD_CONFIG)" || { \
		echo "ERROR: Board config not found: $(BOARD_CONFIG)"; \
		exit 1; \
	}
	@test -n "$(BINARIES_DIR)" || { \
		echo "ERROR: BINARIES_DIR is empty"; \
		exit 1; \
	}
	mkdir -p "$(dir $(GENERATED_FWUP))"
	@test -x "$(GEN_FWUP_SCRIPT)" || { \
		echo "ERROR: generator script is not executable: $(GEN_FWUP_SCRIPT)"; \
		exit 1; \
	}
	"$(GEN_FWUP_SCRIPT)" "$(BOARD_CONFIG)" "$(GENERATED_FWUP)"

prepare-assets: export-blobs generate-fwup
