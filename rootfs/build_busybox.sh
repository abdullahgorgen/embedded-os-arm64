#!/bin/bash
set -e

echo "[*] BusyBox arm64 Statik Derleme Basliyor..."

# 1. KORUMA: Çapraz derleyici ortam değişkenlerini iptal et
unset ARCH CROSS_COMPILE AS LD CC CXX AR NM STRIP OBJCOPY OBJDUMP

# 2. KORUMA: Host GCC'nin doğru (x86_64) assembler'ı (as) bulması için PATH'i standartlaştır
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:$PATH

cd /workspace/rootfs
if [ ! -d "busybox-1.36.1" ]; then
    wget -q https://busybox.net/downloads/busybox-1.36.1.tar.bz2
    tar -xjf busybox-1.36.1.tar.bz2
fi

cd busybox-1.36.1

# 3. KORUMA: Eğer önceden yarım kalmış/hatalı bir konfigürasyon varsa temizle
make distclean

echo "[1/4] defconfig olusturuluyor..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig

echo "[2/4] Statik derleme konfigürasyonu uygulaniyor..."
sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config

echo "[3/4] BusyBox derleniyor..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)

echo "[4/4] Kurulum yapiliyor..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CONFIG_PREFIX=../busybox_install install

echo "[*] BusyBox derleme ve kurulum islemi tamamlandi."
