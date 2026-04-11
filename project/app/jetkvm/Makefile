
ifeq ($(APP_PARAM), )
    APP_PARAM:=../Makefile.param
    include $(APP_PARAM)
endif

export LC_ALL=C
SHELL:=/bin/bash

CURRENT_DIR := $(shell pwd)

PKG_NAME := jetkvm
PKG_BIN ?= out
PKG_BUILD ?= build

ifeq ($(PKG_BIN),)
$(error ### $(CURRENT_DIR): PKG_BIN is NULL, Please Check !!!)
endif

ifeq ($(RK_APP_TYPE),JETKVM)
    PKG_TARGET := jetkvm-build
endif

all: $(PKG_TARGET) thirdlibs-build
	@echo "build $(PKG_NAME) done"

thirdlibs-build:
	@test ! -d $(RK_APP_COMPONENT)/third_libs || make -C $(RK_APP_COMPONENT)/third_libs

jetkvm-build: 
	mkdir -p $(PKG_BIN)/bin $(PKG_BIN)/share $(PKG_BIN)/install_to_userdata $(PKG_BIN)/root/etc/init.d
	cp $(CURRENT_DIR)/jetkvm-lib.sh $(PKG_BIN)/share/jetkvm-lib.sh
	cp $(CURRENT_DIR)/RkLunch.sh $(PKG_BIN)/bin/RkLunch.sh
	cp $(CURRENT_DIR)/RkLunch-stop.sh $(PKG_BIN)/bin/RkLunch-stop.sh
	cp $(CURRENT_DIR)/dropbear.sh $(PKG_BIN)/bin/dropbear.sh
	cp $(CURRENT_DIR)/fb_init $(PKG_BIN)/share/fb_init
	cp -rfa $(CURRENT_DIR)/jetkvm $(PKG_BIN)/install_to_userdata
	cp $(CURRENT_DIR)/network_led.sh $(PKG_BIN)/install_to_userdata/network_led.sh
	chmod +x $(PKG_BIN)/install_to_userdata/network_led.sh
	cp $(CURRENT_DIR)/S90network_led $(PKG_BIN)/root/etc/init.d/S90network_led
	chmod 775 $(PKG_BIN)/root/etc/init.d/S90network_led
	mkdir -p $(PKG_BIN)/install_to_userdata/tailscale
	cp $(CURRENT_DIR)/tailscale $(PKG_BIN)/install_to_userdata/tailscale/tailscale
	cp $(CURRENT_DIR)/tailscaled $(PKG_BIN)/install_to_userdata/tailscale/tailscaled
	chmod +x $(PKG_BIN)/install_to_userdata/tailscale/tailscale
	chmod +x $(PKG_BIN)/install_to_userdata/tailscale/tailscaled
	cp $(CURRENT_DIR)/S99tailscaled $(PKG_BIN)/root/etc/init.d/S99tailscaled
	chmod 775 $(PKG_BIN)/root/etc/init.d/S99tailscaled
	$(call MAROC_COPY_PKG_TO_APP_OUTPUT, $(RK_APP_OUTPUT), $(PKG_BIN))

clean:
	@rm -rf $(PKG_BIN) $(PKG_BUILD)

distclean: clean
