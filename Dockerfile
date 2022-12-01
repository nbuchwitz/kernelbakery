ARG DEBIAN_RELEASE=bullseye
ARG DEBIAN_FRONTEND=noninteractive

FROM debian:${DEBIAN_RELEASE}-slim as base

LABEL maintainer="Revolution Pi Team <development@revolutionpi.com>"

RUN apt-get update && \
    apt-get install -y \
    device-tree-compiler \
    build-essential:native debhelper quilt bc \
    kmod rsync bison flex libssl-dev \
    git eatmydata && \
    apt-get install -y --no-install-recommends devscripts && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM base as build

RUN install -d /build

COPY boot /build/kernelbakery/boot
COPY debian /build/kernelbakery/debian

COPY build.sh /build.sh

CMD "/build.sh"

FROM build as build-native
# The following lines will be omitted in later stages,
# if they don't reference the build-native stage as their base.
# With this intermediate stage the native kernelbakery container
# can be build from the same Dockerfile like this:
# docker build . --target build-native
CMD ["sh", "-c", "ARCH=$(uname -m) /build.sh"]

FROM build as build-cross

RUN apt-get update && \
    apt-get install -y \
    gcc-arm-linux-gnueabihf \
    gcc-aarch64-linux-gnu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

