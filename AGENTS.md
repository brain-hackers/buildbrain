# AGENTS.md

## Purpose

This repository builds Brainux, a Debian-based Linux distribution and SD card image for SHARP Brain devices. The root repo is the orchestration layer: it wires together kernel, bootloader, rootfs, image-building scripts, CI, and several hardware-specific submodules.

Future agents should treat this file as project memory plus operating instructions for working in `buildbrain`.

## Repository map

- `linux-brain/`: Linux kernel submodule.
- `u-boot-brain/`: U-Boot submodule.
- `boot4u/`: chain-boot tool for newer models.
- `brainlilo/`: chain-boot tool for older models.
- `nkbin_maker/`: converts `u-boot.bin` into `nk.bin` for the Windows CE boot flow.
- `buildroot/`: alternative lightweight rootfs build.
- `os-brainux/`: Brainux rootfs customization scripts and overrides.
- `os-buildroot/`: Buildroot-side overrides.
- `image/`: SD image creation scripts.
- `tools/`: helper scripts such as cross-prefix detection and APT cache tooling.
- `docs/knowledge/`: hardware and boot-process knowledge for SHARP Brain devices. Prefer the Markdown files over PDFs for fast reading and search.

## Search strategy

Do not start with a repo-wide search from the root unless you actually need submodule results. This repo contains large submodules, and broad searches are noisy and slow.

Prefer scoped searches:

- Kernel work: search only under `linux-brain/`.
- U-Boot work: search only under `u-boot-brain/`.
- Rootfs and image work: search `os-brainux/`, `image/`, `tools/`, and the root `Makefile`.
- Hardware/background research: read `docs/knowledge/*.md`.

## Important project knowledge

- Brainux development often happens in submodules, not in the root repo.
- Typical kernel workflow:
  1. work inside `linux-brain/` on a branch based on `brain`
  2. return to the repo root
  3. run `make lclean ldefconfig lbuild` for a clean rebuild, or `make lbuild` for incremental rebuilds
  4. test on real hardware by copying `linux-brain/arch/arm/boot/zImage` and matching DTBs
  5. commit in `linux-brain/` using the surrounding kernel commit style
- Typical U-Boot workflow is similar, but uses `u-boot-brain/` plus the `make udefconfig-*` and `make ubuild` targets.
- Typical Brainux rootfs workflow edits files under `os-brainux/`, then runs `make brainux` or `make image/sd.img`.
- Real-device testing is part of the normal loop. A local build passing is useful but not sufficient for hardware changes.

## Main build targets

The root `Makefile` is the main entry point.

- Setup:
  - `make setup`: initialize submodules.
  - `make setup-dev`: create `env/` and install `r3build`.
  - `make watch`: run the file watcher after `setup-dev`.
- Linux:
  - `make ldefconfig`
  - `make ldefconfig-x1`
  - `make lbuild`
  - `make lclean`
- U-Boot:
  - `make udefconfig-<model>` such as `udefconfig-sh1` or `udefconfig-h1`
  - `make ubuild`
  - `make uclean`
- NK.bin:
  - `make nkbin-maker`
  - `make nk.bin`
- Chain boot tools:
  - `make boot4ubuild`
  - `make lilobuild`
- Rootfs and images:
  - `make brainux`
  - `make brainux-umount-special`
  - `make brainux-clean`
  - `make buildroot_rootfs`
  - `make image/sd.img`
  - `make image/sd_x1.img`
  - `make image/sd_buildroot.img`
- Utilities:
  - `make aptcache`
  - `make uuu`

## Build behavior and constraints

- `make brainux` only works on Linux. It uses `debootstrap`, `qemu-arm-static`, `sudo`, chroot, and bind mounts.
- Outside CI, `make brainux` expects the local APT cache from `make aptcache` and points debootstrap at `http://localhost:65432/debian/`.
- `make brainux-umount-special` is the normal cleanup step after rootfs builds.
- `make image/sd.img` and related image targets depend on a prepared rootfs and remove `image/work` via `make clean_work`.
- `make ubuild` chooses the output format from the detected cross toolchain:
  - `arm-linux-gnueabi-` builds `u-boot.sb`
  - other configured prefixes build `u-boot.imx`

## CI reference

The authoritative automation is `.github/workflows/build.yml`.

CI currently does the following:

- Builds Linux artifacts for both the default family and the `x1` family.
- Builds U-Boot artifacts for multiple models through a matrix.
- Builds `nk.bin` for the older-model U-Boot jobs.
- Builds full Debian-based SD images for the default family and for `x1`.

When changing build logic, keep the local Makefile workflow and CI workflow aligned.

## Files and outputs to know

- Linux outputs:
  - `linux-brain/arch/arm/boot/zImage`
  - DTBs under `linux-brain/arch/arm/boot/dts/`
- U-Boot outputs:
  - `u-boot-brain/u-boot.bin`
  - `u-boot-brain/u-boot.sb` or `u-boot-brain/u-boot.imx`
- Converted boot image:
  - `nk.bin`
- SD images:
  - `image/sd.img`
  - `image/sd_x1.img`
  - `image/sd_buildroot.img`

## Guidance for edits

- If the task is about kernel or U-Boot source, make the change in the relevant submodule rather than trying to patch generated outputs or wrapper scripts in the root repo.
- If the task is about Brainux package selection, startup behavior, or filesystem contents, inspect `os-brainux/` first.
- If the task is about image layout or packaging, inspect `image/` and the root `Makefile`.
- If the task is about cross-compile behavior, inspect `tools/getcross` and the relevant Makefile targets.
- Avoid using interactive config editors such as `menuconfig` unless the user explicitly asks; prefer editing committed defconfig/config sources where practical.

## Validation expectations

Choose the lightest validation that matches the change:

- Makefile or CI edits: run the directly affected `make` target when feasible.
- Kernel build plumbing: at least run the relevant `make ldefconfig*` or `make lbuild` path if the environment supports it.
- U-Boot build plumbing: at least run the matching `make udefconfig-*` and `make ubuild` path if feasible.
- Rootfs/image changes: prefer `make brainux brainux-umount-special`, and image targets when dependencies and privileges are available.

If a full build is not possible because of missing toolchains, root privileges, mounts, or long runtime, say that explicitly and leave the repo in a clean state.

## Knowledge docs

- Start with `docs/knowledge/*.md` when you need hardware, boot-sequence, suspend, or eMMC-install context.
- `docs/knowledge/AGENTS.md` defines the rule for converting a knowledge PDF into Markdown. If asked to do such a conversion, preserve page positions with `# Page NN` headings, add an abstract, and write a concise text-first technical explanation rather than raw OCR.

## Commit and review notes

- Submodules have their own history and conventions. Kernel commits should follow the style already used in `linux-brain/`.
- Root-repo changes should stay focused on orchestration, config, CI, docs, image assembly, and rootfs customization.
- When a task spans both the root repo and a submodule, keep the responsibility split clear in the final report.
