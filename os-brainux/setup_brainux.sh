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

# locales: locale has to be set before going any further
apt update -y
DEBIAN_FRONTEND=noninteractive \
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

# Install packagecloud repository
# Reference: https://packagecloud.io/brainhackers/brainux/install

# curl, ca-certificates: downloads the GPG key from packagecloud
# gnupg, debian-archive-keyring: packagecloud verification dependency
DEBIAN_FRONTEND=noninteractive \
    apt install -y curl ca-certificates gnupg debian-archive-keyring

# apt-transport-https can be installed after debian-archive-keyring being installed
DEBIAN_FRONTEND=noninteractive \
    apt install -y apt-transport-https

# Install GPG key and packagecloud repository config
mkdir -p /etc/apt/keyrings
curl -fsSL "https://packagecloud.io/brainhackers/brainux/gpgkey" \
    | gpg --dearmor > /etc/apt/keyrings/brainhackers_brainux-archive-keyring.gpg

cat <<EOF > /etc/apt/sources.list.d/packagecloud.list
deb [signed-by=/etc/apt/keyrings/brainhackers_brainux-archive-keyring.gpg] https://packagecloud.io/brainhackers/brainux/any/ any main
deb-src [signed-by=/etc/apt/keyrings/brainhackers_brainux-archive-keyring.gpg] https://packagecloud.io/brainhackers/brainux/any/ any main
EOF

# Fetch packagecloud repository
apt update -y

DEBIAN_FRONTEND=noninteractive \
    apt install -y dialog sudo \
                   libjpeg-dev libfreetype6 libfreetype6-dev zlib1g-dev \
                   xserver-xorg xserver-xorg-video-fbdev xserver-xorg-dev xserver-xorg-input-evdev xinput-calibrator xorg-dev x11-apps x11-ico-dvd xinit \
                   jwm \
                   bash tmux vim htop \
                   midori pcmanfm lxterminal xterm gnome-terminal fbterm uim-fep uim-anthy fonts-noto-cjk \
                   dbus udev alsa-utils usbutils iw fake-hwclock systemd-timesyncd\
                   build-essential flex bison pkg-config autotools-dev libtool autoconf automake device-tree-compiler \
                   python3 python3-dev python3-setuptools python3-wheel python3-pip python3-smbus \
                   resolvconf net-tools ssh openssh-client avahi-daemon wget git \
                   network-manager zip neofetch sl python3-numpy ipython3 netsurf-gtk fcitx-anthy

# Packages from packagecloud
DEBIAN_FRONTEND=noninteractive \
    apt install -y --install-recommends brain-config

systemctl enable fake-hwclock

# Ly
DEBIAN_FRONTEND=noninteractive \
    apt install -y libpam0g-dev libxcb-xkb-dev
cd /
git clone --recurse-submodules -b master-24f017e https://github.com/brain-hackers/ly.git
cd ly
make
make install
make installsystemd
cd /
rm -r ly
systemctl enable ly

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

# Enable /boot mount
systemctl enable boot.mount

# Enable RNDIS gadget
systemctl enable rndis_gadget

# Get wild
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian bullseye main contrib non-free
deb-src http://deb.debian.org/debian bullseye main contrib non-free
deb http://deb.debian.org/debian bullseye-updates main contrib non-free
deb-src http://deb.debian.org/debian bullseye-updates main contrib non-free
deb http://deb.debian.org/debian-security bullseye-security/updates main contrib non-free
deb-src http://deb.debian.org/debian-security bullseye-security/updates main contrib non-free
EOF

