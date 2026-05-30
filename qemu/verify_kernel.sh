#!/bin/bash

# Kernel derleme doğrulanması

KERNEL_IMAGE="Image"
KERNEL_MIN_SIZE=20000000  # 20MB minimum

echo "════════════════════════════════════"
echo "  Kernel Doğrulama"
echo "════════════════════════════════════"
echo ""

# 1. Dosya var mı?
if [ ! -f "$KERNEL_IMAGE" ]; then
    echo "✗ Kernel Image bulunamadı: $KERNEL_IMAGE"
    echo "  Lütfen önce: ./build_kernel.sh çalıştırın"
    exit 1
fi

echo "[1] Dosya Bilgisi:"
ls -lh "$KERNEL_IMAGE"
KERNEL_SIZE=$(stat -c%s "$KERNEL_IMAGE" 2>/dev/null || stat -f%z "$KERNEL_IMAGE")
echo ""

# 2. Dosya türü kontrol
echo "[2] ELF Dosya Türü:"
file "$KERNEL_IMAGE"
echo ""

# 3. Boyut kontrol
echo "[3] Boyut Kontrol:"
if [ "$KERNEL_SIZE" -gt "$KERNEL_MIN_SIZE" ]; then
    echo "✓ Boyut uygun (>${KERNEL_MIN_SIZE} bytes)"
else
    echo "✗ Kernel boyutu çok küçük! (${KERNEL_SIZE} bytes)"
    exit 1
fi
echo ""

# 4. Mimari Doğrulanması (Hata giderildi)
echo "[4] Mimari Doğrulanması:"
if file "$KERNEL_IMAGE" | grep -iE "aarch64|ARM64"; then
    echo "✓ ARM64 binary doğrulandı"
else
    echo "✗ Mimari uyuşmuyor!"
    exit 1
fi
echo ""

# 5. ELF header
echo "[5] ELF Header Bilgisi:"
readelf -h "$KERNEL_IMAGE" 2>/dev/null | grep -E "Machine|Class" || echo "  Not: Sıkıştırılmış vmlinuz formatı sebebiyle readelf analizi atlandı."
echo ""

echo "════════════════════════════════════"
echo "✓ Kernel doğrulama başarılı!"
echo "════════════════════════════════════"
echo ""
echo "Sıradaki adım: ./boot_kernel.sh"
