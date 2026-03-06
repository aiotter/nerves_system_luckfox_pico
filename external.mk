define LUCKFOX_FIX_STAGING_USR
	[ -L "$(STAGING_DIR)/lib" ] && rm -f "$(STAGING_DIR)/lib" || true
	[ -L "$(STAGING_DIR)/usr/lib" ] && rm -f "$(STAGING_DIR)/usr/lib" || true
	mkdir -p $(STAGING_DIR)/lib $(STAGING_DIR)/usr/lib
endef
TOOLCHAIN_EXTERNAL_CUSTOM_PRE_INSTALL_STAGING_HOOKS += LUCKFOX_FIX_STAGING_USR

E2FSPROGS_CONF_ENV += PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)"
E2FSPROGS_CONF_ENV += PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig"
E2FSPROGS_CONF_ENV += PKG_CONFIG_PATH="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig"
