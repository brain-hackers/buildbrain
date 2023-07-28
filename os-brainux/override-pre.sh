#!/bin/bash

set -uex -o pipefail

SRC=$1
DST=$2

install -g root -o root -m 0644 $SRC/lib/systemd/system/boot.mount $DST/lib/systemd/system/boot.mount
install -g root -o root -m 0644 $SRC/lib/systemd/system/rndis_gadget.service $DST/lib/systemd/system/rndis_gadget.service
install -g root -o root -m 0755 $SRC/usr/bin/enable_rndis_gadget $DST/usr/bin/enable_rndis_gadget
