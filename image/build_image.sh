#!/bin/bash
set -uex -o pipefail

show_help() {
    cat << 'EOF'
Usage: ./build_image.sh ROOTFS IMG_NAME SIZE_M

Build a bootable image for Brainux.

Arguments:
  ROOTFS       Path to the root filesystem directory to include in the image (default: "rootfs").
  IMG_NAME     Name of the output image file (default: sd.img).
  SIZE_M       Size of the output image in megabytes (default: 3072).
EOF
}

# Trigger help if requested or if no arguments are passed
if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    show_help
    exit 0
fi

JOBS=${IMG_BUILD_JOBS:-$(nproc)}
REPO=$(git rev-parse --show-toplevel)
WORK=${REPO}/image/work
LINUX=${REPO}/linux-brain
ROOTFS=${1:-rootfs}
IMG_NAME=${2:-sd.img}
IMG=${REPO}/image/${IMG_NAME}
SIZE_M=${3:-3072}
export CROSS_COMPILE=arm-linux-gnueabi-

mkdir -p ${WORK}
mkdir -p ${WORK}/lilobin

for i in "a7200" "a7400" "sh1" "sh2" "sh3" "sh4" "sh5" "sh6" "sh7"; do
    NUM=$(echo $i | sed -E 's/sh//g')
    BUILD_DIR=${WORK}/uboot-build-${i}

    rm -rf ${BUILD_DIR}
    rsync -a --exclude '.git' ${REPO}/u-boot-brain/ ${BUILD_DIR}/
    make -C ${BUILD_DIR} pw${i}_defconfig
    make -j${JOBS} -C ${BUILD_DIR} u-boot.bin
    ${REPO}/nkbin_maker/bsd-ce ${BUILD_DIR}/u-boot.bin

    case $i in
        "a7200")
            mv ${REPO}/nk.bin ${WORK}/edna3exe.bin
            mv ${BUILD_DIR}/u-boot.bin ${WORK}/lilobin/gen2.bin;;
        "a7400")
            mv ${BUILD_DIR}/u-boot.bin ${WORK}/lilobin/gen2_7400.bin;;
        "sh1" | "sh2" | "sh3")
            mv ${REPO}/nk.bin ${WORK}/edsa${NUM}exe.bin
            mv ${BUILD_DIR}/u-boot.bin ${WORK}/lilobin/gen3_${NUM}.bin;;
        "sh4" | "sh5" | "sh6" | "sh7")
            mv ${REPO}/nk.bin ${WORK}/edsh${NUM}exe.bin
            mv ${BUILD_DIR}/u-boot.bin ${WORK}/lilobin/gen3_${NUM}.bin;;
        *)
            echo "WTF: $i"
            exit 1;;
    esac
done

dd if=/dev/zero of=${IMG} bs=1M count=${SIZE_M}

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

LOOPDEV1=$(losetup_attach --offset $((START1 * 512)) --sizelimit $((SECTORS1 * 512)) ${IMG})
LOOPDEV2=$(losetup_attach --offset $((START2 * 512)) ${IMG})

sudo mkfs.fat -n boot -F32 -v -I ${LOOPDEV1}
sudo mkfs.ext4 -L rootfs ${LOOPDEV2}

mkdir -p ${WORK}/p1 ${WORK}/p2
sudo mount -o utf8=true ${LOOPDEV1} ${WORK}/p1
sudo mount ${LOOPDEV2} ${WORK}/p2

echo ${BRAINUX_VERSION:-unknown} > ${WORK}/brainux_version
sudo cp ${WORK}/brainux_version ${WORK}/p1/
sudo cp ${LINUX}/arch/arm/boot/zImage ${WORK}/p1/
sudo cp ${LINUX}/arch/arm/boot/dts/imx28-pw*.dtb ${WORK}/p1/
sudo mkdir -p ${WORK}/p1/nk
sudo cp ${WORK}/*.bin ${WORK}/p1/nk/

make -C ${REPO}/brainlilo

LILO="${WORK}/p1/アプリ/Launch Linux"
sudo mkdir -p "${LILO}"
sudo touch "${LILO}/index.din"
sudo touch "${LILO}/AppMain.cfg"
sudo cp ${REPO}/brainlilo/*.dll "${LILO}/"
sudo cp ${REPO}/brainlilo/BrainLILO.exe "${LILO}/AppMain_.exe"
gzip -cd ${REPO}/image/exeopener.exe.gz > ${REPO}/image/exeopener.exe
sudo cp ${REPO}/image/exeopener.exe "${LILO}/AppMain.exe"

sudo mkdir -p ${WORK}/p1/loader
sudo cp ${WORK}/lilobin/*.bin ${WORK}/p1/loader/

sudo cp -ra ${REPO}/${ROOTFS}/* ${WORK}/p2/

sudo umount ${WORK}/p1 ${WORK}/p2
sudo losetup -d ${LOOPDEV1} ${LOOPDEV2}

rmdir ${WORK}/p1 ${WORK}/p2

