#!/bin/bash
set -e

BUSYBOX_VERSION="1.36.1"
WORK_DIR=$(pwd)
BUSYBOX_DIR="busybox-${BUSYBOX_VERSION}"
INSTALL_DIR="${WORK_DIR}/busybox_install"

echo "==========================================="
echo "  BusyBox arm64 Statik Derleme Başlıyor"
echo "==========================================="

# Toolchain kontrolü
if ! command -v aarch64-linux-gnu-gcc &>/dev/null; then
    echo "✗ KRİTİK HATA: aarch64-linux-gnu-gcc bulunamadı!"
    echo "  Bu script Docker container içinde çalışmalıdır."
    exit 1
fi
echo "✓ Toolchain: $(aarch64-linux-gnu-gcc --version | head -1)"

if [ ! -d "$BUSYBOX_DIR" ]; then
    wget -q https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
    tar xjf busybox-${BUSYBOX_VERSION}.tar.bz2
    rm busybox-${BUSYBOX_VERSION}.tar.bz2
fi

cd "$BUSYBOX_DIR"

# --- PATH ZEHİRLENMESİ ÖNLEME ---
# Dockerfile'da ENV PATH="/usr/aarch64-linux-gnu/bin:${PATH}" tanımlı.
# Bu dizindeki `as` (ARM64 assembler), BusyBox kconfig'in host araçlarını
# (HOSTCC=gcc) derlerken --64 flag'i ile çağrılır → hata verir.
# Çözüm: HOSTCC ve HOSTAR'ı açıkça native (x86_64) araçlara yönlendir.
# Cross-compile araçları ise CROSS_COMPILE prefix'i sayesinde zaten doğru.
export HOSTCC=/usr/bin/x86_64-linux-gnu-gcc-11
export HOSTCXX=/usr/bin/x86_64-linux-gnu-g++-11
export HOSTAR=/usr/bin/x86_64-linux-gnu-ar
# HOSTCC olarak normal gcc de çalışır; güvenli fallback:
if [ ! -f "$HOSTCC" ]; then
    export HOSTCC=$(which gcc 2>/dev/null || which cc)
    export HOSTCXX=$(which g++ 2>/dev/null || which c++)
    export HOSTAR=$(which ar)
fi
echo "  HOSTCC : $HOSTCC"
echo "  HOSTAR : $HOSTAR"

# --- ADIM 1: Temiz başlangıç noktası oluştur ---
# `yes ""` → NEW config sorularına otomatik varsayılan yanıt (enter)
echo "[1/4] defconfig oluşturuluyor (non-interactive)..."
yes "" | make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    HOSTCC="$HOSTCC" HOSTAR="$HOSTAR" \
    defconfig 2>&1 | grep -v "^$" | tail -3

# --- ADIM 2: Statik derleme için .config'i cerrahi müdahaleyle yamala ---
# Kconfig bağımlılık çözümlemesini BYPASS ederek doğrudan .config dosyasını düzenle.
# Neden: `make oldconfig` ile PIE/STATIC çakışmasını çözmek mümkün değil —
# kconfig her zaman PIE'yi tercih eder ve STATIC'i kapatır.
# Bu yaklaşım BusyBox build sistemi tarafından desteklenir: .config doğrudan okunur.
echo "[2/4] Statik derleme konfigürasyonu uygulanıyor (sed ile direkt .config yaması)..."

# PIE → kapat (STATIC ile çakışır)
sed -i 's/^CONFIG_PIE=y$/# CONFIG_PIE is not set/' .config
# SUID → kapat (statik ile çakışabilir)
sed -i 's/^CONFIG_FEATURE_SUID=y$/# CONFIG_FEATURE_SUID is not set/' .config
sed -i 's/^CONFIG_FEATURE_SUID_CONFIG=y$/# CONFIG_FEATURE_SUID_CONFIG is not set/' .config
sed -i 's/^CONFIG_FEATURE_SUID_CONFIG_QUIET=y$/# CONFIG_FEATURE_SUID_CONFIG_QUIET is not set/' .config
# STATIC → aç (satır mevcut: "# CONFIG_STATIC is not set" → "CONFIG_STATIC=y")
sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' .config
# LIBBUSYBOX_STATIC → aç (isteğe bağlı ama tutarlılık için)
sed -i 's/^# CONFIG_FEATURE_LIBBUSYBOX_STATIC is not set$/CONFIG_FEATURE_LIBBUSYBOX_STATIC=y/' .config

echo "  .config yaması tamamlandı"

# --- ADIM 3: Kritik doğrulama — derleme ÖNCESI ---
echo "[3/4] Konfigürasyon doğrulanıyor..."
STATIC_VAL=$(grep -E "^CONFIG_STATIC=" .config || echo "NOT_FOUND")
PIE_VAL=$(grep -E "^CONFIG_PIE=" .config || echo "# CONFIG_PIE is not set")

echo "  CONFIG_STATIC  : $STATIC_VAL"
echo "  CONFIG_PIE     : $PIE_VAL"

if [ "$STATIC_VAL" != "CONFIG_STATIC=y" ]; then
    echo ""
    echo "✗ HATA: CONFIG_STATIC=y ayarlanamadı!"
    echo "  Mevcut .config içeriği (ilgili satırlar):"
    grep -E "STATIC|PIE|SUID" .config || true
    exit 1
fi
echo "  ✓ Statik derleme aktif — derleme başlıyor"

# --- ADIM 4: Derleme ve kurulum ---
echo "[4/4] Derleniyor (bu işlem birkaç dakika sürebilir)..."
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    HOSTCC="$HOSTCC" HOSTAR="$HOSTAR" \
    -j$(nproc) 2>&1 | tail -10

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- \
    HOSTCC="$HOSTCC" HOSTAR="$HOSTAR" \
    CONFIG_PREFIX="$INSTALL_DIR" install > /dev/null 2>&1

# --- MÜHENDİSLİK DOĞRULAMASI (derleme sonrası) ---
echo ""
echo "=== Derleme Sonrası Doğrulama ==="
BUSYBOX_BIN="$INSTALL_DIR/bin/busybox"

if [ ! -f "$BUSYBOX_BIN" ]; then
    echo "✗ HATA: $BUSYBOX_BIN bulunamadı!"
    exit 1
fi

FILE_OUT=$(file "$BUSYBOX_BIN")
echo "  file: $FILE_OUT"

# Mimari kontrolü
if [[ "$FILE_OUT" != *"ARM aarch64"* ]]; then
    echo "✗ KRİTİK HATA: Binary ARM aarch64 mimarisinde değil!"
    exit 1
fi
echo "  ✓ Mimari: ARM aarch64 (doğru)"

# Statik linkaj kontrolü — bu kontrolü geçemezse RootFS kullanılamaz
if [[ "$FILE_OUT" == *"dynamically linked"* ]]; then
    echo ""
    echo "✗ KRİTİK HATA: BusyBox hâlâ dinamik linklenmiş!"
    echo "  Bağımlılıklar:"
    readelf -d "$BUSYBOX_BIN" | grep NEEDED || true
    echo ""
    echo "  Bu binary ile RootFS boot edilemez."
    echo "  Dinamik linker (/lib/ld-linux-aarch64.so.1) RootFS içinde mevcut değil."
    exit 1
fi

if [[ "$FILE_OUT" == *"statically linked"* ]]; then
    SIZE=$(du -h "$BUSYBOX_BIN" | cut -f1)
    echo "  ✓ Linkaj  : statically linked (DOĞRU)"
    echo "  ✓ Boyut   : $SIZE"
    echo ""
    echo "✓ ZAFER: BusyBox başarıyla statik derlendi ve ARM64 için hazır!"
else
    echo "⚠ UYARI: Linkaj tipi belirlenemedi — binary incelenmelidir:"
    echo "  $FILE_OUT"
fi
