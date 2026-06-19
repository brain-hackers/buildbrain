#!/bin/bash
set -uex -o pipefail

JOBS=$(nproc)
REPO=$(git rev-parse --show-toplevel)
WORK=${REPO}/image/work
LINUX=${REPO}/linux-brain
IMG=${REPO}/image/sd_x1.img
export CROSS_COMPILE=arm-linux-gnueabihf-

mkdir -p ${WORK}

dd if=/dev/zero of=${IMG} bs=1M count=3072

START1=2048
SECTORS1=$((1024 * 1024 * 64 / 512))
START2=$((2048 + ${SECTORS1}))

cat <<EOF > ${WORK}/part.sfdisk
${IMG}1 : start=${START1}, size=${SECTORS1}, type=b
${IMG}2 : start=${START2}, type=83
EOF

sfdisk ${IMG} < ${WORK}/part.sfdisk

# Attach each partition as its own loop device using explicit offsets.
# This avoids relying on partition sub-device creation (loopNpX) which
# requires udev and does not work reliably in Docker containers.
#
# Docker Desktop only pre-populates a small set of /dev/loopN nodes, so if
# losetup picks a higher number the device node may be absent.  Create it
# with mknod (major 7) before attaching.
losetup_attach() {
    local DEV
    DEV=$(sudo losetup -f)
    local NUM=${DEV#/dev/loop}
    [ -e "${DEV}" ] || sudo mknod -m 0660 "${DEV}" b 7 "${NUM}"
    sudo losetup "${DEV}" "$@"
    echo "${DEV}"
}

LOOPDEV1=$(losetup_attach --offset $((START1 * 512)) --sizelimit $((SECTORS1 * 512)) ${IMG})
LOOPDEV2=$(losetup_attach --offset $((START2 * 512)) ${IMG})

sudo mkfs.fat -F32 -v -I ${LOOPDEV1}
sudo mkfs.ext4 ${LOOPDEV2}

mkdir -p ${WORK}/p1 ${WORK}/p2
sudo mount ${LOOPDEV1} ${WORK}/p1
sudo mount ${LOOPDEV2} ${WORK}/p2

sudo cp ${LINUX}/arch/arm/boot/zImage ${WORK}/p1/
sudo cp ${LINUX}/arch/arm/boot/dts/imx7ulp-pwh*.dtb ${WORK}/p1/

sudo cp ${REPO}/u-boot-brain/u-boot.bin ${WORK}/p1/

sudo mkdir -p ${WORK}/p1/App/boot4u
sudo cp ${REPO}/boot4u/AppMain.bin ${WORK}/p1/App/boot4u/
sudo touch ${WORK}/p1/App/boot4u/index.din

sudo cp -ra ${REPO}/brainux/* ${WORK}/p2/

sudo umount ${WORK}/p1 ${WORK}/p2
sudo losetup -d ${LOOPDEV1} ${LOOPDEV2}

rmdir ${WORK}/p1 ${WORK}/p2

