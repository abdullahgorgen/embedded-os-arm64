#!/bin/bash
set -e

# Docker içerisinde proje her zaman /workspace dizinine bağlanır
PROJECT_ROOT="/workspace"

echo "[*] Tüm katmanlardaki derleme artıkları temizleniyor... (Dizin: $PROJECT_ROOT)"

# Temizlik komutları (hata verseler bile devam etmesi için || true eklendi)
cd "$PROJECT_ROOT/source_code" && make clean || true
cd "$PROJECT_ROOT/source_code/driver" && make KDIR="$PROJECT_ROOT/qemu/linux-6.1.75" clean || true
cd "$PROJECT_ROOT/qemu" && make clean || true

# RootFS staging alanının arındırılması
rm -f "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/collector" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/monitor" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/display" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/stress_mem" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/usr/bin/meminfo" \
      "$PROJECT_ROOT/rootfs/rootfs_tree/lib/modules/sys_alarm_driver.ko"

# Geçici DTS/DTB dosyalarının silinmesi
rm -f "$PROJECT_ROOT/dts/"*.dtb \
      "$PROJECT_ROOT/dts/"*.dts

echo "[✓] Temizlik tamamlandı. Sistem sıfırdan derlemeye (clean build) hazır."
