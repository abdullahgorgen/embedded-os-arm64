#!/bin/bash
# ===================================================================
# build_all.sh — Unified Embedded Linux In-Tree/Out-of-Tree Pipeline
# Target Architecture: ARM64 (QEMU Virt Platform)
# Engineering Scope  : Kernel Prep, Userspace IPC, Platform Driver,
#                      Device Tree Injection, RootFS Packaging, Validation.
# ===================================================================

set -e

echo '══════════════════════════════════════════════════════'
echo '  ARM64 Embedded System — Unified Production Pipeline'
echo '══════════════════════════════════════════════════════'
echo ''

# ─── ÇEVRESEL YAPILANDIRMA VE SABİTLER ─────────────────────────────
KDIR="/workspace/qemu/linux-6.1.75"
ARCH="arm64"
CROSS="aarch64-linux-gnu-"
NPROC=$(nproc)

ROOTFS_TREE="/workspace/rootfs/rootfs_tree"
BIN_STAGE_DIR="$ROOTFS_TREE/usr/bin"
MOD_STAGE_DIR="$ROOTFS_TREE/lib/modules"

# ─── ADIM 1: KERNEL MODULES_PREPARE ────────────────────────────────
echo "[1/6] Kernel yapılandırması (defconfig + modules_prepare)..."
cd "$KDIR"
if [ ! -f .config ]; then
    echo "  defconfig oluşturuluyor..."
    make ARCH=$ARCH CROSS_COMPILE=$CROSS defconfig -j$NPROC > /tmp/kernel_config.log 2>&1
    echo "  ✓ defconfig tamamlandı"
fi
echo "  modules_prepare çalışıyor..."
make ARCH=$ARCH CROSS_COMPILE=$CROSS modules_prepare -j$NPROC > /tmp/kernel_modules_prepare.log 2>&1
echo "  ✓ modules_prepare tamamlandı"
echo ''

# ─── ADIM 2: KULLANICI UZAYI IPC BİLEŞENLERİ ───────────────────────
echo "[2/6] IPC userspace binary'leri derleniyor ve sahneleniyor..."
cd /workspace/source_code
make clean
make all
make verify

# Staging dizin yapısının doğrulanması ve dosyaların kopyalanması
mkdir -p "$BIN_STAGE_DIR"
cp collector monitor display "$BIN_STAGE_DIR/"

# stress_mem ve meminfo araçlarının varlık kontrolü ve transferi
[ -f stress_mem ] && cp stress_mem "$BIN_STAGE_DIR/"
[ -f meminfo ] && cp meminfo "$BIN_STAGE_DIR/"
[ -f meminfo.sh ] && cp meminfo.sh "$BIN_STAGE_DIR/meminfo"

# POSIX çalıştırma izinlerinin normalize edilmesi
chmod 755 "$BIN_STAGE_DIR/collector" \
          "$BIN_STAGE_DIR/monitor" \
          "$BIN_STAGE_DIR/display"

[ -f "$BIN_STAGE_DIR/stress_mem" ] && chmod 755 "$BIN_STAGE_DIR/stress_mem"
[ -f "$BIN_STAGE_DIR/meminfo" ] && chmod 755 "$BIN_STAGE_DIR/meminfo"

echo "  ✓ Kullanıcı alanı bileşenleri rootfs_tree dizinine enjekte edildi"
echo ''

# ─── ADIM 3: PLATFORM SÜRÜCÜSÜ DERLEME ─────────────────────────────
echo "[3/6] sys_alarm_driver.ko derleniyor... (Out-of-Tree)"
cd /workspace/source_code/driver
make clean 2>/dev/null || true
make KDIR=$KDIR

# Sürücü dosyasının RootFS iskeletine transferi
mkdir -p "$MOD_STAGE_DIR"
cp sys_alarm_driver.ko "$MOD_STAGE_DIR/"
echo "  ✓ Çekirdek modülü lib/modules dizinine yerleştirildi"
echo ''

# ─── ADIM 4: DEVICE TREE ENJEKSİYONU ───────────────────────────────
echo "[4/6] Device Tree (DTS/DTB) otomasyonu yürütülüyor..."
mkdir -p /workspace/dts
BASE_DTB="/workspace/dts/virt_base.dtb"
BASE_DTS="/workspace/dts/virt_base.dts"
CUSTOM_DTS="/workspace/dts/custom_virt_machine.dts"
CUSTOM_DTB="/workspace/dts/custom_virt_machine.dtb"

echo "  QEMU virt makinesinden ham DTB dökümü alınıyor..."
qemu-system-aarch64 \
    -machine virt,dumpdtb="$BASE_DTB" \
    -cpu cortex-a72 -m 512M -smp 2 \
    -nographic -nodefaults 2>/dev/null || true

if [ ! -f "$BASE_DTB" ]; then
    echo "  HATA: Ham DTB dökümü alınamadı!"
    exit 1
fi

# İkili (Binary) DTB'den kaynak kod (DTS) üretimi
dtc -I dtb -O dts -o "$BASE_DTS" "$BASE_DTB" 2>/dev/null

# Python ile soyut platform cihazı (system_alarm) enjeksiyonu
python3 - "$BASE_DTS" "$CUSTOM_DTS" << 'EOF'
import sys
with open(sys.argv[1], 'r') as f:
    content = f.read()
node = """
\tsystem_alarm@09080000 {
\t\tcompatible = "marmara,system-alarm";
\t\treg = <0x0 0x09080000 0x0 0x1000>;
\t\tstatus = "okay";
\t\tlabel = "Critical Memory Alarm Relay";
\t};
"""
idx = content.rfind('};')
if idx == -1:
    idx = content.rfind('}')
if idx != -1:
    new_content = content[:idx] + node + content[idx:]
else:
    new_content = content + node
with open(sys.argv[2], 'w') as f:
    f.write(new_content)
EOF

echo "  ✓ 'marmara,system-alarm' düğümü DTS'ye eklendi"

# Yeni haritanın ikili formata geri derlenmesi
dtc -I dts -O dtb -o "$CUSTOM_DTB" "$CUSTOM_DTS" 2>&1 | grep -v Warning || true

# Derleme sonrası düğüm varlık denetimi
if dtc -I dtb -O dts "$CUSTOM_DTB" 2>/dev/null | grep -q 'marmara,system-alarm'; then
    echo "  ✓ Doğrulama: Aygıt ağacı enjeksiyonu kararlı"
else
    echo "  HATA: Sürücü uyumluluk etiketi (compatible) DTB içinde bulunamadı!"
    exit 1
fi
echo ''

# ─── ADIM 5: ROOTFS PAKETLEME ──────────────────────────────────────
echo "[5/6] Kök dosya sistemi imajı yeniden oluşturuluyor..."
cd /workspace/rootfs
bash build_rootfs.sh
echo ''

# ─── ADIM 6: FİNAL İMAJ İÇİ DOĞRULAMA (MATRİS DENETİMİ) ────────────
echo "[6/6] Nihai RootFS İmajı bütünlük denetimi..."
MNTDIR=$(mktemp -d)
mount -o loop,ro /workspace/rootfs/rootfs.img "$MNTDIR"

CHECK_OK=0
CHECK_FAIL=0

check_file() {
    local desc="$1" path="$2"
    if [ -e "$MNTDIR/$path" ]; then
        echo "  ✓ Doğrulandı: /$path ($desc)"
        CHECK_OK=$((CHECK_OK+1))
    else
        echo "  ✗ KRİTİK EKSİK: /$path ($desc)"
        CHECK_FAIL=$((CHECK_FAIL+1))
    fi
}

# Tam sistem doğrulama matrisi
check_file "Collector"              "usr/bin/collector"
check_file "Monitor"                "usr/bin/monitor"
check_file "Display"                "usr/bin/display"
check_file "Stress Tool"            "usr/bin/stress_mem"
check_file "Orchestrator"           "usr/bin/meminfo"
check_file "Platform Sürücüsü"      "lib/modules/sys_alarm_driver.ko"

umount "$MNTDIR"
rmdir "$MNTDIR"
echo ''

echo "══════════════════════════════════════════════════════"
echo "  Doğrulama Sonucu: Başarılı: $CHECK_OK | Hatalı: $CHECK_FAIL"
if [ "$CHECK_FAIL" -eq 0 ]; then
    echo "  STATUS: TÜM SİSTEM BİLEŞENLERİ KUSURSUZ ŞEKİLDE ENTEGRE EDİLDİ"
else
    echo "  HATA STATUS: DOSYA SİSTEMİ BÜTÜNLÜĞÜ BOZUK!"
    exit 1
fi
echo "══════════════════════════════════════════════════════"