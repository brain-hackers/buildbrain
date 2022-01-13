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


Bootstrap Debian 11 (bullseye)
------------------------------

1. Run `make ldefconfig lbuild`.

1. Run APT cache in background (mandatory): `make aptcache`.

1. Run `make brainux`.

1. Run `make image/sd.img`

1. Confirm that `image/sd.img` is built and burn it to an SD card.

Known issues
----------------------------------------
If you using gcc 10 for host compiler, `make ubuild` may fail.  
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
