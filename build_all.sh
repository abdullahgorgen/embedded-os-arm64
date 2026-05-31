#!/bin/bash
set -e

echo '══════════════════════════════════════════'
echo '  ARM64 IPC Pipeline — Tam Derleme'
echo '══════════════════════════════════════════'
echo ''

# 1. Derleme
echo '[1/3] Derleniyor...'
cd /workspace/source_code
make clean
make all
make verify
echo ''

# 2. RootFS tree kopyalama
echo '[2/3] Binary kurulumu (rootfs_tree/usr/bin/)...'
mkdir -p /workspace/rootfs/rootfs_tree/usr/bin
cp collector monitor display /workspace/rootfs/rootfs_tree/usr/bin/
chmod 755 /workspace/rootfs/rootfs_tree/usr/bin/collector \
          /workspace/rootfs/rootfs_tree/usr/bin/monitor \
          /workspace/rootfs/rootfs_tree/usr/bin/display
echo '  collector → rootfs_tree/usr/bin/ ✓'
echo '  monitor   → rootfs_tree/usr/bin/ ✓'
echo '  display   → rootfs_tree/usr/bin/ ✓'
echo ''

# 3. RootFS imajı yeniden oluştur
echo '[3/3] RootFS imajı yeniden oluşturuluyor...'
cd /workspace/rootfs
bash build_rootfs.sh
echo ''

# Son kontrol: imaj içindeki binary'leri doğrula
echo '══ İmaj İçi Doğrulama ══'
MNTDIR=$(mktemp -d)
mount -o loop,ro rootfs.img "$MNTDIR"
for b in collector monitor display stress_mem meminfo; do
  if [ -x "$MNTDIR/usr/bin/$b" ]; then
    echo "  ✓ /usr/bin/$b — imaj içinde"
  else
    echo "  ✗ /usr/bin/$b — EKSİK!"
  fi
done
umount "$MNTDIR"
rmdir "$MNTDIR"

echo ''
echo '══════════════════════════════════════════'
echo '✓ Tüm adımlar tamamlandı'
echo '══════════════════════════════════════════'
