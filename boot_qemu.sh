#!/bin/bash
# ===================================================================
# boot_qemu.sh — ARM64 QEMU Simülasyon Başlatıcısı
# ===================================================================

WORK_DIR=$(pwd)

echo "========================================="
echo "  QEMU ARM64 Simülasyonu Başlatılıyor... "
echo "  Sistemden çıkış yapmak için: Ctrl+A, ardından X tuşlayın."
echo "========================================="

docker run -it --rm --privileged \
    -v "${WORK_DIR}:/workspace" \
    -e "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    arm64-embedded-dev:latest \
    qemu-system-aarch64 \
    -machine virt -cpu cortex-a72 -m 512M -smp 2 \
    -kernel /workspace/qemu/Image \
    -dtb /workspace/dts/custom_virt_machine.dtb \
    -drive file=/workspace/rootfs/rootfs.img,format=raw,if=virtio \
    -append "root=/dev/vda rw console=ttyAMA0 earlycon init=/init" \
    -nographic
