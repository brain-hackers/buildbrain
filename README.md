buildbrain
==========

This repository includes:

 - linux-brain, u-boot-brain, nkbin_maker and boot4u as submodules
 - Useful build targets in Makefile
 - r3build.toml to watch changes that occur in submodules


Confirmed environments
----------------------

- Debian 10 (buster) amd64
- Debian 11 (bullseye) amd64
- macOS 26.5 (Tahoe) arm64-apple-darwin25.5.0 via Docker


Getting Started
---------------

1. Install dependencies.

    ```
    $ sudo apt install build-essential bison flex libncurses5-dev gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf libssl-dev bc lzop qemu-user-static debootstrap kpartx libyaml-dev python3-pyelftools
    ```

1. Clone this repository with recursive clone enabled.

    ```
    $ git clone --recursive git@github.com:brain-hackers/buildbrain.git
    ```

    - If you've cloned it without `--recursive`, run following command:

    ```
    $ git submodule update --init --recursive
    ```

1. Install uuu.

    - Follow [the instruction](https://github.com/NXPmicro/mfgtools#linux) and build `uuu` executable.
    - Put `uuu` where the PATH executable points to.


Build U-Boot
-----------------------

1. Run `make udefconfig-sh*` to generate `.config`.

    - For Sx1: `make udefconfig-sh1`
    - For Sx6: `make udefconfig-sh6`
    - For x1:  `make udefconfig-h1`

2. Run `make ubuild` to build whole repository and generate `u-boot.sb` or `u-boot.bin`.

    - i.MX283 loads a packed U-Boot executable called `u-boot.sb`.


Inject U-Boot into i.MX283 in recovery mode
-----------------------
1. Follow `Build U-Boot` procedure to make U-Boot binary.

1. Run `make uuu`

Build and make NK.bin
-----------------------

1. Follow `Build U-Boot` procedure to make U-Boot binary.

1. Run `make nkbin-maker`.

1. To make `nk.bin`, run `make nk.bin`.

    - nkbin_maker packs `u-boot.bin` into `nk.bin`.

Build and deploy boot4u
-----------------------

1. Run `make boot4u`

1. Create index.din and copy AppMain.bin
    - `mkdir /path/to/your/sd/1st/partition/App/boot4u`
    - `touch /path/to/your/sd/1st/partition/App/boot4u/index.din`
    - `cp boot4u/AppMain.bin  /path/to/your/sd/1st/partition/App/boot4u/`


Build Linux
-----------

1. Run `make ldefconfig` to generate `.config`.

1. Run `make lbuild` to generate `zImage`.

1. Confirm that `linux-brain/arch/arm/boot/zImage` exists.


Build a Debian rootfs
---------------------

1. Run `make ldefconfig lbuild`.

1. Run APT cache in background (mandatory): `make aptcache`.

1. Run `make brainux`.

1. Run `make image/sd.img`

1. Confirm that `image/sd.img` is built and burn it to an SD card.


Build a Buildroot rootfs
------------------------

Buildroot rootfs aims to be the most lightweight rootfs for experimental use. `make buildroot_rootfs` runs the defconfig target for rootfs-only build and then builds the rootfs tarball and a CPIO archive for initramfs. `make image/sd_buildroot.img` makes a bootable SD image in `image` directory like the typical Brainux SD image.

If you want to customize the build of Buildroot, `cd` into `buildroot` and use the following targets:

 - `make menuconfig` to change the configuration
 - `make` to build the rootfs (`-j` option might give you extra speed)

For Docker-based customization, use the interactive targets:

1. `make docker-buildroot-menuconfig`
2. `make docker-buildroot-savedefconfig` — writes `buildroot/.config` back to `buildroot/configs/brain_imx28_defconfig` so your changes are committed-safe.
3. `make docker-buildroot-rootfs` — rebuilds the rootfs with the updated config.

`image/sd_buildroot.img` target expects presence of the tarball at `buildroot/output/images/rootfs.tar`. You'll have to `clean` and rebuild every time you change the Buildroot's config before making the SD image.


Docker build
------------

You can build everything in Docker instead of preparing native Linux cross toolchains on your host.

### Prerequisites

- Docker Desktop (or Docker Engine) with Linux containers enabled
- A clone with submodules initialized

### Steps

1. Build the builder image.

    ```sh
    make docker-build
    ```

2. Build complete SD image in stages (recommended for macOS to avoid daemon crashes).

    ```sh
    make docker-sd-image-full
    ```

    This runs three separate containers in sequence, which distributes resource load and prevents Docker Desktop daemon from running out of memory. Alternatively, run each stage independently:

    ```sh
    make docker-kernel
    make docker-rootfs
    make docker-sd-image
    ```

    **Note:** On macOS Docker Desktop, the combined memory footprint of kernel compilation, rootfs staging, and loop device operations can exceed the default VM allocation (~2-4 GB). Breaking into stages allows the daemon to garbage collect between steps.

    **Note:** `make docker-rootfs` (and thus `make docker-sd-image-full`) always deletes and recreates the named volume `buildbrain-brainux-rootfs` before building, so each rootfs build starts from a clean slate. To delete the volume manually between runs use `make docker-volume-rm`.

3. *(Optional)* Build a Buildroot-based SD image instead.

    ```sh
    make docker-buildroot-full
    ```

    This builds the Linux kernel, the Buildroot rootfs, and assembles `image/sd_buildroot.img`.  Run each stage independently if preferred:

    ```sh
    make docker-kernel
    make docker-buildroot-rootfs
    make docker-buildroot-sd-image
    ```

    The Buildroot rootfs is stored in a separate named volume (`buildbrain-buildroot-rootfs`) for the same Linux-filesystem reasons as the Debian rootfs.  `make docker-buildroot-rootfs` always recreates it from scratch; use `make docker-buildroot-volume-rm` to wipe it manually.

### Direct Docker commands (advanced)

For macOS, run in **stages** and use a **named volume** for the rootfs.

> [!NOTE] Why a named volume for the rootfs?
> macOS APFS (the host filesystem behind Docker bind mounts) cannot create device
> files (`mknod`), may strip `setuid` bits, and does not faithfully preserve all
> Linux filesystem attributes.  If the Debian rootfs is stored on APFS the result
> looks complete but will fail to boot — systemd cannot exec as PID 1 because the
> rootfs is subtly broken.  The `make docker-*` targets below store `brainux/` in a
> Docker **named volume** (`buildbrain-brainux-rootfs`), which lives inside the
> Docker Desktop Linux VM on an ext4 filesystem and supports full Linux semantics.

```sh
# Create a named volume for the rootfs (Linux ext4 inside the Docker Desktop VM)
$ docker volume create buildbrain-brainux-rootfs

# Stage 1: kernel (bind mount is fine for source + outputs)
$ docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work buildbrain-builder:local \
    bash -lc "make ldefconfig && make lbuild"

# Stage 2: rootfs (must use named volume, NOT a bind mount for brainux/)
$ docker run --rm --platform linux/amd64 --privileged -e CI=true \
    -v buildbrain-brainux-rootfs:/work/brainux \
    -v "$PWD":/work -w /work buildbrain-builder:local \
    bash -lc "make brainux"

# Stage 3: image assembly (mount the same named volume so cp -a reads from Linux ext4)
$ docker run --rm --platform linux/amd64 --privileged \
    -v buildbrain-brainux-rootfs:/work/brainux \
    -v "$PWD":/work -w /work buildbrain-builder:local \
    bash -lc "make -C nkbin_maker clean all && make IMG_BUILD_JOBS=1 image/sd.img"
```

On Linux with sufficient resources, you can run all steps in one container (no named volume needed on a native Linux host):

```sh
$ docker run --rm --platform linux/amd64 --privileged -e CI=true -v "$PWD":/work -w /work buildbrain-builder:local \
    bash -lc "make ldefconfig lbuild && make nkbin-maker && make brainux && make image/sd.img"
```

Other useful Docker recipes:

- `make docker-uboot` to build U-Boot
- `make docker-kernel` to build Linux kernel
- `make docker-(buildroot-)volume-(create|rm)` to manage the Debian/Buildroot rootfs volume
- `make docker-(buildroot-)patch-(kernel|rootfs)-image` to quickly update just one partition in `image/sd(_buildroot).img` (which must already exist)

Known issues
----------------------------------------
If you use GCC 10 for the host compiler, `make ubuild` may fail.
To complete build, open `/u-boot-brain/scripts/dtc/dtc-lexer.lex.c` or `/u-boot-brain/scripts/dtc/dtc-parser.tab.c` then comment out `YYLTYPE yylloc;`

Watch changes in submodules & auto-build
----------------------------------------

1. Run `make setup-dev` to prepare a Python venv to watch code changes. Namely;

    - Python 3 venv in `env`
    - r3build command in the env

1. Run `r3build`. It'll detect the changes you make and builds the corresponding executable automatically.


What's r3build?
---------------

[r3build](https://github.com/puhitaku/r3build) is a smart file watcher that aims to provide hot-reloading feature like Web frontend development.
