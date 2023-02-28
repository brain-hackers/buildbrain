#!/bin/bash
set -uex -o pipefail

/debootstrap/debootstrap --second-stage

# cat <<EOF > /etc/apt/sources.list
# deb http://deb.debian.org/debian bullseye main contrib non-free
# deb-src http://deb.debian.org/debian bullseye main contrib non-free
# deb http://deb.debian.org/debian bullseye-updates main contrib non-free
# deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free
# deb http://deb.debian.org/debian-security bullseye-security/updates main contrib non-free
# deb-src http://deb.debian.org/debian-security bullseye-security/updates main contrib non-free
# EOF

# cat <<EOF > /etc/apt/apt.conf.d/90-norecommend
# APT::Install-Recommends "0";
# APT::Install-Suggests "0";
# EOF

# locales: locale has to be set before going any further
apt update -y
DEBIAN_FRONTEND=noninteractive \
    apt install -y locales bash

echo "Asia/Tokyo" > /etc/timezone
rm /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
echo 'LANG="en_US.UTF-8"' > /etc/default/locale
dpkg-reconfigure -f noninteractive locales
update-locale LANG=en_US.UTF-8

LANG=en_US.UTF-8

echo "brain" > /etc/hostname

# apt install -y sudo

# Network
# apt install -y ca-certificates fake-hwclock systemd-timesyncd net-tools ssh avahi-daemon network-manager
# systemctl enable fake-hwclock

# Setup users
# adduser --gecos "" --disabled-password --home /home/user user
# echo user:brain | chpasswd
# echo "user ALL=(ALL:ALL) ALL" > /etc/sudoers.d/user
echo -e "127.0.1.1\tbrain" >> /etc/hosts

echo root:root | chpasswd
