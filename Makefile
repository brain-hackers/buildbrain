JOBS=$(shell grep -c '^processor' /proc/cpuinfo)

UBOOT_CROSS=$(shell ./tools/getcross u-boot)
LINUX_CROSS=$(shell ./tools/getcross linux)
ROOTFS_CROSS=$(shell ./tools/getcross rootfs)
export ARCH=arm

DOCKER_IMAGE := buildbrain-builder:local
ROOTFS_VOLUME := buildbrain-brainux-rootfs
# Separate, leaner image for Buildroot.  Based on debian:bookworm (GCC 12)
# which is compatible with the 2023.05-era Buildroot fork without any patches.
BUILDROOT_DOCKER_IMAGE := buildbrain-buildroot:local
ROOTFS_VOLUME     := buildbrain-brainux-rootfs
BUILDROOT_VOLUME  := buildbrain-buildroot-rootfs
BUILDROOT_OUTPUT_VOLUME := buildbrain-buildroot-output

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
ldefconfig-x1:
	make -C ./linux-brain imx_v7_defconfig

.PHONY:
lmenuconfig:
	make CROSS_COMPILE=$(LINUX_CROSS) -C ./linux-brain menuconfig

.PHONY:
lsavedefconfig:
	make CROSS_COMPILE=$(LINUX_CROSS) -C ./linux-brain savedefconfig
	mv ./linux-brain/defconfig ./linux-brain/arch/arm/configs/brain_defconfig

.PHONY:
lsavedefconfig-x1:
	make CROSS_COMPILE=$(LINUX_CROSS) -C ./linux-brain savedefconfig
	mv ./linux-brain/defconfig ./linux-brain/arch/arm/configs/imx_v7_defconfig

.PHONY:
lclean:
	make -C ./linux-brain distclean

.PHONY:
lbuild:
	make CROSS_COMPILE=$(LINUX_CROSS) -j$(JOBS) -C ./linux-brain

.PHONY:
ldebpkg:
	$(MAKE) ldebpkg-build || $(MAKE) ldebpkg-clean
	mkdir -p debian
	mv linux-*.buildinfo debian/
	mv linux-*.changes debian/
	mv linux-*.diff.gz debian/
	mv linux-*.dsc debian/
	mv linux-*.orig.tar.gz debian/
	mv linux-*.deb debian/

.PHONY:
ldebpkg-build:
	make -j$(JOBS) -C ./linux-brain deb-pkg

.PHONY:
ldebpkg-clean:
	rm -f linux-*.buildinfo
	rm -f linux-*.changes
	rm -f linux-*.diff.gz
	rm -f linux-*.dsc
	rm -f linux-*.orig.tar.gz
	rm -f linux-*.deb

.PHONY:
uuu:
	sudo uuu ./u-boot-brain/u-boot.sb

.PHONY:
nkbin-maker:
	make -C ./nkbin_maker

.PHONY:
nk.bin:
	./nkbin_maker/bsd-ce ./u-boot-brain/u-boot.bin

.PHONY:
boot4ubuild:
	make -C ./boot4u

.PHONY:
boot4uclean:
	make -C ./boot4u clean

.PHONY:
lilobuild:
	make -C ./brainlilo

.PHONY:
liloclean:
	make -C ./brainlilo clean

.PHONY: brainux brainux-umount-special brainux-clean buildroot_rootfs
brainux: 
	@if [ "$(shell uname)" != "Linux" ]; then \
		echo "Debootstrap is only available in Linux!"; \
		exit 1; \
	fi
	mkdir -p brainux
	@if [ "$(CI)" = "true" ]; then \
		echo "I'm in CI and debootstrap without cache."; \
		sudo debootstrap --arch=$(ROOTFS_CROSS) --foreign trixie brainux/; \
	else \
		sudo debootstrap --arch=$(ROOTFS_CROSS) --foreign trixie brainux/ http://localhost:65432/debian/; \
	fi

	# Keep the mounting commands AFTER the first stage of debootstrap, because
	# debootstrap's cleanup code/trap tries to clean up the target directory
	# (`rm -rf /work/brainux/proc`) and fails because proc virtual files can't be removed.
	sudo mkdir -p brainux/proc brainux/sys
	sudo mount -t proc none $(shell pwd)/brainux/proc
	sudo mount --rbind /sys $(shell pwd)/brainux/sys

	sudo cp /usr/bin/qemu-arm-static brainux/usr/bin/
	sudo cp ./os-brainux/setup_brainux.sh brainux/
	sudo ./os-brainux/override-pre.sh ./os-brainux/override ./brainux
	# Register qemu-arm-static binfmt handler if not already present.
	sudo bash -c 'mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc 2>/dev/null; test -e /proc/sys/fs/binfmt_misc/qemu-arm || echo ":qemu-arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:F" > /proc/sys/fs/binfmt_misc/register'
	# Allow qemu-arm-static to reserve the guest address space at low virtual
	# addresses (0x1000).  On Linux hosts vm.mmap_min_addr defaults to 65536
	# which blocks the reservation, causing armel binaries like sqv (apt's
	# OpenPGP verifier) to fail.  This requires --privileged in Docker.
	sudo sh -c 'echo 0 > /proc/sys/vm/mmap_min_addr'
	sudo -E chroot brainux /setup_brainux.sh
	sudo rm brainux/setup_brainux.sh
	sudo ./os-brainux/override.sh ./os-brainux/override ./brainux

brainux-umount-special:
	sudo umount $(shell pwd)/brainux/proc || true
	sudo umount -l $(shell pwd)/brainux/sys || true
	sudo rm -rf brainux/proc brainux/sys

brainux-clean: brainux-umount-special
	sudo rm -rf brainux

buildroot_rootfs:
	make -C buildroot O=/work/buildroot_output brain_imx28_defconfig
	make -C buildroot O=/work/buildroot_output
	mkdir -p buildroot_rootfs
	tar -C ./buildroot_rootfs -xf buildroot_output/images/rootfs.tar

image/sd.img: clean_work
	./image/build_image.sh brainux sd.img 3072

image/sd_x1.img: clean_work
	./image/build_image_x1.sh brainux sd_x1.img 3072

image/sd_buildroot.img: clean_work
	./image/build_image.sh buildroot_rootfs sd_buildroot.img 128


.PHONY:
clean_work:
	sudo rm -rf image/work

.PHONY:
aptcache:
	./tools/aptcache_linux_amd64 \
		-rule 'local=localhost:65432, remote=ftp.riken.jp, root=/Linux/debian' \
		-rule 'local=localhost:65433, remote=security.debian.org'

.PHONY:
datetag:
	git tag $(shell ./tools/version)

.PHONY:
docker-build:
	docker build --platform linux/amd64 -t $(DOCKER_IMAGE) -f Dockerfile .

.PHONY:
docker-buildroot-build:
	docker build --platform linux/amd64 -t $(BUILDROOT_DOCKER_IMAGE) -f Dockerfile.buildroot .

.PHONY:
docker-uboot:
	docker run --rm --platform linux/amd64 -v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make udefconfig-sh1 && make ubuild"

.PHONY:
docker-kernel:
	docker run --rm --platform linux/amd64 -v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make lclean; make ldefconfig && make lbuild"

.PHONY:
docker-rootfs: docker-volume-rm docker-volume-create
	docker run --rm --platform linux/amd64 --privileged -e CI=true \
		-v $(ROOTFS_VOLUME):/work/brainux \
		-v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make brainux"

.PHONY:
docker-sd-image:
	docker run --rm --platform linux/amd64 --privileged \
		-v $(ROOTFS_VOLUME):/work/brainux \
		-v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make -C nkbin_maker clean all && make IMG_BUILD_JOBS=1 image/sd.img"

.PHONY:
docker-sd-image-full: docker-kernel docker-rootfs docker-sd-image

.PHONY:
docker-volume-create:
	docker volume create $(ROOTFS_VOLUME)

.PHONY:
docker-volume-rm:
	docker volume rm $(ROOTFS_VOLUME) 2>/dev/null || true

.PHONY:
docker-buildroot-rootfs: docker-buildroot-volume-rm docker-buildroot-volume-create docker-buildroot-output-volume-create
	docker run --rm --platform linux/amd64 --privileged \
		-v $(BUILDROOT_OUTPUT_VOLUME):/work/buildroot_output \
		-v $(BUILDROOT_VOLUME):/work/buildroot_rootfs \
		-v "$$PWD":/work -w /work $(BUILDROOT_DOCKER_IMAGE) \
		bash -lc "make buildroot_rootfs"

.PHONY:
docker-buildroot-menuconfig:
	docker run --rm -it --platform linux/amd64 \
		-v "$$PWD":/work -w /work $(BUILDROOT_DOCKER_IMAGE) \
		bash -lc "rm -rf buildroot/output/build/buildroot-config && make -C buildroot brain_imx28_defconfig && make -C buildroot menuconfig"

# Run after docker-buildroot-menuconfig to persist customisations.
.PHONY:
docker-buildroot-savedefconfig:
	docker run --rm --platform linux/amd64 \
		-v "$$PWD":/work -w /work $(BUILDROOT_DOCKER_IMAGE) \
		bash -lc "rm -rf buildroot/output/build/buildroot-config && make -C buildroot savedefconfig BR2_DEFCONFIG=configs/brain_imx28_defconfig"

.PHONY:
docker-buildroot-sd-image:
	docker run --rm --platform linux/amd64 --privileged \
		-v $(BUILDROOT_VOLUME):/work/buildroot_rootfs \
		-v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make -C nkbin_maker clean all && make IMG_BUILD_JOBS=1 image/sd_buildroot.img"

# Fast rootfs-only update: replace only the ext4 partition (p2) in an existing
# sd_buildroot.img without rebuilding U-Boot (saves ~35 min per iteration).
# Requires image/sd_buildroot.img to already exist from a prior full build.
# Workflow for overlay-only changes:
#   1. Edit files under os-buildroot/override/
#   2. make docker-buildroot-rootfs        (~1 min)
#   3. make docker-buildroot-patch-image   (~1 min)
#   4. Flash image/sd_buildroot.img
.PHONY:
docker-buildroot-patch-image:
	docker run --rm --platform linux/amd64 --privileged \
		-v $(BUILDROOT_VOLUME):/work/buildroot_rootfs \
		-v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "set -e; \
		  KPARTX_OUTPUT=\$$(kpartx -av image/sd_buildroot.img); \
		  echo \"\$${KPARTX_OUTPUT}\"; \
		  LONAME=\$$(echo \"\$${KPARTX_OUTPUT}\" | sed -n 's/^add map \(loop[0-9]\+\)p2.*/\1/p' | head -1); \
		  if [ -z \"\$${LONAME}\" ]; then echo 'Failed to detect loop device from kpartx output'; exit 1; fi; \
		  mkdir -p /mnt/brainp2; \
		  mount /dev/mapper/\$${LONAME}p2 /mnt/brainp2; \
		  echo 'Wiping old rootfs...'; \
		  rm -rf /mnt/brainp2/*; \
		  echo 'Copying new rootfs...'; \
		  cp -a buildroot_rootfs/. /mnt/brainp2/; \
		  sync; \
		  umount /mnt/brainp2; \
		  kpartx -d image/sd_buildroot.img; \
		  echo 'Done. Rootfs partition updated.'"

# Fast kernel-only update: replace only boot partition (p1) kernel artifacts
# in an existing sd_buildroot.img, without rebuilding rootfs or repacking image.
# Requires image/sd_buildroot.img to already exist.
# Workflow for kernel-only changes:
#   1. make docker-kernel
#   2. make docker-buildroot-patch-kernel-image
#   3. Flash image/sd_buildroot.img
.PHONY:
docker-buildroot-patch-kernel-image:
	docker run --rm --platform linux/amd64 --privileged \
		-v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "set -e; \
		  KPARTX_OUTPUT=\$$(kpartx -av image/sd_buildroot.img); \
		  echo \"\$${KPARTX_OUTPUT}\"; \
		  LONAME=\$$(echo \"\$${KPARTX_OUTPUT}\" | sed -n 's/^add map \(loop[0-9]\+\)p1.*/\1/p' | head -1); \
		  if [ -z \"\$${LONAME}\" ]; then echo 'Failed to detect loop device from kpartx output'; exit 1; fi; \
		  mkdir -p /mnt/brainp1; \
		  mount -o utf8=true /dev/mapper/\$${LONAME}p1 /mnt/brainp1; \
		  echo 'Updating kernel artifacts on boot partition...'; \
		  cp -f linux-brain/arch/arm/boot/zImage /mnt/brainp1/; \
		  cp -f linux-brain/arch/arm/boot/dts/imx28-pw*.dtb /mnt/brainp1/; \
		  sync; \
		  umount /mnt/brainp1; \
		  kpartx -d image/sd_buildroot.img; \
		  echo 'Done. Kernel artifacts updated.'"

.PHONY:
docker-buildroot-full: docker-kernel docker-buildroot-rootfs docker-buildroot-sd-image

.PHONY:
docker-buildroot-volume-create:
	docker volume create $(BUILDROOT_VOLUME)

.PHONY:
docker-buildroot-volume-rm:
	docker volume rm $(BUILDROOT_VOLUME) 2>/dev/null || true

.PHONY:
docker-buildroot-output-volume-create:
	docker volume create $(BUILDROOT_OUTPUT_VOLUME)

.PHONY:
docker-buildroot-output-volume-rm:
	docker volume rm $(BUILDROOT_OUTPUT_VOLUME) 2>/dev/null || true
