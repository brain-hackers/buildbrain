# Objective

This repository contains anything necessary to build an SD card image file of Brainux - a Debian-based Linux distribution for a series of e-dictionary "Brain" series sold by SHARP, a Japanese manufacturer - and now I'm going to add the root AGENTS.md for automated development.

Explore the repository to generate appropriate AGENTS.md that will help CC for future runs. AGENTS.md should contain project memory and instructions for CC.


# Hints and instructions about the repo's structure

- Knowledge useful to understand the inside of SHARP Brain and its hacking scene will be contained in /docs/knowledge.
- The definition of GitHub Actions workflow (/.github/workflows/build.yml) will be useful to understand how it enters into the build procedure.
- The repo contains some submodules. File search or string search at the repo's root is not recommended.
  - Linux (linux-brain)
  - U-Boot (u-boot-brain)
  - BrainLILO (chain-boot tool specially made for specific older models)
  - boot4u (chain-boot tool specially made for specific newer models)
  - buildroot (to build an alternative lightweight rootfs, instead of the default Debian)
  - nkbin_maker (converter to turn U-Boot's ELF into an nk.bin that Windows CE's EBOOT bootloader understands)


# My typical usage of buildbrain on the development of Brainux


## Develop Linux kernel

1. `cd` into linux-brain
2. Checkout an appropriate branch
  - The default branch is `brain`. When I edit the code, I make another branch from `brain`.
3. Edit the code
4. `cd ..` and go up into buildbrain
5. `make lclean ldefconfig lbuild` to start a clean build
  - Run `make lmenuconfig` to edit the .config (which is not a suitable way for coding agents due to TUI)
6. Copy the resulting kernel `/linux-brain/arch/arm/boot/zImage` and `/linux-brain/arch/arm/boot/dts/imx28-pw*.dtb` into an SD card and run it on a real machine
6. Continue try-and-error loop; make another change to the code, `make lbuild`, and run it
7. `cd linux-brain` and commit the change
  - Commit message must comply the kernel's convention; watch surrounding files and commits to infer the format
8. File a PR and ask review
9. Merge it


## Develop U-Boot

It is mostly the same as Linux kernel.


## Update Brainux's configuration script and file

1. Checkout an appropriate branch
2. Edit scripts and files in os-brainux
3. Run `make brainux` to build the root filesystem
  - ... or run `make image/sd.img` to create a complete SD image
4. Copy the root filesystem to an SD card's second partition or write the entire image to an SD card
5. Repeat 3 and 4
6. Commit the change, file a PR, ask a review, and merge it

