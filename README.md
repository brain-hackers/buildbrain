buildbrain
==========

This repository includes:

 - linux-brain and u-boot-brain as submodules
 - Useful build targets in Makefile
 - r3build.toml to watch changes that occur in submodules


Getting Started
---------------

1. Clone this repository with recursive clone enabled.

    ```
    $ git clone --recursive git@github.com:puhitaku/buildbrain.git
    ```

    - If you've cloned it without `--recursive`, run following command:

    ```
    $ git submodule update --init --recursive
    ```

2. Then run `make setup` to prepare an build environment. Namely;

    - Python 3 venv in `env`
    - r3build command in the env

3. Install uuu.

    - Follow [the instruction](https://github.com/NXPmicro/mfgtools#linux) and build `uuu` executable.
    - Put `uuu` where the PATH executable points to.


Build and inject U-Boot
-----------------------

1. Run `make udefconfig` to generate `.config`.

2. Run `make ubuild` to build whole repository and generate `u-boot.sb`.

    - i.MX283 loads a packed U-Boot executable called `u-boot.sb`.

3. To inject the executable into i.MX283 in recovery mode, run `make uuu`.


Build Linux
-----------

1. Run `make ldefconfig` to generate `.config`.

1. Run `make lbuild` to generate `zImage`.

1. Confirm that `linux-brain/arch/arm/boot/zImage` exists.


Watch changes in submodules & auto-build
----------------------------------------

1. Run `r3build`. It'll detect the changes you make and builds the corresponding executable automatically.


What's r3build?
---------------

[r3build](https://github.com/puhitaku/r3build) is a smart file watcher that aims to provide hot-reloading feature like Web frontend development.

