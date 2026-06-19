# losetup_attach - source this file to get the losetup_attach function.
#
# Usage:
#   source "$(dirname "$0")/losetup_attach.sh"
#   DEV=$(losetup_attach --offset <bytes> [--sizelimit <bytes>] <image>)
#
# Attaches an image (or a region of one) to the next free loop device and
# prints the device path.  Works in environments where the kernel allocates
# loop device numbers but udev has not created their /dev nodes (e.g. Docker
# Desktop on macOS): losetup -f may return "/dev/loopN (lost)" in that case,
# and the node is created with mknod before attaching.

losetup_attach() {
    # losetup -f may return "/dev/loopN (lost)" when the device number is
    # allocated by the kernel but the node is absent from /dev (common in
    # Docker Desktop).  Strip the annotation to get the bare path, then
    # create the node with mknod if it is still missing.
    local DEV
    DEV=$(sudo losetup -f | awk '{print $1}')
    local NUM=${DEV##/dev/loop}
    [ -e "${DEV}" ] || sudo mknod -m 0660 "${DEV}" b 7 "${NUM}"
    sudo losetup "${DEV}" "$@"
    echo "${DEV}"
}
