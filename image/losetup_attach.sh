#!/bin/bash
# losetup_attach.sh - attach an image (or a region of one) to a loop device.
#
# Usage: losetup_attach.sh [--offset <bytes>] [--sizelimit <bytes>] <image>
#
# Attaches the image to the next free loop device and prints the device path.
set -euo pipefail

# losetup -f may return "/dev/loopN (lost)" when the device number is
# allocated by the kernel but the node is absent from /dev (common in
# Docker Desktop).  Strip the annotation to get the bare path, then
# create the node with mknod if it is still missing.
DEV=$(sudo losetup -f | awk '{print $1}')
NUM=${DEV##/dev/loop}
[ -e "${DEV}" ] || sudo mknod -m 0660 "${DEV}" b 7 "${NUM}"
sudo losetup "${DEV}" "$@"
echo "${DEV}"
