#!/bin/bash
# build_driver.sh — Tam Kernel Modülü + IPC + DTS + RootFS Build Pipeline
set -e
echo '══════════════════════════════════════════════════════'
echo '  ARM64 Embedded — Aşama 5/6 Tam Build Pipeline'
echo '══════════════════════════════════════════════════════'
echo ''
KDIR="/workspace/qemu/linux-6.1.75"
ARCH="arm64"
CROSS="aarch64-linux-gnu-"
NPROC=$(nproc)
# ─── ADIM 1: Kernel modules_prepare ─────────────────────────
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
echo "  Module.symvers: $(ls -lh Module.symvers 2>/dev/null || echo 'OLUŞMADI')"
echo ''
# ─── ADIM 2: sys_alarm_driver.ko derleme ─────────────────────
echo "[2/6] sys_alarm_driver.ko derleniyor..."
cd /workspace/source_code/driver
make clean 2>/dev/null || true
make KDIR=$KDIR
file sys_alarm_driver.ko
echo ''
# ─── ADIM 3: IPC Userspace binary'leri ───────────────────────
echo "[3/6] IPC userspace binary'leri derleniyor..."
cd /workspace/source_code
make clean
make all
make verify
echo ''
# ─── ADIM 4: DTS extraction + custom DTS oluşturma ───────────
echo "[4/6] DTS işlemi..."
mkdir -p /workspace/dts
BASE_DTB="/workspace/dts/virt_base.dtb"
BASE_DTS="/workspace/dts/virt_base.dts"
CUSTOM_DTS="/workspace/dts/custom_virt_machine.dts"
CUSTOM_DTB="/workspace/dts/custom_virt_machine.dtb"
# QEMU'dan DTB dump
echo "  QEMU virt DTB dump alınıyor..."
qemu-system-aarch64 \
    -machine virt,dumpdtb="$BASE_DTB" \
    -cpu cortex-a72 -m 512M -smp 2 \
    -nographic -nodefaults 2>/dev/null || true
if [ ! -f "$BASE_DTB" ]; then
    echo "  HATA: DTB oluşturulamadı"
    exit 1
fi
echo "  ✓ Base DTB: $BASE_DTB ($(du -h "$BASE_DTB" | cut -f1))"
# DTB → DTS
dtc -I dtb -O dts -o "$BASE_DTS" "$BASE_DTB" 2>/dev/null
echo "  ✓ Base DTS: $BASE_DTS"
# custom DTS: system_alarm@09080000 düğümü enjekte et
# Son '}' den önce node'u ekle
python3 - "$BASE_DTS" "$CUSTOM_DTS" << 'EOF'
import sys, re
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
# Dosyanın son '}' (kök kapanış) den önce ekle
idx = content.rfind('};')
if idx == -1:
    # Alternatif: son '}' bul
    idx = content.rfind('}')
if idx != -1:
    new_content = content[:idx] + node + content[idx:]
else:
    new_content = content + node
with open(sys.argv[2], 'w') as f:
    f.write(new_content)
print("  ✓ system_alarm@09080000 düğümü eklendi")
EOF
echo "  ✓ Custom DTS: $CUSTOM_DTS"
# DTS → DTB
dtc -I dts -O dtb -o "$CUSTOM_DTB" "$CUSTOM_DTS" 2>&1 | grep -v Warning || true
echo "  ✓ Custom DTB: $CUSTOM_DTB ($(du -h "$CUSTOM_DTB" | cut -f1))"
# Düğüm doğrulama
if dtc -I dtb -O dts "$CUSTOM_DTB" 2>/dev/null | grep -q 'marmara,system-alarm'; then
    echo "  ✓ Doğrulama: marmara,system-alarm DTB içinde"
else
    echo "  ✗ HATA: marmara,system-alarm DTB içinde bulunamadı!"
    exit 1
fi
echo ''
# ─── ADIM 5: RootFS rebuild ───────────────────────────────────
echo "[5/6] RootFS imajı yeniden oluşturuluyor..."
cd /workspace/rootfs
bash build_rootfs.sh
echo ''
# ─── ADIM 6: Final doğrulama ─────────────────────────────────
echo "[6/6] Final İmaj Doğrulama..."
MNTDIR=$(mktemp -d)
mount -o loop,ro /workspace/rootfs/rootfs.img "$MNTDIR"
CHECK_OK=0
CHECK_FAIL=0
check_file() {
    local desc="$1" path="$2"
    if [ -e "$MNTDIR/$path" ]; then
        echo "  ✓ $desc"
        CHECK_OK=$((CHECK_OK+1))
    else
        echo "  ✗ EKSİK: $desc ($path)"
        CHECK_FAIL=$((CHECK_FAIL+1))
    fi
}
check_file "collector"              "usr/bin/collector"
check_file "monitor"                "usr/bin/monitor"
check_file "display"                "usr/bin/display"
check_file "stress_mem"             "usr/bin/stress_mem"
check_file "meminfo"                "usr/bin/meminfo"
check_file "sys_alarm_driver.ko"    "lib/modules/sys_alarm_driver.ko"
umount "$MNTDIR"
rmdir "$MNTDIR"
echo ''
echo "══════════════════════════════════════════════════════"
echo "  Sonuç: $CHECK_OK ✓  |  $CHECK_FAIL ✗"
if [ "$CHECK_FAIL" -eq 0 ]; then
    echo "✓ TÜM ADIMLAR TAMAMLANDI"
else
    echo "✗ $CHECK_FAIL DOSYA EKSİK"
    exit 1
fi
echo ''
echo "DTB: /workspace/dts/custom_virt_machine.dtb"
echo "İmaj: /workspace/rootfs/rootfs.img"
echo "══════════════════════════════════════════════════════"