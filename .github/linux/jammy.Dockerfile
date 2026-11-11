# Cone's Linux build image on Ubuntu 22.04 (glibc 2.35), so the packages run on Ubuntu 22.04,
# Linux Mint 21, Debian 12 and every newer system (redesign/LINUX_OLDER_DISTROS_NOTES.md).
# The libraries VLC uses come from Ubuntu 22.04 (they meet VLC 4's minimums: FFmpeg 4.4 is
# libavcodec 58.134 / libavformat 58.76, libplacebo 4.192); Qt is the official Qt 6.8.3 for
# Linux (Ubuntu 22.04 has Qt 6.2, the interface needs 6.8, like the Windows build), installed
# with aqtinstall into /opt/qt. Built by .github/workflows/build-linux.yml.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

# apt retries a failed download, and "apt-get update --error-on=any" stops at a package list it
# could not fetch (with the reason) instead of going on to "Unable to locate package"
RUN echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries

# The Ubuntu archive to install from. build-linux.yml passes the runner's own mirror (Azure's copy
# of the archive): from GitHub's runners archive.ubuntu.com and security.ubuntu.com stopped
# resolving (build-linux #106-#112, "Temporary failure resolving"), while the runner's mirror
# works. Without the argument (a local build) Ubuntu's own archive is used.
ARG UBUNTU_MIRROR=
RUN if [ -n "$UBUNTU_MIRROR" ]; then \
      sed -i -e "s|http://archive.ubuntu.com/ubuntu/\?|$UBUNTU_MIRROR|" \
             -e "s|http://security.ubuntu.com/ubuntu/\?|$UBUNTU_MIRROR|" /etc/apt/sources.list; \
    fi \
 && grep -v '^#' /etc/apt/sources.list | grep .

RUN apt-get update --error-on=any && apt-get install -y --no-install-recommends \
    ca-certificates curl git file patch xz-utils bzip2 unzip python3 python3-pip \
    gcc g++ make autoconf automake libtool gettext autopoint pkg-config cmake meson ninja-build \
    nasm yasm bison flex gperf ragel \
    libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libswresample-dev libpostproc-dev \
    liba52-0.7.4-dev libaom-dev libarchive-dev libasound2-dev libass-dev libavahi-client-dev \
    libbluray-dev libcaca-dev libcddb2-dev libchromaprint-dev libdav1d-dev libdbus-1-dev \
    libdca-dev libdvbpsi-dev libdvdnav-dev libdvdread-dev libebml-dev libmatroska-dev \
    libegl-dev libgl-dev libgles-dev libegl1-mesa-dev libgbm-dev libdrm-dev \
    libfaad-dev libflac-dev libfluidsynth-dev libfreetype-dev libfribidi-dev libfontconfig-dev \
    libgcrypt20-dev libgme-dev libgnutls28-dev libharfbuzz-dev \
    libjack-jackd2-dev libkate-dev liblua5.2-dev lua5.2 libmad0-dev \
    libmodplug-dev libmpcdec-dev libmpeg2-4-dev libmpg123-dev libmtp-dev libmysofa-dev \
    libncurses-dev libnfs-dev libnotify-dev libogg-dev libopenmpt-dev libopus-dev \
    libplacebo-dev libpng-dev libjpeg-dev libprotobuf-dev protobuf-compiler libpulse-dev \
    libpipewire-0.3-dev libspa-0.2-dev libraw1394-dev libavc1394-dev libdc1394-dev \
    libsamplerate0-dev libsecret-1-dev libshine-dev libshout3-dev libsmbclient-dev \
    libsndio-dev libsoxr-dev libspatialaudio-dev libspeex-dev libspeexdsp-dev libsrt-gnutls-dev \
    libssh2-1-dev libsystemd-dev libtag1-dev libtheora-dev libtwolame-dev libudev-dev \
    libupnp-dev libv4l-dev libva-dev libvdpau-dev libvorbis-dev libvpx-dev \
    libwayland-dev wayland-protocols libx264-dev libx265-dev libxkbcommon-dev libxkbcommon-x11-dev \
    libx11-dev libx11-xcb-dev libxcb1-dev libxcb-shm0-dev libxcb-xv0-dev libxcb-keysyms1-dev \
    libxcb-damage0-dev libxcb-xfixes0-dev libffmpeg-nvenc-dev \
    libxcb-randr0-dev libxcb-composite0-dev libxcb-xkb-dev libxcb-cursor-dev libxcb-icccm4-dev \
    libxcb-image0-dev libxcb-render-util0-dev libxcb-xinerama0-dev libxcb-xinput-dev \
    libxinerama-dev libxext-dev libxi-dev libxpm-dev libxml2-dev libzvbi-dev libvulkan-dev \
    libsqlite3-dev zlib1g-dev libgtk-3-dev librsvg2-dev libvncserver-dev liblirc-dev \
    libopengl-dev libglx-dev \
 && rm -rf /var/lib/apt/lists/*

# VLC's Wayland code needs wayland-scanner 1.23 and wayland-protocols 1.33 (Ubuntu 22.04 has 1.20
# and 1.25): the scanner and the protocol files only, from source. VLC still links Ubuntu 22.04's
# libwayland-client 1.20, so it uses nothing older systems lack; the package takes the system's
ARG WAYLAND_VERSION=1.23.1
ARG WAYLAND_SHA256=864fb2a8399e2d0ec39d56e9d9b753c093775beadc6022ce81f441929a81e5ed
ARG WAYLAND_PROTOCOLS_VERSION=1.41
ARG WAYLAND_PROTOCOLS_SHA256=2786b6b1b79965e313f2c289c12075b9ed700d41844810c51afda10ee329576b
RUN cd /tmp \
 && curl -sSLf -o wayland.tar.xz "https://gitlab.freedesktop.org/wayland/wayland/-/releases/${WAYLAND_VERSION}/downloads/wayland-${WAYLAND_VERSION}.tar.xz" \
 && echo "${WAYLAND_SHA256}  wayland.tar.xz" | sha256sum -c - \
 && tar xf wayland.tar.xz && cd "wayland-${WAYLAND_VERSION}" \
 && meson setup build --prefix=/usr/local -Dlibraries=false -Ddocumentation=false -Dtests=false -Ddtd_validation=false \
 && ninja -C build install && cd /tmp \
 && curl -sSLf -o wp.tar.xz "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/${WAYLAND_PROTOCOLS_VERSION}/downloads/wayland-protocols-${WAYLAND_PROTOCOLS_VERSION}.tar.xz" \
 && echo "${WAYLAND_PROTOCOLS_SHA256}  wp.tar.xz" | sha256sum -c - \
 && tar xf wp.tar.xz && cd "wayland-protocols-${WAYLAND_PROTOCOLS_VERSION}" \
 && meson setup build --prefix=/usr/local -Dtests=false \
 && ninja -C build install \
 && rm -rf /tmp/wayland* /tmp/wp.tar.xz

# Qt 6.8.3, the version Cone uses on Windows (qmlcheck checks against it too): the essentials
# (qtbase, qtdeclarative, qtsvg, qtwayland, ICU) and qtshadertools for qsb
ARG AQT_VERSION=3.2.1
ARG QT_VERSION=6.8.3
RUN pip3 install --no-cache-dir "aqtinstall==${AQT_VERSION}" \
 && aqt install-qt linux desktop "${QT_VERSION}" linux_gcc_64 -O /opt/qt -m qtshadertools qtimageformats \
 && ln -s qmake /opt/qt/${QT_VERSION}/gcc_64/bin/qmake6 2>/dev/null || true \
 && rm -rf /root/.cache

ENV QT_DIR=/opt/qt/6.8.3/gcc_64
ENV PATH=/opt/qt/6.8.3/gcc_64/bin:$PATH \
    PKG_CONFIG_PATH=/opt/qt/6.8.3/gcc_64/lib/pkgconfig:/usr/local/share/pkgconfig:/usr/local/lib/x86_64-linux-gnu/pkgconfig
