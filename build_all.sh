#!/bin/bash
# ===================================================================
# build_all.sh — Dinamik ARM64 Embedded System Üretim Boru Hattı
# ===================================================================

set -e

# Betiğin çalıştığı kök dizini dinamik olarak al
PROJECT_ROOT=$(pwd)
KDIR="$PROJECT_ROOT/qemu/linux-6.1.75"
ARCH="arm64"
CROSS="aarch64-linux-gnu-"
NPROC=$(nproc)

ROOTFS_TREE="$PROJECT_ROOT/rootfs/rootfs_tree"
BIN_STAGE_DIR="$ROOTFS_TREE/usr/bin"
MOD_STAGE_DIR="$ROOTFS_TREE/lib/modules"

echo "══════════════════════════════════════════════════════"
echo "  ARM64 Embedded System — Dinamik Üretim Boru Hattı"
echo "══════════════════════════════════════════════════════"
echo ""

# ─── ADIM 1: KERNEL MODULES_PREPARE ────────────────────────────────
echo "[1/6] Kernel yapılandırması (defconfig + modules_prepare)..."
cd "$KDIR"
if [ ! -f .config ]; then
    make ARCH=$ARCH CROSS_COMPILE=$CROSS defconfig -j$NPROC > /dev/null 2>&1
fi
make ARCH=$ARCH CROSS_COMPILE=$CROSS modules_prepare -j$NPROC > /dev/null 2>&1

# ─── ADIM 2: KULLANICI UZAYI IPC BİLEŞENLERİ ───────────────────────
echo "[2/6] IPC userspace binary'leri derleniyor..."
cd "$PROJECT_ROOT/source_code"
make clean > /dev/null 2>&1 || true
make all
make verify

mkdir -p "$BIN_STAGE_DIR"
cp collector monitor display "$BIN_STAGE_DIR/"
[ -f stress_mem ] && cp stress_mem "$BIN_STAGE_DIR/"
[ -f meminfo ] && cp meminfo "$BIN_STAGE_DIR/"
[ -f meminfo.sh ] && cp meminfo.sh "$BIN_STAGE_DIR/meminfo"

chmod 755 "$BIN_STAGE_DIR/"*

# ─── ADIM 3: PLATFORM SÜRÜCÜSÜ DERLEME ─────────────────────────────
echo "[3/6] sys_alarm_driver.ko derleniyor..."
cd "$PROJECT_ROOT/source_code/driver"
make clean > /dev/null 2>&1 || true
make KDIR="$KDIR"

mkdir -p "$MOD_STAGE_DIR"
cp sys_alarm_driver.ko "$MOD_STAGE_DIR/"

# ─── ADIM 4: DEVICE TREE ENJEKSİYONU ───────────────────────────────
echo "[4/6] Device Tree (DTS/DTB) otomasyonu yürütülüyor..."
mkdir -p "$PROJECT_ROOT/dts"
BASE_DTB="$PROJECT_ROOT/dts/virt_base.dtb"
BASE_DTS="$PROJECT_ROOT/dts/virt_base.dts"
CUSTOM_DTS="$PROJECT_ROOT/dts/custom_virt_machine.dts"
CUSTOM_DTB="$PROJECT_ROOT/dts/custom_virt_machine.dtb"

qemu-system-aarch64 -machine virt,dumpdtb="$BASE_DTB" -cpu cortex-a72 -m 512M -smp 2 -nographic -nodefaults 2>/dev/null || true

if [ ! -f "$BASE_DTB" ]; then
    echo "HATA: Ham DTB dökümü alınamadı!"
    exit 1
fi

dtc -I dtb -O dts -o "$BASE_DTS" "$BASE_DTB" 2>/dev/null

python3 - "$BASE_DTS" "$CUSTOM_DTS" << 'PYEOF'
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
PYEOF

dtc -I dts -O dtb -o "$CUSTOM_DTB" "$CUSTOM_DTS" 2>&1 | grep -v Warning || true

if dtc -I dtb -O dts "$CUSTOM_DTB" 2>/dev/null | grep -q 'marmara,system-alarm'; then
    echo "  Doğrulama: Aygıt ağacı enjeksiyonu kararlı."
else
    echo "HATA: Aygıt ağacı düğümü bulunamadı."
    exit 1
fi

# ─── ADIM 5: ROOTFS PAKETLEME ──────────────────────────────────────
echo "[5/6] Kök dosya sistemi imajı yeniden oluşturuluyor..."
cd "$PROJECT_ROOT/rootfs"
bash build_rootfs.sh

# ─── ADIM 6: FİNAL İMAJ İÇİ DOĞRULAMA ──────────────────────────────
echo "[6/6] Nihai RootFS İmajı bütünlük denetimi..."
MNTDIR=$(mktemp -d)

# Bağlama işlemi root yetkisi gerektirir
sudo mount -o loop,ro "$PROJECT_ROOT/rootfs/rootfs.img" "$MNTDIR"

CHECK_OK=0
CHECK_FAIL=0

check_file() {
    if [ -e "$MNTDIR/$2" ]; then
        echo "  [✓] $1"
        CHECK_OK=$((CHECK_OK+1))
    else
        echo "  [✗] EKSİK: $1 (/$2)"
        CHECK_FAIL=$((CHECK_FAIL+1))
    fi
}

check_file "Collector"          "usr/bin/collector"
check_file "Monitor"            "usr/bin/monitor"
check_file "Display"            "usr/bin/display"
check_file "Stress Tool"        "usr/bin/stress_mem"
check_file "Orchestrator"       "usr/bin/meminfo"
check_file "Platform Sürücüsü"  "lib/modules/sys_alarm_driver.ko"

sudo umount "$MNTDIR"
rmdir "$MNTDIR"
echo ""

if [ "$CHECK_FAIL" -eq 0 ]; then
    echo "STATUS: TÜM SİSTEM BİLEŞENLERİ KUSURSUZ ŞEKİLDE ENTEGRE EDİLDİ."
else
    echo "HATA STATUS: DOSYA SİSTEMİ BÜTÜNLÜĞÜ BOZUK!"
    exit 1
fi
