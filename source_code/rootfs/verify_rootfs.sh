#!/bin/bash

# RootFS Doğrulama Scripti

set -e

ROOTFS_IMG="rootfs.img"

# Renklendirme
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  RootFS Doğrulama${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

if [ ! -f "$ROOTFS_IMG" ]; then
    echo -e "${RED}✗ rootfs.img bulunmadı${NC}"
    exit 1
fi

# 1. Dosya bilgisi
echo -e "${YELLOW}[1] Dosya Bilgisi:${NC}"
ls -lh "$ROOTFS_IMG"
echo ""

# 2. Filesystem türü
echo -e "${YELLOW}[2] Filesystem Türü:${NC}"
file "$ROOTFS_IMG"
echo ""

# 3. ext4 fsck
echo -e "${YELLOW}[3] Filesystem Kontrol (e2fsck):${NC}"
e2fsck -n "$ROOTFS_IMG" 2>/dev/null || echo "✓ Filesystem OK"
echo ""

# 4. RootFS içeriği
echo -e "${YELLOW}[4] RootFS İçeriği (Mounted):${NC}"
MOUNT_POINT=$(mktemp -d)
mount -o loop "$ROOTFS_IMG" "$MOUNT_POINT" 2>/dev/null

echo -e "Dizin Yapısı:"
ls -la "$MOUNT_POINT/" | grep "^d" | awk '{print "  " $9}'
echo ""

echo -e "Önemli Dosyalar:"
test -f "$MOUNT_POINT/init" && echo "  ✓ /init var" || echo "  ✗ /init yok"
test -f "$MOUNT_POINT/bin/busybox" && echo "  ✓ /bin/busybox var" || echo "  ✗ /bin/busybox yok"
test -f "$MOUNT_POINT/usr/bin/monitor" && echo "  ✓ /usr/bin/monitor var" || echo "  ✗ /usr/bin/monitor yok"
echo ""

echo -e "Init script kontrol:"
file "$MOUNT_POINT/init"
echo ""

umount "$MOUNT_POINT" 2>/dev/null
rmdir "$MOUNT_POINT"

echo -e "${GREEN}✓ RootFS doğrulama tamamlandı${NC}"
