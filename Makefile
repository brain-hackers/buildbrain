JOBS=$(shell grep -c '^processor' /proc/cpuinfo)

export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabi-

.PHONY:
setup:
	@echo "Updating submodules"
	@git submodule update --init --recursive
	@echo "Creating venv"
	@python3 -m venv env
	@echo "Installing r3build"
	@. ./env/bin/activate; \
	pip install r3build

.PHONY:
watch:
	@echo "Watching changes in linux-brain and u-boot-brain"
	@. ./env/bin/activate; \
	@python3 -m r3build

.PHONY:
udefconfig:
	make -C ./u-boot-brain mx28evk_defconfig

.PHONY:
usavedefconfig:
	make -C ./u-boot-brain savedefconfig

.PHONY:
umenuconfig:
	make -C ./u-boot-brain menuconfig

.PHONY:
ubuild:
	make -j$(JOBS) -C ./u-boot-brain u-boot.sb

.PHONY:
ldefconfig:
	make -C ./linux-brain mxs_defconfig

.PHONY:
lmenuconfig:
	make -C ./linux-brain menuconfig

.PHONY:
lsavedefconfig:
	make -C ./linux-brain savedefconfig
	cp ./linux-brain/defconfig ./linux-brain/arch/arm/configs/mxs_defconfig

.PHONY:
lbuild:
	make -j$(JOBS) -C ./linux-brain

.PHONY:
uuu:
	sudo uuu ./u-boot-brain/u-boot.sb

debian:
	mkdir debian
	sudo debootstrap --arch=armel --foreign buster debian/
	sudo cp /usr/bin/qemu-arm-static debian/usr/bin/
	sudo cp setup_debian.sh debian/
	sudo chroot debian /setup_debian.sh

