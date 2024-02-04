#!/bin/bash
set -uex -o pipefail

JOBS=$(nproc)
REPO=$(git rev-parse --show-toplevel)
WORK=${REPO}/image/work
LINUX=${REPO}/linux-brain
ROOTFS=$1
IMG_NAME=$2
IMG=${REPO}/image/${IMG_NAME}
SIZE_M=$3
export CROSS_COMPILE=arm-linux-gnueabi-

mkdir -p ${WORK}
mkdir -p ${WORK}/lilobin

for i in "a7200" "a7400" "sh1" "sh2" "sh3" "sh4" "sh5" "sh6" "sh7"; do
    NUM=$(echo $i | sed -E 's/sh//g')

    make -C ${REPO}/u-boot-brain distclean pw${i}_defconfig
    make -j${JOBS} -C ${REPO}/u-boot-brain u-boot.bin
    ${REPO}/nkbin_maker/bsd-ce ${REPO}/u-boot-brain/u-boot.bin

    case $i in
        "a7200")
            mv ${REPO}/nk.bin ${WORK}/edna3exe.bin
            mv ${REPO}/u-boot-brain/u-boot.bin ${WORK}/lilobin/gen2.bin;;
        "a7400")
            mv ${REPO}/u-boot-brain/u-boot.bin ${WORK}/lilobin/gen2_7400.bin;;
        "sh1" | "sh2" | "sh3")
            mv ${REPO}/nk.bin ${WORK}/edsa${NUM}exe.bin
            mv ${REPO}/u-boot-brain/u-boot.bin ${WORK}/lilobin/gen3_${NUM}.bin;;
        "sh4" | "sh5" | "sh6" | "sh7")
            mv ${REPO}/nk.bin ${WORK}/edsh${NUM}exe.bin
            mv ${REPO}/u-boot-brain/u-boot.bin ${WORK}/lilobin/gen3_${NUM}.bin;;
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

sudo kpartx -av ${IMG}

LOOPDEV=$(losetup -l | grep ${IMG_NAME} | grep -o 'loop.' | tail -n 1)

sudo mkfs.fat -n boot -F32 -v -I /dev/mapper/${LOOPDEV}p1
sudo mkfs.ext4 -L rootfs /dev/mapper/${LOOPDEV}p2

mkdir -p ${WORK}/p1 ${WORK}/p2
sudo mount -o utf8=true /dev/mapper/${LOOPDEV}p1 ${WORK}/p1
sudo mount /dev/mapper/${LOOPDEV}p2 ${WORK}/p2

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
sudo kpartx -d ${IMG}

rmdir ${WORK}/p1 ${WORK}/p2

