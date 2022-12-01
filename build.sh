#!/bin/bash

set -x
set -e

export ARCH=${ARCH:-arm}
export DEBIAN_FRONTEND=noninteractive
export LD_PRELOAD=libeatmydata.so
export LD_LIBRARY_PATH=/usr/lib/libeatmydata

GIT_KERNEL_REPO=${GIT_KERNEL_REPO:-"https://gitlab.com/RevolutionPi/linux"}
GIT_KERNEL_BRANCH=${GIT_KERNEL_BRANCH:-"revpi-6.1"}
GIT_PICONTROL_REPO=${GIT_PICONTROL_REPO:-"https://gitlab.com/RevolutionPi/piControl"}
GIT_PICONTROL_BRANCH=${GIT_PICONTROL_BRANCH:-"master"}

RELEASE_PACKAGES=${RELEASE_PACKAGES:-0}
CHANGELOG_AUTHOR=$(whoami)
CHANGELOG_AUTHOR_EMAIL=$CHANGELOG_AUTHOR@$(hostname -f)

if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    ARCH=arm64
    DPKG_ARCH=arm64
else
    ARCH=arm
    DPKG_ARCH=armhf
fi

BUILD_DIR='/build'

if [[ ! -d "${BUILD_DIR}/piControl" ]]; then
    git clone --depth 1 -b "$GIT_PICONTROL_BRANCH" "$GIT_PICONTROL_REPO" ${BUILD_DIR}/piControl
else
    git config --global --add safe.directory /build/piControl
fi

if [[ ! -d "${BUILD_DIR}/linux" ]]; then
    git clone --depth 1 -b "$GIT_KERNEL_BRANCH" "$GIT_KERNEL_REPO" ${BUILD_DIR}/linux
else
    git config --global --add safe.directory /build/linux
fi

cd ${BUILD_DIR}/kernelbakery

if [[ $RELEASE_PACKAGES -eq 0 ]]; then
    LAST_VERSION=$(dpkg-parsechangelog --show-field Version)
    VERSION=$(echo "$LAST_VERSION" | cut -d \+ -f 1)
    SUFFIX=$(echo "$LAST_VERSION" | cut -d \+ -f 2)

    if [[ -z ${VERSION_SUFFIX+x} ]]; then
        BUILD_DATE=$(date "+%Y%m%d")
        BUILD_COMMIT_KERNEL=$(cd ../linux && git rev-parse --short=8 HEAD)
        BUILD_COMMIT_PICONTROL=$(cd ../piControl && git rev-parse --short=8 HEAD)
        VERSION_SUFFIX="${BUILD_DATE}+1-${BUILD_COMMIT_KERNEL}${BUILD_COMMIT_PICONTROL}-1"

	KERNEL_VERSION=$(cd /build/linux && make kernelversion)
    fi

    DEBIAN_VERSION=$(cat /etc/debian_version | cut -f 1 -d \.)
    RELEASE_SUFFIX="revpi${DEBIAN_VERSION}+1"
    NEW_VERSION="${VERSION}-${VERSION_SUFFIX}+1-${KERNEL_VERSION}-1+${RELEASE_SUFFIX}"

    export NAME=${CHANGELOG_AUTHOR}
    export EMAIL=${CHANGELOG_AUTHOR_EMAIL}

    debchange --newversion="${NEW_VERSION}" -u medium -D experimental "This is a non-release build and not meant for productive use"
    debchange -a "kernel commit id ${BUILD_COMMIT_KERNEL}"
    debchange -a "piControl commit id ${BUILD_COMMIT_KERNEL}"

    head -n 10 debian/changelog
fi

LINUXDIR=$PWD/../linux PIKERNELMODDIR=$PWD/../piControl debian/update.sh

dpkg-buildpackage -a "$DPKG_ARCH" -b -us -uc

# Move artifacts to mounted volume (if present)
if [[ -d /output ]]; then
	mv ../raspberrypi-{kernel,firmware}* /output
fi
