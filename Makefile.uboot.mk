UBOOT_MAKE ?= source $(UBOOT_DIR)/../u-boot-venv/bin/activate; make -C $(UBOOT_DIR) \
	CROSS_COMPILE="aarch64-linux-gnu-"

$(UBOOT_DIR)/.config: $(UBOOT_DIR)/configs/$(UBOOT_DEFCONFIG)
	$(UBOOT_MAKE) $(UBOOT_DEFCONFIG)

ifneq (,$(FORCE))
.PHONY: out/u-boot/idbloader.img
endif
out/u-boot/idbloader.img: $(UBOOT_DIR)/.config $(BL31) u-boot-venv u-boot
	cp -u $(BL31) u-boot/bl31.elf
	$(UBOOT_MAKE) -j $$(nproc)
	$(UBOOT_MAKE) -j $$(nproc) u-boot.itb
	mkdir -p out/u-boot
ifneq (,$(USE_UBOOT_TPL))
	$(UBOOT_DIR)/tools/mkimage -n rk3328 -T rksd -d $(UBOOT_DIR)/tpl/u-boot-tpl.bin $@.tmp
else
	$(UBOOT_DIR)/tools/mkimage -n rk3328 -T rksd -d rkbin/rk33/rk3328_ddr_786MHz_v1.06.bin $@.tmp
endif
	cat $(UBOOT_DIR)/spl/u-boot-spl.bin >> $@.tmp
	dd if=$(UBOOT_DIR)/u-boot.itb of=$@.tmp seek=$$((0x200-64)) conv=notrunc
	mv $@.tmp $@

.PHONY: u-boot-menuconfig		# edit u-boot config and save as defconfig
u-boot-menuconfig: u-boot-venv u-boot
	$(UBOOT_MAKE) ARCH=arm64 $(UBOOT_DEFCONFIG)
	$(UBOOT_MAKE) ARCH=arm64 menuconfig
	$(UBOOT_MAKE) ARCH=arm64 savedefconfig
	cp $(UBOOT_DIR)/defconfig $(UBOOT_DIR)/configs/$(UBOOT_DEFCONFIG)

.PHONY: u-boot-clear
u-boot-clear:
	rm -rf out/u-boot/

.PHONY: u-boot-boot		# boot u-boot over USB
u-boot-boot: out/u-boot/idbloader.img
	rkdeveloptool db rkbin/rk33/rk3328_loader_v1.08.244_for_spi_nor_build_Aug_7_2017.bin
	sleep 1s
	rkdeveloptool rid
	rkdeveloptool wl 512 $(UBOOT_DIR)/u-boot.itb
	rkdeveloptool rd
	sleep 1s

	cat rkbin/rk33/rk3328_ddr_786MHz_v1.06.bin | openssl rc4 -K 7c4e0304550509072d2c7b38170d1711 | rkflashtool l
	cat u-boot/spl/u-boot-spl.bin | openssl rc4 -K 7c4e0304550509072d2c7b38170d1711 | rkflashtool L

.PHONY: u-boot-flash-spi		# flash u-boot to SPI
u-boot-flash-spi: out/u-boot/idbloader.img
	rkdeveloptool db rkbin/rk33/rk3328_loader_v1.08.244_for_spi_nor_build_Aug_7_2017.bin
	sleep 1s
	rkdeveloptool rid
	rkdeveloptool wl 64 $<
	rkdeveloptool rd

.PHONY: u-boot-clear-spi		# clear u-boot to SPI
u-boot-clear-spi: out/u-boot/idbloader.img
	rkdeveloptool db rkbin/rk33/rk3328_loader_v1.08.244_for_spi_nor_build_Aug_7_2017.bin
	sleep 1s
	rkdeveloptool rid
	rkdeveloptool wl 64 $<
	rkdeveloptool rd

.PHONY: u-boot-build		# compile u-boot
u-boot-build: out/u-boot/idbloader.img
