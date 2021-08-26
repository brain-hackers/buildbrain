buildbrain
==========

This repository includes:

 - linux-brain, u-boot-brain and nkbin_maker as submodules
 - Useful build targets in Makefile
 - r3build.toml to watch changes that occur in submodules


Confirmed environments
----------------------

- Debian 10 (buster) amd64


Getting Started
---------------

1. Install dependencies.

    ```
    $ sudo apt install build-essential bison flex libncurses5-dev gcc-arm-linux-gnueabi qemu-user-static
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


Build and inject U-Boot
-----------------------

1. Run `make udefconfig-sh*` to generate `.config`.

    - For Sx1: `make udefconfig-sh1`
    - For Sx6: `make udefconfig-sh6`

2. Run `make ubuild` to build whole repository and generate `u-boot.sb`.

    - i.MX283 loads a packed U-Boot executable called `u-boot.sb`.

3. To inject the executable into i.MX283 in recovery mode, run `make uuu`.


Build and make NK.bin
-----------------------

1. Run `make udefconfig` to generate `.config`.

2. Run `make ubuild` to build whole repository and generate `u-boot.bin`.

3. Run `make nkbin-maker`.

4. To make `nk.bin`, run `make nk.bin`.

    - nkbin_maker packs `u-boot.bin` into `nk.bin`.


Build Linux
-----------

1. Run `make ldefconfig` to generate `.config`.

1. Run `make lbuild` to generate `zImage`.

1. Confirm that `linux-brain/arch/arm/boot/zImage` exists.


Bootstrap Debian 11 (bullseye)
------------------------------

1. Run `make ldefconfig lbuild`.

1. Run APT cache in background (mandatory): `make aptcache`.

1. Run `make brainux`.

1. Run `make image/sd.img`

1. Confirm that `image/sd.img` is built and burn it to an SD card.

Watch changes in submodules & auto-build
----------------------------------------

1. Run `make setup-dev` to prepare a Python venv to watch code changes. Namely;

    - Python 3 venv in `env`
    - r3build command in the env

1. Run `r3build`. It'll detect the changes you make and builds the corresponding executable automatically.


What's r3build?
---------------

[r3build](https://github.com/puhitaku/r3build) is a smart file watcher that aims to provide hot-reloading feature like Web frontend development.
