#!/bin/bash
set -e

# PANZEHİR: PATH Zehirlenmesini temizle ve sistemi standart yollara geri döndür.
# Çapraz derleyiciler (/usr/bin) içinde zaten takılarıyla (aarch64-) duruyor, onları oradan bulacak.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

WORK_DIR=$(pwd)
KERNEL_VERSION="6.1.75"
KERNEL_DIR="${WORK_DIR}/linux-${KERNEL_VERSION}"
KERNEL_BUILD_DIR="${KERNEL_DIR}/build"

echo "==========================================="
echo "  Kusursuz Kernel Derleme (Zehrin Panzehiri)"
echo "==========================================="

echo "[1/4] Kaynak kod arşivden çıkarılıyor (eski kalıntılar siliniyor)..."
rm -rf "$KERNEL_DIR"
tar xf "linux-${KERNEL_VERSION}.tar.xz"

mkdir -p "$KERNEL_BUILD_DIR"
cd "$KERNEL_DIR"

echo "[2/4] Kernel konfigürasyonu yapılıyor (HOSTCC devrede)..."
make O="$KERNEL_BUILD_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc HOSTCXX=g++ defconfig > /dev/null

echo "[3/4] QEMU Virtio ayarları kernel'a gömülüyor..."
sed -i 's/^# CONFIG_PROC_FS is not set/CONFIG_PROC_FS=y/' "$KERNEL_BUILD_DIR/.config" || true
echo "CONFIG_SYSFS=y" >> "$KERNEL_BUILD_DIR/.config"
echo "CONFIG_EXT4_FS=y" >> "$KERNEL_BUILD_DIR/.config"
echo "CONFIG_SERIAL_AMBA=y" >> "$KERNEL_BUILD_DIR/.config"
echo "CONFIG_VIRTIO=y" >> "$KERNEL_BUILD_DIR/.config"
echo "CONFIG_VIRTIO_BLK=y" >> "$KERNEL_BUILD_DIR/.config"

echo "[4/4] Çekirdek derleniyor (Bilgisayarın fanları hızlanabilir, 5-10 dk)..."
make O="$KERNEL_BUILD_DIR" ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc HOSTCXX=g++ -j$(nproc) Image

cp "$KERNEL_BUILD_DIR/arch/arm64/boot/Image" "$WORK_DIR/Image"
echo "==========================================="
echo "✓ ZAFER! KERNEL DERLEME TAMAMLANDI!"
echo "==========================================="
