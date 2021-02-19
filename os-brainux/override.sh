#!/bin/bash

set -uex -o pipefail

SRC=$1
DST=$2

install -g root -o root -m 0644 $SRC/usr/lib/os-release $DST/usr/lib/os-release
install -g root -o root -m 0644 $SRC/etc/issue $DST/etc/issue
install -g root -o root -m 0644 $SRC/etc/issue.net $DST/etc/issue.net
install -g root -o root -m 0644 $SRC/etc/motd $DST/etc/motd
