JOBS=$(shell grep -c '^processor' /proc/cpuinfo)

UBOOT_CROSS=$(shell ./tools/getcross u-boot)
LINUX_CROSS=$(shell ./tools/getcross linux)
ROOTFS_CROSS=$(shell ./tools/getcross rootfs)
export ARCH=arm

DOCKER_IMAGE := buildbrain-builder:local
ROOTFS_VOLUME := buildbrain-brainux-rootfs

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

.PHONY: brainux brainux-umount-special brainux-clean
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

	# Mount proc and sys to allow debootstrap to run the second stage in the chroot.
	# Keep the mounting commands AFTER the first stage of debootstrap, because
	# debootstrap's cleanup code/trap tries to clean up the target directory
	# (`rm -rf /work/brainux/proc`) and fails because proc virtual files can't be removed.
	sudo mkdir -p brainux/proc brainux/sys
	sudo mount -t proc none $(shell pwd)/brainux/proc
	sudo mount --rbind /sys $(shell pwd)/brainux/sys

	# Copy qemu-arm-static and setup script to allow running the second stage of
	# debootstrap in the chroot on an x86 host.
	sudo cp /usr/bin/qemu-arm-static brainux/usr/bin/
	sudo cp ./os-brainux/setup_brainux.sh brainux/
	sudo ./os-brainux/override-pre.sh ./os-brainux/override ./brainux
	# Register qemu-arm-static binfmt handler if not already present.
	# The F (fixed) flag makes the kernel resolve the interpreter from the
	# host filesystem so it works inside the chroot even without qemu in it.
	# This is a no-op if the entry already exists (e.g. in CI or native Linux).
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
	make -C buildroot brain_imx28_defconfig
	make -C buildroot -j 12
	sudo mkdir -p buildroot_rootfs
	sudo tar -C ./buildroot_rootfs -xf buildroot/output/images/rootfs.tar

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

# ========== Docker-based build targets (for macOS and other non-Linux hosts) ==========

.PHONY:
docker-build:
	docker build --platform linux/amd64 -t $(DOCKER_IMAGE) -f Dockerfile .

.PHONY:
docker-uboot:
	docker run --rm --platform linux/amd64 -v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make udefconfig-sh1 && make ubuild"

# Build Linux kernel using brain defconfig.
# mrproper wipes stale host-tool binaries (e.g. arm64 objects left from a
# previous native build) so they are always recompiled for the container's
# architecture before defconfig and the full build run.
.PHONY:
docker-kernel:
	docker run --rm --platform linux/amd64 -v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make lclean; make ldefconfig && make lbuild"

# Build Debian rootfs in container with debootstrap and qemu.
# The rootfs is stored in a Docker named volume (Linux ext4 inside the Docker
# Desktop VM) instead of the macOS APFS bind mount.  This is critical: APFS
# cannot represent mknod device files or preserve all Linux permission bits,
# which produces a rootfs that fails to boot despite appearing structurally
# complete.  A named volume stores a true Linux filesystem and avoids all of
# these issues.
.PHONY:
docker-rootfs: docker-volume-rm docker-volume-create
	docker run --rm --platform linux/amd64 --privileged -e CI=true \
		-v $(ROOTFS_VOLUME):/work/brainux \
		-v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make brainux"

# Assemble SD image from pre-built kernel and rootfs.
# Requires privileged mode because make targets use loop devices, kpartx and mount.
# Mounts the same named volume used by docker-rootfs so the rootfs copy into the
# ext4 partition originates from the Linux-native volume, not from macOS APFS.
.PHONY:
docker-sd-image:
	docker run --rm --platform linux/amd64 --privileged \
		-v $(ROOTFS_VOLUME):/work/brainux \
		-v "$$PWD":/work -w /work $(DOCKER_IMAGE) \
		bash -lc "make -C nkbin_maker clean all && make IMG_BUILD_JOBS=1 image/sd.img"

# Build complete SD image from scratch (stages: kernel, rootfs, then assembly).
# We split the build into 3 phases to avoid overwhelming the daemon on macOS Docker Desktop.
.PHONY:
docker-sd-image-full: docker-kernel docker-rootfs docker-sd-image

# --------------------- Docker named-volume helpers ---------------------
# docker-rootfs already recreates the volume automatically; these targets are
# provided for manual use (e.g. inspecting, wiping, or recreating between runs).
.PHONY:
docker-volume-create:
	docker volume create $(ROOTFS_VOLUME)

.PHONY:
docker-volume-rm:
	docker volume rm $(ROOTFS_VOLUME) 2>/dev/null || true

# ==================== end of Docker-based build targets ====================
