#!/bin/bash

# Docker Container'ında Kernel Derleme - Geliştirilmiş

WORK_DIR=$(pwd)
IMAGE_NAME="arm64-embedded-dev:latest"
TARGET_IMAGE="${WORK_DIR}/qemu/Image"

# Renklendirme
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}  Docker İçinde Kernel Derleme${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Docker image kontrol
echo -e "${YELLOW}[1] Docker Image Kontrol${NC}"
if ! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
    echo -e "${RED}✗ Docker image bulunamadı: $IMAGE_NAME${NC}"
    echo ""
    echo -e "${YELLOW}Çözüm:${NC}"
    echo "cd docker"
    echo "./build.sh"
    exit 1
fi
echo -e "${GREEN}✓ Docker image mevcut${NC}"
echo ""

# Docker kontrol
echo -e "${YELLOW}[2] Docker Daemon Kontrol${NC}"
if ! docker ps > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker daemon çalışmıyor${NC}"
    echo ""
    echo -e "${YELLOW}Çözüm (Linux):${NC}"
    echo "sudo systemctl start docker"
    echo ""
    echo -e "${YELLOW}Çözüm (Windows/Mac):${NC}"
    echo "Docker Desktop'u aç"
    exit 1
fi
echo -e "${GREEN}✓ Docker daemon çalışıyor${NC}"
echo ""

# Kernel derleme
echo -e "${YELLOW}[3] Kernel Derleme Başlıyor${NC}"
echo "Container'da 5-10 dakika sürebilir..."
echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Docker'da komut çalıştır
docker run --rm \
    -v "${WORK_DIR}:/workspace" \
    "$IMAGE_NAME" \
    bash -c "
        cd /workspace/qemu && \
        chmod +x build_kernel.sh && \
        ./build_kernel.sh
    "

BUILD_RESULT=$?

echo ""
echo -e "${BLUE}═══════════════════════════════════════════${NC}"

if [ $BUILD_RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Kernel derleme BAŞARILI!${NC}"
    echo ""

    # Image kontrol (Path güncellendi)
    if [ -f "$TARGET_IMAGE" ]; then
        IMAGE_SIZE=$(du -h "$TARGET_IMAGE" | cut -f1)
        echo "Image: $TARGET_IMAGE"
        echo "Boyut: $IMAGE_SIZE"
        echo ""
        echo -e "${YELLOW}Sıradaki:${NC}"
        echo "./qemu/verify_kernel.sh"
        echo "./qemu/boot_kernel.sh"
    else
        echo -e "${RED}⚠ Uyarı: Image dosyası belirtilen dizinde bulunamadı (${TARGET_IMAGE})${NC}"
    fi
else
    echo -e "${RED}✗ Kernel derleme BAŞARISIZ${NC}"
    echo ""
    echo -e "${YELLOW}Çözüm:${NC}"
    echo "1. Log dosyalarını inceleyiniz."
    echo "2. qemu/build_kernel.sh betiğindeki hataları gideriniz."
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════${NC}"
