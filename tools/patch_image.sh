#!/usr/bin/env bash
set -e

TYPE="$1"
SPECIFIED_IMAGE="$2"

# Parse modes and assign configurations
case "$TYPE" in
    "rootfs-buildroot")
        IMAGE="${SPECIFIED_IMAGE:-image/sd_buildroot.img}"
        PART="2"
        MNT_DIR="/mnt/brainp2"
        MOUNT_OPTS=""
        SRC_DIR="buildroot_rootfs"
        ;;
    "rootfs-brainux")
        IMAGE="${SPECIFIED_IMAGE:-image/sd.img}"
        PART="2"
        MNT_DIR="/mnt/brainp2"
        MOUNT_OPTS=""
        SRC_DIR="brainux"
        ;;
    "kernel")
        IMAGE="${SPECIFIED_IMAGE:-image/sd.img}"
        PART="1"
        MNT_DIR="/mnt/brainp1"
        MOUNT_OPTS="-o utf8=true"
        ;;
    *)
        echo "Usage: $0 [kernel|rootfs-buildroot|rootfs-brainux] [optional_image_path]"
        exit 1
        ;;
esac

if [ ! -f "$IMAGE" ]; then
    echo "Error: Target image '$IMAGE' does not exist."
    exit 1
fi

echo "Mapping $IMAGE with kpartx..."
KPARTX_OUTPUT=$(kpartx -av "$IMAGE")
echo "$KPARTX_OUTPUT"

# Extract loop device name (e.g., loop0)
LONAME=$(echo "$KPARTX_OUTPUT" | sed -n "s/^add map \(loop[0-9]\+\)p${PART}.*/\1/p" | head -1)
if [ -z "$LONAME" ]; then
    echo "Failed to detect loop device from kpartx output."
    exit 1
fi

MAPPER_DEV="/dev/mapper/${LONAME}p${PART}"
mkdir -p "$MNT_DIR"

# Cleanup trap to ensure we clean up loop devices and mounts on failure
cleanup() {
    echo "Cleaning up mounts and loop devices..."
    if mountpoint -q "$MNT_DIR"; then
        umount "$MNT_DIR"
    fi
    kpartx -d "$IMAGE" || true
}
trap cleanup EXIT

echo "Mounting partition p${PART} to $MNT_DIR..."
mount $MOUNT_OPTS "$MAPPER_DEV" "$MNT_DIR"

if [[ "$TYPE" == rootfs-* ]]; then
    echo "Wiping old rootfs..."
    rm -rf "${MNT_DIR:?}"/*
    echo "Copying new rootfs from $SRC_DIR..."
    cp -a "$SRC_DIR"/. "$MNT_DIR/"
elif [ "$TYPE" = "kernel" ]; then
    echo "Updating kernel artifacts on boot partition..."
    cp -f linux-brain/arch/arm/boot/zImage "$MNT_DIR/"
    cp -f linux-brain/arch/arm/boot/dts/imx28-pw*.dtb "$MNT_DIR/"
fi

sync
echo "Done. ${TYPE} update applied successfully to ${IMAGE}."
