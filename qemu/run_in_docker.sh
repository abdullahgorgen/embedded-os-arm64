#!/bin/bash

# Docker container'ında QEMU boot
WORK_DIR=$(pwd)

echo "========================================="
echo "  QEMU ARM64 Simülasyonu Başlatılıyor... "
echo "  Çıkış yapmak için: Ctrl+A sonra X "
echo "========================================="

docker run -it --rm \
    -v "${WORK_DIR}:/workspace" \
    arm64-embedded-dev:latest \
    bash -c "cd /workspace && \
             qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -m 512M \
    -smp 2 \
    -kernel ./qemu/Image \
    -drive file=./source_code/rootfs/rootfs.img,format=raw,if=virtio \
    -append 'root=/dev/vda rw console=ttyAMA0 init=/init' \
    -nographic"
