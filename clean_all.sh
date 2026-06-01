#!/bin/bash
set -e

# Betiğin çalıştığı dizini dinamik olarak al
PROJECT_ROOT=$(pwd)
CLEAN_MODE=${1:-"standard"}

echo "══════════════════════════════════════════════════════"
if [ "$CLEAN_MODE" == "--deep" ]; then
    echo "  [DİKKAT] TAM TEMİZLİK (DEEP CLEAN) BAŞLATILIYOR"
else
    echo "  Standart Temizlik Başlatılıyor (Hafif Ara Çıktılar)"
fi
echo "══════════════════════════════════════════════════════"

# ─── 1. STANDART TEMİZLİK (Hafif Ara Çıktılar) ──────────────────────
echo "[*] IPC Binary'leri ve Kernel Modülü temizleniyor..."
cd "$PROJECT_ROOT/source_code" && make clean > /dev/null 2>&1 || true
cd "$PROJECT_ROOT/source_code/driver" && make KDIR="$PROJECT_ROOT/qemu/linux-6.1.75" clean > /dev/null 2>&1 || true

echo "[*] Device Tree ve RootFS staging alanı siliniyor..."
rm -f "$PROJECT_ROOT/dts/"*.dtb "$PROJECT_ROOT/dts/"*.dts
rm -rf "$PROJECT_ROOT/rootfs/rootfs_tree"
rm -f "$PROJECT_ROOT/rootfs/rootfs.img"

# ─── 2. DERİN TEMİZLİK (Ağır Bağımlılıklar - Sadece --deep ile) ─────
if [ "$CLEAN_MODE" == "--deep" ]; then
    echo "[*] Ağır Bağımlılıklar (Kernel & BusyBox) siliniyor..."
    rm -rf "$PROJECT_ROOT/qemu/linux-6.1.75"
    rm -f "$PROJECT_ROOT/qemu/linux-6.1.75.tar.xz"
    rm -f "$PROJECT_ROOT/qemu/Image"
    
    rm -rf "$PROJECT_ROOT/rootfs/busybox-1.36.1"
    rm -f "$PROJECT_ROOT/rootfs/busybox-1.36.1.tar.bz2"
    rm -rf "$PROJECT_ROOT/rootfs/busybox_install"
fi

echo "══════════════════════════════════════════════════════"
echo "[✓] Temizlik tamamlandı."