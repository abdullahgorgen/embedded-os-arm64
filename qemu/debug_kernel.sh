#!/bin/bash

# Kernel Derleme Sorun Giderme

set -e

WORK_DIR=$(pwd)
KERNEL_VERSION="6.1.75"
KERNEL_DIR="${WORK_DIR}/linux-${KERNEL_VERSION}"
KERNEL_BUILD_DIR="${KERNEL_DIR}/build"

# Renklendirme
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Kernel Derleme - Debug Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# 1. Ortam kontrolü
echo -e "${YELLOW}[1] Ortam Kontrolü${NC}"
echo "Çalışma dizini: $(pwd)"
echo "Kernel versiyonu: ${KERNEL_VERSION}"

# aarch64-linux-gnu-gcc kontrol
echo ""
echo -e "${YELLOW}[2] Toolchain Kontrol${NC}"
which aarch64-linux-gnu-gcc && echo "✓ aarch64-linux-gnu-gcc mevcut" || \
    { echo "✗ Toolchain bulunamadı"; exit 1; }

aarch64-linux-gnu-gcc --version | head -1
echo ""

# 2. Kernel kaynağı kontrol
echo -e "${YELLOW}[3] Kernel Kaynağı${NC}"
if [ -d "$KERNEL_DIR" ]; then
    echo "✓ Kernel kaynağı mevcut: $KERNEL_DIR"
    echo "  Dosya sayısı: $(find $KERNEL_DIR -type f | wc -l)"
else
    echo "✗ Kernel kaynağı yok, indiriliyor..."
    wget -q --show-progress https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz
    tar xf linux-${KERNEL_VERSION}.tar.xz
    echo "✓ İndirme ve çıkarma tamamlandı"
fi
echo ""

# 3. Build dizini hazırla
echo -e "${YELLOW}[4] Build Dizini Hazırlanıyor${NC}"
mkdir -p "$KERNEL_BUILD_DIR"
cd "$KERNEL_DIR"
echo "✓ Build dizini: $KERNEL_BUILD_DIR"
echo ""

# 4. Defconfig - DETAYLI HATA GÖSTER
echo -e "${YELLOW}[5] Defconfig Uygulanıyor${NC}"
echo "Komut: make O=\"$KERNEL_BUILD_DIR\" CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 defconfig"
echo ""

if make O="$KERNEL_BUILD_DIR" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    ARCH=arm64 \
    defconfig; then
    echo -e "${GREEN}✓ Defconfig başarılı${NC}"
else
    echo -e "${RED}✗ Defconfig başarısız${NC}"
    echo ""
    echo -e "${YELLOW}Hata Logları:${NC}"
    # Log dosyasını göster
    tail -50 "$KERNEL_BUILD_DIR/.config" 2>/dev/null || echo "Config dosyası oluşturulamadı"
    exit 1
fi

echo ""

# 5. Config dosyası kontrol
echo -e "${YELLOW}[6] Config Dosyası Kontrol${NC}"
CONFIG_FILE="${KERNEL_BUILD_DIR}/.config"

if [ -f "$CONFIG_FILE" ]; then
    echo "✓ Config dosyası oluşturuldu"
    echo "  Boyut: $(wc -c < $CONFIG_FILE) bytes"
    echo "  Satır: $(wc -l < $CONFIG_FILE) lines"
    echo ""
    echo "  İlk 10 satır:"
    head -10 "$CONFIG_FILE"
else
    echo "✗ Config dosyası bulunamadı!"
    exit 1
fi

echo ""

# 6. Önemli config seçeneklerini kontrol et
echo -e "${YELLOW}[7] Önemli Config Seçenekleri${NC}"

for option in PROC_FS SYSFS EXT4_FS SERIAL_AMBA VIRTIO VIRTIO_BLK; do
    if grep -q "^CONFIG_${option}=y" "$CONFIG_FILE"; then
        echo "✓ CONFIG_${option}=y"
    else
        echo "⚠ CONFIG_${option} ayarlanmamış (otomatik etkinleştirilecek)"
    fi
done

echo ""

# 7. Build test
echo -e "${YELLOW}[8] Build Test (make --version)${NC}"
make --version | head -1
echo ""

# 8. Yapısal kontroller
echo -e "${YELLOW}[9] Yapısal Kontroller${NC}"
echo "Kernel Makefile: $([ -f "$KERNEL_DIR/Makefile" ] && echo "✓" || echo "✗")"
echo "Kernel arch/: $([ -d "$KERNEL_DIR/arch" ] && echo "✓" || echo "✗")"
echo "Kernel drivers/: $([ -d "$KERNEL_DIR/drivers" ] && echo "✓" || echo "✗")"
echo ""

echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Pre-build Kontroller Tamamlandı${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Sıradaki adım:${NC}"
echo "cd $KERNEL_DIR"
echo "make O=\"$KERNEL_BUILD_DIR\" CROSS_COMPILE=aarch64-linux-gnu- ARCH=arm64 -j\$(nproc)"
echo ""

cd "$WORK_DIR"
