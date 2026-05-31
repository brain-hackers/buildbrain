# TOOLCHAIN_PLATFORM is pinned to linux/amd64 so the ARM cross-compilers and
# qemu-user-static are always x86_64 binaries, matching the tested path.
# Passing `--platform` through an ARG silences the Docker linter warning about
# constant --platform values while keeping the behaviour identical.
ARG TOOLCHAIN_PLATFORM=linux/amd64
FROM --platform=${TOOLCHAIN_PLATFORM} debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# Toolchain and utilities needed by build targets in this repository.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bc \
    bison \
    build-essential \
    ca-certificates \
    cpio \
    debootstrap \
    dosfstools \
    e2fsprogs \
    fdisk \
    file \
    flex \
    gcc-arm-linux-gnueabi \
    gcc-arm-linux-gnueabihf \
    git \
    kmod \
    kpartx \
    libncurses-dev \
    libssl-dev \
    libyaml-dev \
    lzop \
    make \
    parted \
    python3 \
    python3-pyelftools \
    python3-venv \
    qemu-user-static \
    rsync \
    sudo \
    unzip \
    util-linux \
    u-boot-tools \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# brainlilo requires arm-mingw32ce toolchain from cegcc-build releases.
RUN wget -q -O /tmp/cegcc.zip https://github.com/brain-hackers/cegcc-build/releases/download/2022-04-11-133546/cegcc-2022-04-11-133546.zip \
    && unzip -q /tmp/cegcc.zip -d /tmp \
    && mkdir -p /opt \
    && mv /tmp/cegcc /opt/cegcc \
    && rm -rf /tmp/cegcc.zip

WORKDIR /work

# Keep entrypoint simple so callers can pass arbitrary make targets.
CMD ["bash"]
