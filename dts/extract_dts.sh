#!/bin/bash
# extract_dts.sh — QEMU virt DTB'yi çıkar ve DTS'e dönüştür
#
# Kullanım: bash extract_dts.sh
# Çıktı   : virt_base.dtb, virt_base.dts (bu dizinde)
#
# Not: Docker içinde çalıştırılmalıdır (qemu-system-aarch64 ve dtc gereklidir)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DTB_OUT="$SCRIPT_DIR/virt_base.dtb"
DTS_OUT="$SCRIPT_DIR/virt_base.dts"

echo "[1] QEMU virt makinesinden DTB dump alınıyor..."
qemu-system-aarch64 \
    -machine virt,dumpdtb="$DTB_OUT" \
    -cpu cortex-a72 \
    -m 512M \
    -smp 2 \
    -nographic \
    -nodefaults \
    2>/dev/null || true
# dumpdtb QEMU'yu hemen kapatır — exit code 1 normaldir

if [ ! -f "$DTB_OUT" ]; then
    echo "HATA: DTB oluşturulamadı: $DTB_OUT"
    exit 1
fi
echo "  ✓ DTB: $DTB_OUT ($(du -h "$DTB_OUT" | cut -f1))"

echo "[2] DTB → DTS dönüşümü..."
dtc -I dtb -O dts -o "$DTS_OUT" "$DTB_OUT"
echo "  ✓ DTS: $DTS_OUT"

echo ""
echo "Sıradaki adım:"
echo "  DTS dosyasını düzenleyip custom_virt_machine.dts olarak kaydedin."
echo "  Ardından: dtc -I dts -O dtb -o custom_virt_machine.dtb custom_virt_machine.dts"
