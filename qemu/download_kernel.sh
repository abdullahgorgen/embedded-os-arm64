#!/bin/bash

echo "========================================="
echo "  QEMU ARM64 Kernel (Alpine Virt) İndiriliyor "
echo "========================================="

wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/aarch64/netboot/vmlinuz-virt -O qemu/Image

echo "[✓] Kernel başarıyla hazırlandı (qemu/Image)!"
