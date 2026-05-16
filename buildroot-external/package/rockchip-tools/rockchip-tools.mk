################################################################################
#
# Rockchip tools
#
################################################################################

###################################################

ROCKCHIP_TOOLS_VERSION = c6a1db07470693d358b8d6711d2c92fe56cb2cdd
ROCKCHIP_TOOLS_SITE = https://github.com/Firefly-rk-linux/tools
ROCKCHIP_TOOLS_SITE_METHOD = git
ROCKCHIP_TOOLS_DL_OPTS = --depth 1
ROCKCHIP_TOOLS_LICENSE = PROPRIETARY

define HOST_ROCKCHIP_TOOLS_INSTALL_CMDS
	$(INSTALL) -D -m 0777 $(@D)/linux/Linux_Pack_Firmware/rockdev/afptool $(HOST_DIR)/bin
	$(INSTALL) -D -m 0777 $(@D)/linux/Linux_Pack_Firmware/rockdev/rkImageMaker $(HOST_DIR)/bin
endef

$(eval $(host-generic-package))
