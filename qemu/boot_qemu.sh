#!/bin/bash

# QEMU arm64 Boot Script

set -e

WORK_DIR=$(pwd)
ROOTFS_IMG="${WORK_DIR}/../rootfs/rootfs.img"
KERNEL_IMG="${WORK_DIR}/Image"
QEMU_PORT=5555

# Renklendirme
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  QEMU arm64 Boot - Sistem İzleyici        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# 1. Kernel kontrol
if [ ! -f "$KERNEL_IMG" ]; then
    echo -e "${YELLOW}[!] Kernel bulunamadı: $KERNEL_IMG${NC}"
    echo -e "${YELLOW}    Docker container'dan Image'i kopyalayın:${NC}"
    echo -e "    docker cp <container_id>:/vmlinuz ."
    exit 1
fi

# 2. RootFS kontrol
if [ ! -f "$ROOTFS_IMG" ]; then
    echo -e "${RED}[✗] RootFS bulunamadı: $ROOTFS_IMG${NC}"
    exit 1
fi

# 3. QEMU başlat
echo -e "${YELLOW}[*] QEMU başlatılıyor...${NC}"
echo -e "${YELLOW}[*] Serial: /dev/pts/X üzerinden erişim sağlanacak${NC}"
echo -e "${YELLOW}[*] Çıkmak için: Ctrl+A X (QEMU Monitor)${NC}"
echo ""

qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -m 512M \
    -smp 2 \
    -kernel "$KERNEL_IMG" \
    -drive file="$ROOTFS_IMG",format=raw,if=virtio \
    -append "root=/dev/vda rw console=ttyAMA0 earlycon init=/init" \
    -serial stdio \
    -nographic

echo ""
echo -e "${GREEN}✓ QEMU kapatıldı${NC}"
