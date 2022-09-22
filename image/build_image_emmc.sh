#!/bin/bash
set -uex -o pipefail

JOBS=$(nproc)
REPO=$(git rev-parse --show-toplevel)
WORK=${REPO}/image/work
LINUX=${REPO}/linux-brain
IMG=${REPO}/image/sd.img
export CROSS_COMPILE=${CROSS_COMPILE:="arm-linux-gnueabi-"}

mkdir -p ${WORK}
mkdir -p ${WORK}/lilobin

for i in "sh1"; do
    NUM=$(echo $i | sed -E 's/sh//g')

    make -C ${REPO}/u-boot-brain distclean pw${i}_defconfig
    make -j${JOBS} -C ${REPO}/u-boot-brain u-boot.sb u-boot.bin

    case $i in
        "sh1" | "sh2" | "sh3")
            mv ${REPO}/u-boot-brain/u-boot.sb ${WORK}/lilobin/gen3_${NUM}.sb
            mv ${REPO}/u-boot-brain/u-boot.bin ${WORK}/lilobin/gen3_${NUM}.bin;;
        *)
            echo "WTF: $i"
            exit 1;;
    esac
done

dd if=/dev/zero of=${IMG} bs=1M count=96

START1=2048
SECTORS1=$((1024 * 1024 * 64 / 512))
START2=$((2048 + ${SECTORS1}))
SECTORS2=$((1024 * 1024 * 8 / 512))
START3=$((2048 + ${SECTORS1} + ${SECTORS2}))

cat <<EOF > ${WORK}/part.sfdisk
${IMG}1 : start=${START1}, size=${SECTORS1}, type=b
${IMG}2 : start=${START2}, size=${SECTORS2}, type=53
${IMG}3 : start=${START3}, type=83
EOF

sfdisk ${IMG} < ${WORK}/part.sfdisk

sudo kpartx -av ${IMG}

LOOPDEV=$(losetup -l | grep sd.img | grep -o 'loop.' | tail -n 1)
${REPO}/image/mk_hdr.sh `fdisk -lu /dev/${LOOPDEV} | awk '$6==53 {print $2}'` 1 > ${WORK}/header.bin
dd if=${WORK}/header.bin of=/dev/${LOOPDEV}p2 ibs=512 conv=sync
dd if=${WORK}/lilobin/gen3_1.sb of=/dev/${LOOPDEV}p2 ibs=512 obs=512 seek=1 conv=sync

# sudo mount -o utf8=true /dev/mapper/${LOOPDEV}p1 ${WORK}/p1
# sudo mount /dev/mapper/${LOOPDEV}p2 ${WORK}/p2

sudo kpartx -d ${IMG}

