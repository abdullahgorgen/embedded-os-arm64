FROM ubuntu:22.04

# Uyarıları susturmak için frontend ayarı
ENV DEBIAN_FRONTEND=noninteractive

# Tek, birleştirilmiş ve eksiksiz paket kurulumu (Docker Best-Practice)
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    musl-tools \
    qemu-system-arm \
    qemu-user-static \
    binfmt-support \
    libncurses-dev \
    libssl-dev \
    flex \
    bison \
    bc \
    cpio \
    file \
    e2fsprogs \
    curl \
    wget \
    git \
    nano \
    vim \
    strace \
    gdb-multiarch \
    device-tree-compiler \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Host kullanıcısıyla aynı ID ile çalışan kullanıcı (Yetki sorunlarını çözer)
ARG UID=1000
ARG GID=1000
RUN groupadd -g ${GID} developer || true && \
    useradd -m -u ${UID} -g ${GID} developer || true

# QEMU arm64 emülasyonunu etkinleştir
RUN update-binfmts --enable qemu-aarch64-static || true

# Çapraz derleme araçları için yol (PATH) ve ortam değişkenleri
ENV PATH="/usr/aarch64-linux-gnu/bin:${PATH}"
ENV CC=aarch64-linux-gnu-gcc
ENV CXX=aarch64-linux-gnu-g++
ENV AR=aarch64-linux-gnu-ar
ENV CROSS_COMPILE=aarch64-linux-gnu-
ENV ARCH=arm64

CMD ["/bin/bash"]
