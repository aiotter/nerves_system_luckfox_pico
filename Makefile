SHELL := bash

PREBUILT_DIR := .nerves/luckfox_prebuilt
PREBUILT_FILES := idblock.img uboot.img zImage kernel.dtb userdata.img BoardConfig.mk
PREBUILT_TARGETS := $(addprefix $(PREBUILT_DIR)/,$(PREBUILT_FILES))
PREBUILT_ARCHIVE := .nerves/out-$(LUCKFOX_BOARD)-$(LUCKFOX_SDK_GIT_REF).tar

.PHONY: all
all: $(PREBUILT_TARGETS)

$(PREBUILT_TARGETS): $(PREBUILT_ARCHIVE)
	mkdir -p "$(dir $@)"
	tar -xf "$<" -C "$(dir $@)" "$(notdir $@)" || { rm -f "$@"; exit 1; }

$(PREBUILT_ARCHIVE): VERSION $(wildcard docker/*)
	@test -n "$(LUCKFOX_BOARD)" || { echo "LUCKFOX_BOARD is required"; exit 1; }
	@test -n "$(LUCKFOX_SDK_GIT_REF)" || { echo "LUCKFOX_SDK_GIT_REF is required"; exit 1; }
	mkdir -p "$(dir $@)"
	@set -eu; \
	board="$(LUCKFOX_BOARD)"; \
	image_tag="nerves_system_luckfox_pico-$${board,,}:$$(cat VERSION)-$(LUCKFOX_SDK_GIT_REF)"; \
	docker build --platform "linux/amd64" --file docker/Dockerfile --tag "$$image_tag" \
	  --build-arg "LUCKFOX_BOARD=$(LUCKFOX_BOARD)" \
	  --build-arg "LUCKFOX_SDK_GIT_REF=$(LUCKFOX_SDK_GIT_REF)" .; \
	container_id="$$(docker create --platform "linux/amd64" "$$image_tag")"; \
	trap 'docker rm -f "$$container_id" >/dev/null 2>&1 || true' EXIT INT TERM; \
	docker cp "$$container_id:/out.tar" "$@"
