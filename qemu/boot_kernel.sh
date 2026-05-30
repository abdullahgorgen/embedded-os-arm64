#!/bin/bash

# QEMU arm64 Kernel Boot Script

set -e

WORK_DIR=$(pwd)
KERNEL_IMAGE="${WORK_DIR}/Image"
ROOTFS_IMG="${WORK_DIR}/../rootfs/rootfs.img"

# Renklendirme
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  QEMU arm64 Boot - Sistem İzleyici        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Dosya kontrolleri
if [ ! -f "$KERNEL_IMAGE" ]; then
    echo -e "${RED}✗ Kernel Image bulunamadı: $KERNEL_IMAGE${NC}"
    exit 1
fi

if [ ! -f "$ROOTFS_IMG" ]; then
    echo -e "${RED}✗ RootFS bulunamadı: $ROOTFS_IMG${NC}"
    exit 1
fi

# Kernel bilgisi
echo -e "${YELLOW}Kernel Bilgisi:${NC}"
file "$KERNEL_IMAGE"
ls -lh "$KERNEL_IMAGE"
echo ""

echo -e "${YELLOW}RootFS Bilgisi:${NC}"
file "$ROOTFS_IMG"
ls -lh "$ROOTFS_IMG"
echo ""

# Boot mesajı
echo -e "${YELLOW}Boot Komutu:${NC}"
echo "qemu-system-aarch64 \\"
echo "  -machine virt \\"
echo "  -cpu cortex-a72 \\"
echo "  -m 512M \\"
echo "  -smp 2 \\"
echo "  -kernel $KERNEL_IMAGE \\"
echo "  -drive file=$ROOTFS_IMG,format=raw,if=virtio \\"
echo "  -append \"root=/dev/vda rw console=ttyAMA0 earlycon init=/init\" \\"
echo "  -nographic"
echo ""

echo -e "${YELLOW}[*] QEMU başlatılıyor...${NC}"
echo -e "${YELLOW}[*] Shell prompt'ı görmek için biraz bekleyin${NC}"
echo -e "${YELLOW}[*] Monitor uygulaması: /usr/bin/monitor${NC}"
echo -e "${YELLOW}[*] Çıkmak için: Ctrl+A X${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# QEMU boot (Redundant -serial stdio parametresi kaldırıldı)
qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -m 512M \
    -smp 2 \
    -kernel "$KERNEL_IMAGE" \
    -drive file="$ROOTFS_IMG",format=raw,if=virtio \
    -append "root=/dev/vda rw console=ttyAMA0 earlycon init=/init" \
    -nographic

echo ""
echo -e "${GREEN}✓ QEMU kapatıldı${NC}"
