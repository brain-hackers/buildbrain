JOBS=$(shell grep -c '^processor' /proc/cpuinfo)

UBOOT_CROSS=$(shell ./tools/getcross u-boot)
LINUX_CROSS=$(shell ./tools/getcross linux)
export ARCH=arm

.PHONY:
setup:
	@echo "Updating submodules"
	@git submodule update --init --recursive

.PHONY:
setup-dev:
	@echo "Creating venv"
	@python3 -m venv env
	@echo "Installing r3build"
	@. ./env/bin/activate; \
	pip install wheel; \
	pip install r3build

.PHONY:
watch:
	@echo "Watching changes in linux-brain and u-boot-brain"
	@. ./env/bin/activate; \
	@python3 -m r3build

.PHONY:
udefconfig:
	make -C ./u-boot-brain pwsh1_defconfig

.PHONY:
udefconfig-%:
	make -C ./u-boot-brain pw$*_defconfig

.PHONY:
usavedefconfig:
	make CROSS_COMPILE=$(UBOOT_CROSS) -C ./u-boot-brain savedefconfig

.PHONY:
umenuconfig:
	make CROSS_COMPILE=$(UBOOT_CROSS) -C ./u-boot-brain menuconfig

.PHONY:
uclean:
	make -C ./u-boot-brain distclean

.PHONY:
ubuild:
	if [ "$(UBOOT_CROSS)" = "arm-linux-gnueabi-" ]; then \
		make CROSS_COMPILE=$(UBOOT_CROSS) -j$(JOBS) -C ./u-boot-brain u-boot.sb; \
	else \
		make CROSS_COMPILE=$(UBOOT_CROSS) -j$(JOBS) -C ./u-boot-brain u-boot.imx; \
	fi

.PHONY:
ldefconfig:
	make -C ./linux-brain brain_defconfig

.PHONY:
lmenuconfig:
	make CROSS_COMPILE=$(LINUX_CROSS) -C ./linux-brain menuconfig

.PHONY:
lsavedefconfig:
	make CROSS_COMPILE=$(LINUX_CROSS) -C ./linux-brain savedefconfig
	mv ./linux-brain/defconfig ./linux-brain/arch/arm/configs/brain_defconfig

.PHONY:
lclean:
	make -C ./linux-brain distclean

.PHONY:
lbuild:
	make CROSS_COMPILE=$(LINUX_CROSS) -j$(JOBS) -C ./linux-brain

.PHONY:
uuu:
	sudo uuu ./u-boot-brain/u-boot.sb

.PHONY:
nkbin-maker:
	make -C ./nkbin_maker

.PHONY:
nk.bin:
	./nkbin_maker/bsd-ce ./u-boot-brain/u-boot.bin

brainux:
	@if [ "$(shell uname)" != "Linux" ]; then \
		echo "Debootstrap is only available in Linux!"; \
		exit 1; \
	fi
	mkdir -p brainux
	@if [ "$(CI)" = "true" ]; then \
		echo "I'm in CI and debootstrap without cache."; \
		sudo debootstrap --arch=armel --foreign buster brainux/; \
	else \
		sudo debootstrap --arch=armel --foreign buster brainux/ http://localhost:65432/debian/; \
	fi
	sudo cp /usr/bin/qemu-arm-static brainux/usr/bin/
	sudo cp ./os-brainux/setup_brainux.sh brainux/
	sudo -E chroot brainux /setup_brainux.sh
	sudo rm brainux/setup_brainux.sh
	sudo ./os-brainux/override.sh ./os-brainux/override ./brainux

image/sd.img: clean_work
	./image/build_image.sh

.PHONY:
clean_work:
	sudo rm -rf image/work

.PHONY:
aptcache:
	./tools/aptcache_linux_amd64 \
		-rule 'local=localhost:65432, remote=ftp.jaist.ac.jp' \
		-rule 'local=localhost:65433, remote=security.debian.org'
