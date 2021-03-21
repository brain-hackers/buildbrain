#!/bin/bash
set -uex -o pipefail

TIMEZONE="Asia/Tokyo"

/debootstrap/debootstrap --second-stage

if [ "${CI}" == "true" ]; then
	REPO=deb.debian.org
	REPO_SECURITY=deb.debian.org
else
	REPO=localhost:65432
	REPO_SECURITY=localhost:65433
fi

cat <<EOF > /etc/apt/sources.list
deb http://${REPO}/debian buster main contrib non-free
deb-src http://${REPO}/debian buster main contrib non-free
deb http://${REPO}/debian buster-updates main contrib non-free
deb-src http://${REPO}/debian buster-updates main contrib non-free
deb http://${REPO_SECURITY}/debian-security buster/updates main contrib non-free
deb-src http://${REPO_SECURITY}/debian-security buster/updates main contrib non-free
EOF

cat <<EOF > /etc/apt/apt.conf.d/90-norecommend
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

apt update -y
apt install -y locales

echo "$TIMEZONE" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_us.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="en_US.UTF-8"' > /etc/default/locale && \
    dpkg-reconfigure -f noninteractive locales && \
    update-locale LANG=en_US.UTF-8

echo "brain" > /etc/hostname


echo root:root | chpasswd

cat <<EOF >> /etc/securetty
ttymxc0
EOF

DEBIAN_FRONTEND=noninteractive \
    apt install -y dialog sudo \
                   libjpeg-dev libfreetype6 libfreetype6-dev zlib1g-dev \
                   xserver-xorg xserver-xorg-video-fbdev xserver-xorg-dev xorg-dev x11-apps \
                   openbox obconf obmenu \
                   weston xwayland \
                   alsa-utils \
                   bash tmux vim htop \
                   midori pcmanfm lxterminal xterm gnome-terminal fonts-noto-cjk \
                   dbus udev build-essential flex bison pkg-config autotools-dev libtool autoconf automake device-tree-compiler\
                   python3 python3-dev python3-setuptools python3-wheel python3-pip python3-smbus \
                   resolvconf net-tools ssh openssh-client avahi-daemon curl wget

# Fix Midori launch failure
sudo update-mime-database /usr/share/mime

# Get wild
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian buster main contrib non-free
deb-src http://deb.debian.org/debian buster main contrib non-free
deb http://deb.debian.org/debian buster-updates main contrib non-free
deb-src http://deb.debian.org/debian buster-updates main contrib non-free
deb http://deb.debian.org/debian-security buster/updates main contrib non-free
deb-src http://deb.debian.org/debian-security buster/updates main contrib non-free
EOF

