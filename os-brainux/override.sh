#!/bin/bash

set -uex -o pipefail

SRC=$1
DST=$2

install -g root -o root -m 0644 $SRC/usr/lib/os-release $DST/usr/lib/os-release
install -g root -o root -m 0644 $SRC/etc/issue $DST/etc/issue
install -g root -o root -m 0644 $SRC/etc/issue.net $DST/etc/issue.net
install -g root -o root -m 0644 $SRC/etc/motd $DST/etc/motd

install -g root -o root -m 0644 $SRC/etc/X11/xorg.conf $DST/etc/X11/xorg.conf
install -g root -o root -m 0644 $SRC/etc/X11/Xsession.d/96calibrate $DST/etc/X11/Xsession.d/96calibrate

install -g root -o root -m 0644 -D $SRC/etc/xdg/weston/weston.ini $DST/etc/xdg/weston/weston.ini

install -g root -o root -m 0644 -D $SRC/home/user/lxterminal/lxterminal.conf $DST/home/user/lxterminal/lxterminal.conf
install -g root -o root -m 0644 -D $SRC/etc/jwm/system.jwmrc $DST/etc/jwm/system.jwmrc
