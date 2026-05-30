#!/bin/bash
set -uex -o pipefail

show_help() {
    cat << 'EOF'
Usage: ./build_image.sh ROOTFS IMG_NAME SIZE_M

Build a bootable image for Brainux.

Arguments:
  ROOTFS       Path to the root filesystem directory to include in the image (default: "rootfs").
  IMG_NAME     Name of the output image file (default: brainux.img).
  SIZE_M       Size of the output image in megabytes (default: 1024).
EOF
}

# Trigger help if requested or if no arguments are passed
if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
    show_help
    exit 0
fi

# JOBS is used to control the number of parallel jobs when building u-boot.
# By default, it uses the number of CPU cores. This can be overridden by
# setting the IMG_BUILD_JOBS environment variable before running the script,
# handy for Docker environments or when you want to limit resource usage.
JOBS=${IMG_BUILD_JOBS:-$(nproc)}
REPO=$(git rev-parse --show-toplevel)
WORK=${REPO}/image/work
LINUX=${REPO}/linux-brain
ROOTFS=${1:-rootfs} # Default to "rootfs" if not specified
IMG_NAME=${2:-brainux.img}
IMG=${REPO}/image/${IMG_NAME}
SIZE_M=${3:-1024} # Default to 1GB if not specified
export CROSS_COMPILE=arm-linux-gnueabi-

mkdir -p ${WORK}
mkdir -p ${WORK}/lilobin

for i in "a7200" "a7400" "sh1" "sh2" "sh3" "sh4" "sh5" "sh6" "sh7"; do
    NUM=$(echo $i | sed -E 's/sh//g')
    BUILD_DIR=${WORK}/uboot-build-${i}

    # Build per-board from isolated source copies to avoid fragile clean rules.
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

# Create an empty image file of the specified size.
dd if=/dev/zero of=${IMG} bs=1M count=${SIZE_M}

# We want to partition the image with two partitions:
# * a 64MB FAT32 partition for the bootloader and kernel, and
# * the rest of the space as an ext4 partition for the root filesystem.
START1=2048 # Start at 1MB (2048 sectors of 512 bytes) to align with typical partitioning schemes and avoid issues with some bootloaders.
SECTORS1=$((1024 * 1024 * 64 / 512)) # 64MB in sectors (512 bytes per sector)
START2=$((START1 + SECTORS1)) # Start the second partition immediately after the first

# We use sfdisk to create the partition table. The first partition is type 'b' (W95 FAT32), and the second is type '83' (Linux).
cat <<EOF > ${WORK}/part.sfdisk
${IMG}1 : start=${START1}, size=${SECTORS1}, type=b
${IMG}2 : start=${START2}, type=83
EOF

sfdisk ${IMG} < ${WORK}/part.sfdisk

# We want to format and write to the partitions. To do so, we use kpartx to create device mappings for the partitions in the image.
KPARTX_OUTPUT=$(sudo kpartx -av ${IMG})
# Extract the loop device name from kpartx output. It looks like:
# "add map loop0p1 (252:0): 0 131072 linear /dev/loop0 2048"
# We want to extract "loop0" from this line.
LOOPDEV=$(echo "${KPARTX_OUTPUT}" | sed -n 's/^add map \(loop[0-9]\+\)p1.*/\1/p' | head -n 1)

sudo mkfs.fat -n boot -F32 -v -I /dev/mapper/${LOOPDEV}p1
sudo mkfs.ext4 -L rootfs /dev/mapper/${LOOPDEV}p2

mkdir -p ${WORK}/p1 ${WORK}/p2
sudo mount -o utf8=true /dev/mapper/${LOOPDEV}p1 ${WORK}/p1
sudo mount /dev/mapper/${LOOPDEV}p2 ${WORK}/p2

echo ${BRAINUX_VERSION:-unknown} > ${WORK}/brainux_version
sudo cp ${WORK}/brainux_version ${WORK}/p1/
sudo cp ${LINUX}/arch/arm/boot/zImage ${WORK}/p1/
sudo cp ${LINUX}/arch/arm/boot/dts/imx28-pw*.dtb ${WORK}/p1/
sudo mkdir -p ${WORK}/p1/nk
sudo cp ${WORK}/*.bin ${WORK}/p1/nk/

# Prepare the WinCE application "Launch Linux". "LILO" stands for "Linux Loader".
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

# Clean up: unmount the partitions and remove the device mappings.
sudo umount ${WORK}/p1 ${WORK}/p2
sudo kpartx -d ${IMG}

rmdir ${WORK}/p1 ${WORK}/p2

