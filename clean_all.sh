#!/bin/bash
# ===================================================================
# clean_all.sh — Dinamik Sistem Temizlik Betiği
# ===================================================================

set -e

# Betiğin çalıştığı kök dizini dinamik olarak al
PROJECT_ROOT=$(pwd)

echo "[*] Tüm katmanlardaki derleme artıkları temizleniyor... (Dizin: $PROJECT_ROOT)"

# Dizin içi Makefile kurallarının işletilmesi
cd "$PROJECT_ROOT/source_code" && make clean

# ÇÖZÜM BURADA: Sürücüyü temizlerken doğru Kernel dizinini parametre olarak veriyoruz
cd "$PROJECT_ROOT/source_code/driver" && make KDIR="$PROJECT_ROOT/qemu/linux-6.1.75" clean

cd "$PROJECT_ROOT/qemu" && make clean

# Ana dizine geri dön
cd "$PROJECT_ROOT"

# RootFS staging alanının arındırılması
rm -f "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/collector" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/monitor" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/display" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/stress_mem" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/meminfo"

rm -f "$PROJECT_ROOT/rootfs/rootfs_tree/lib/modules/sys_alarm_driver.ko"

# Geçici DTS/DTB dosyalarının silinmesi
rm -f "$PROJECT_ROOT/dts/virt_base.dtb" \
      "$PROJECT_ROOT/dts/virt_base.dts" \
      "$PROJECT_ROOT/dts/custom_virt_machine.dtb"

echo "[✓] Temizlik tamamlandı. Sistem sıfırdan derlemeye (clean build) hazır."
