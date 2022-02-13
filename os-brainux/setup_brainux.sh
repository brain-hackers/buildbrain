#!/bin/bash
set -uex -o pipefail

if [ ! -v TIMEZONE ]; then
    TIMEZONE=Asia/Tokyo
fi

if [ ! -v CI ]; then
    CI=false
fi

/debootstrap/debootstrap --second-stage

if [ "${CI}" == "true" ]; then
	REPO=deb.debian.org
	REPO_SECURITY=deb.debian.org
else
	REPO=localhost:65432
	REPO_SECURITY=localhost:65433
fi

cat <<EOF > /etc/apt/sources.list
deb http://${REPO}/debian bullseye main contrib non-free
deb-src http://${REPO}/debian bullseye main contrib non-free
deb http://${REPO}/debian bullseye-updates main contrib non-free
deb-src http://${REPO}/debian bullseye-updates main contrib non-free
deb http://${REPO_SECURITY}/debian-security bullseye-security/updates main contrib non-free
deb-src http://${REPO_SECURITY}/debian-security bullseye-security/updates main contrib non-free
EOF

cat <<EOF > /etc/apt/apt.conf.d/90-norecommend
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

apt update -y
apt install -y locales

echo "$TIMEZONE" > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="en_US.UTF-8"' > /etc/default/locale && \
    dpkg-reconfigure -f noninteractive locales && \
    update-locale LANG=en_US.UTF-8

LANG=en_US.UTF-8

rm /etc/localtime
ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

echo "brain" > /etc/hostname
DEBIAN_FRONTEND=noninteractive \
    apt install -y dialog sudo \
                   libjpeg-dev libfreetype6 libfreetype6-dev zlib1g-dev \
                   xserver-xorg xserver-xorg-video-fbdev xserver-xorg-dev xserver-xorg-input-evdev xinput-calibrator xorg-dev x11-apps xinit \
                   jwm \
                   weston xwayland \
                   bash tmux vim htop \
                   midori pcmanfm lxterminal xterm gnome-terminal fbterm uim-fep uim-anthy fonts-noto-cjk \
                   dbus udev alsa-utils usbutils iw fake-hwclock\
                   build-essential flex bison pkg-config autotools-dev libtool autoconf automake device-tree-compiler \
                   python3 python3-dev python3-setuptools python3-wheel python3-pip python3-smbus \
                   resolvconf net-tools ssh openssh-client avahi-daemon curl wget git

DEBIAN_FRONTEND=noninteractive \
    apt install -y --install-recommends fcitx-anthy

systemctl enable fake-hwclock

# Ly
apt install -y libpam0g-dev libxcb-xkb-dev
cd /
git clone --recurse -submodules https://github.com/nullgemm/ly.git
cd ly
make
make install
systemctl enable ly.service
systemctl disable getty@tty2.service
cd /
rm -r ly

# Create editable xorg.conf.d
install -m 0777 -d /etc/X11/xorg.conf.d

# Fix Midori launch failure
sudo update-mime-database /usr/share/mime

# Setup users
adduser --gecos "" --disabled-password --home /home/user user
echo user:brain | chpasswd
echo "user ALL=(ALL:ALL) ALL" > /etc/sudoers.d/user
echo -e "127.0.1.1\tbrain" >> /etc/hosts

echo root:root | chpasswd

# Fix Xorg permission for non-root users
# https://unix.stackexchange.com/questions/315169/how-can-i-run-usr-bin-xorg-without-sudo
chown root:input /usr/lib/xorg/Xorg
chmod g+s /usr/lib/xorg/Xorg
usermod -a -G video user

# Allow root login via UART
cat <<EOF >> /etc/securetty
ttymxc0
ttyLP0
EOF

# Get wild
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian bullseye main contrib non-free
deb-src http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian-security bullseye-security/updates main contrib non-free
deb-src http://deb.debian.org/debian-security bullseye-security/updates main contrib non-free
EOF

