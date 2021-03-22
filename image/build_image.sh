#!/bin/bash
set -uex -o pipefail

JOBS=$(nproc)
REPO=$(git rev-parse --show-toplevel)
WORK=${REPO}/image/work
LINUX=${REPO}/linux-brain
IMG=${REPO}/image/sd.img

mkdir -p ${WORK}

for i in $(seq 1 7); do
    make -C ${REPO}/u-boot-brain pwsh${i}_defconfig
    make -j${JOBS} -C ${REPO}/u-boot-brain u-boot.bin
    ${REPO}/nkbin_maker/bsd-ce ${REPO}/u-boot-brain/u-boot.bin

    case $i in
        1|2|3)
            mv ${REPO}/nk.bin ${WORK}/edsa${i}exe.bin;;
        4|5|6)
            mv ${REPO}/nk.bin ${WORK}/edsh${i}exe.bin;;
        *)
            echo "WTF: $i"
            exit 1;;
    esac
done

dd if=/dev/zero of=${IMG} bs=1M count=3072

START1=2048
SECTORS1=$((1024 * 1024 * 64 / 512))
START2=$((2048 + ${SECTORS1}))

cat <<EOF > ${WORK}/part.sfdisk
${IMG}1 : start=${START1}, size=${SECTORS1}, type=b
${IMG}2 : start=${START2}, type=83
EOF

sfdisk ${IMG} < ${WORK}/part.sfdisk

sudo kpartx -av ${IMG}

LOOPDEV=$(losetup -l | grep sd.img | grep -o 'loop.')

sudo mkfs.fat -F32 -v -I /dev/mapper/${LOOPDEV}p1
sudo mkfs.ext4 /dev/mapper/${LOOPDEV}p2

mkdir -p ${WORK}/p1 ${WORK}/p2
sudo mount /dev/mapper/${LOOPDEV}p1 ${WORK}/p1
sudo mount /dev/mapper/${LOOPDEV}p2 ${WORK}/p2

sudo cp ${LINUX}/arch/arm/boot/zImage ${WORK}/p1/
sudo cp ${LINUX}/arch/arm/boot/dts/imx28-pwsh*.dtb ${WORK}/p1/
sudo cp ${WORK}/*.bin ${WORK}/p1/

sudo cp -ra ${REPO}/brainux/* ${WORK}/p2/

sudo umount ${WORK}/p1 ${WORK}/p2
sudo kpartx -d ${IMG}

rmdir ${WORK}/p1 ${WORK}/p2

