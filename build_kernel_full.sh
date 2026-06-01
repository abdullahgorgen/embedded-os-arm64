#!/bin/bash
# ===================================================================
# build_kernel_full.sh — Otonom Çekirdek İndirme ve Tam Derleme Betiği
# ===================================================================

WORK_DIR=$(pwd)
IMAGE_NAME="arm64-embedded-dev:latest"
KERNEL_VERSION="6.1.75"
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"
KERNEL_DIR="/workspace/qemu/linux-${KERNEL_VERSION}"
TARGET_IMAGE="${WORK_DIR}/qemu/Image"

# Renk kodları
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Otonom Kernel Tedarik ve Derleme Süreci${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}[HATA] Docker daemon çalışmıyor veya yetki yok.${NC}"
    exit 1
fi

docker run --rm -it --privileged \
    -v "${WORK_DIR}:/workspace" \
    "$IMAGE_NAME" \
    bash -c "
        set -e
        # Ortam İzolasyonu: PATH zehirlenmesini engelle
        export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        
        cd /workspace/qemu

        # 1. Kaynak Kod Tedariki ve Ayıklama
        if [ ! -d \"linux-${KERNEL_VERSION}\" ]; then
            echo '[*] Çekirdek dizini bulunamadı. Tedarik ediliyor...'
            if [ ! -f \"${KERNEL_TAR}\" ]; then
                echo '[*] Kaynak arşivi indiriliyor (wget)...'
                wget -q --show-progress ${KERNEL_URL}
            fi
            echo '[*] Arşiv çıkartılıyor (Bu işlem zaman alabilir)...'
            tar -xf ${KERNEL_TAR}
        else
            echo '[*] Çekirdek kaynak kodu halihazırda mevcut. İndirme atlanıyor.'
        fi

        cd linux-${KERNEL_VERSION}

        # 2. Varsayılan Yapılandırma
        echo '[*] Yapılandırma (defconfig) oluşturuluyor...'
        make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc HOSTCXX=g++ defconfig > /dev/null

        # 3. QEMU Virtio ve Dosya Sistemi Enjeksiyonları
        echo '[*] QEMU donanım modülleri çekirdek yapılandırmasına enjekte ediliyor...'
        sed -i 's/^# CONFIG_PROC_FS is not set/CONFIG_PROC_FS=y/' .config || true
        echo 'CONFIG_SYSFS=y' >> .config
        echo 'CONFIG_EXT4_FS=y' >> .config
        echo 'CONFIG_SERIAL_AMBA=y' >> .config
        echo 'CONFIG_VIRTIO=y' >> .config
        echo 'CONFIG_VIRTIO_BLK=y' >> .config

        # 4. Çapraz Derleme İşlemi
        echo '[*] Image ve modüller derleniyor (Multithread)...'
        make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- HOSTCC=gcc HOSTCXX=g++ -j\$(nproc) Image modules

        # 5. Çıktının Taşınması
        echo '[*] Derlenmiş Kernel (Image) qemu ana dizinine kopyalanıyor...'
        cp arch/arm64/boot/Image /workspace/qemu/Image
    "

BUILD_RESULT=$?

echo -e "${BLUE}═══════════════════════════════════════════${NC}"

if [ $BUILD_RESULT -eq 0 ] && [ -f "$TARGET_IMAGE" ]; then
    IMAGE_SIZE=$(du -h "$TARGET_IMAGE" | cut -f1)
    echo -e "${GREEN}[✓] Otonom Kernel Derleme BAŞARILI!${NC}"
    echo -e "Çıktı Konumu : $TARGET_IMAGE"
    echo -e "Dosya Boyutu : $IMAGE_SIZE"
else
    echo -e "${RED}[✗] Kernel derleme BAŞARISIZ veya süreç kesintiye uğradı.${NC}"
    exit 1
fi
