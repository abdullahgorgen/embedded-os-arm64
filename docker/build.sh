#!/bin/bash

# Renklendirme
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Docker Image Oluşturuluyor ===${NC}"
echo ""

# Dockerfile'ın bulunduğu dizine git
cd "$(dirname "$0")"

# Docker image'i oluştur
docker build \
    --build-arg UID=$(id -u) \
    --build-arg GID=$(id -g) \
    -t arm64-embedded-dev:latest \
    -f Dockerfile \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker image başarıyla oluşturuldu: arm64-embedded-dev:latest${NC}"
else
    echo -e "${RED}✗ Docker image oluşturma başarısız${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Container'ı başlatmak için şu komutu çalıştır:${NC}"
echo "docker run -it --rm -v \$(pwd):/workspace arm64-embedded-dev:latest"
