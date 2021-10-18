buildbrain
==========

This repository includes:

 - linux-brain, u-boot-brain and boot4u as submodules
 - Useful build targets in Makefile
 - r3build.toml to watch changes that occur in submodules


Confirmed environments
----------------------

- Debian 10 (buster) amd64


Getting Started
---------------

1. Install dependencies.

    ```
    $ sudo apt install build-essential bison flex libncurses5-dev gcc-arm-linux-gnueabihf libssl-dev bc lzop
    $ pip install pyelftools
    ```

1. Clone this repository with recursive clone enabled.

    ```
    $ git clone --recursive git@github.com:brain-hackers/buildbrain.git
    ```

    - If you've cloned it without `--recursive`, run following command:

    ```
    $ git submodule update --init --recursive
    ```


Build U-Boot
-----------------------

1. Run `make udefconfig` to generate `.config`.

2. Run `make ubuild` to build whole repository and generate `u-boot.bin`.


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


Bootstrap Debian 10 (buster)
----------------------------

1. Partition an SD card into two partitions.

    - 1st: FAT32 (vfat), about 100MB
    - 2st: ext4, fill the remaining area

1. Build and copy the Linux kernel.

    - Run `make ldefconfig lbuild`.
    - Copy `/linux-brain/arch/arm/boot/zImage` and `/linux-brain/arch/arm/boot/dts/imx7ulp-pwh1.dtb` into the 1st partition.

1. Run APT cache in background (mandatory): `make aptcache`.

1. Run `make debian`.

1. Copy all contents in `./brainux` into the 2nd partition.

    - `sudo cp -ar ./brainux/* /path/to/your/sd/2nd/partition/`
    - Please make sure that all attributes are preserved with `-a` flag.


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

