#!/bin/bash
set -e

WORK_DIR=$(pwd)
BUSYBOX_INSTALL="${WORK_DIR}/busybox_install"
ROOTFS_DIR="${WORK_DIR}/rootfs_tree"
ROOTFS_IMG="${WORK_DIR}/rootfs.img"
ROOTFS_SIZE=512

# Renklendirme
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== RootFS Oluşturma Başlıyor ===${NC}"
echo ""

# --- ÖN KOŞUL: BusyBox statik mi? ---
echo -e "${YELLOW}[0] BusyBox Doğrulama${NC}"

if [ ! -d "$BUSYBOX_INSTALL" ]; then
    echo -e "${RED}✗ HATA: BusyBox kurulum dizini bulunamadı: $BUSYBOX_INSTALL${NC}"
    echo "  Önce build_busybox.sh çalıştırın."
    exit 1
fi

BUSYBOX_BIN="$BUSYBOX_INSTALL/bin/busybox"
if [ ! -f "$BUSYBOX_BIN" ]; then
    echo -e "${RED}✗ HATA: $BUSYBOX_BIN bulunamadı!${NC}"
    exit 1
fi

FILE_OUT=$(file "$BUSYBOX_BIN")
echo "  $FILE_OUT"

if [[ "$FILE_OUT" == *"dynamically linked"* ]]; then
    echo -e "${RED}"
    echo "✗ KRİTİK: BusyBox dinamik linklenmiş!"
    echo "  Bu binary ile sistem boot edilemez."
    echo "  Çözüm: build_busybox.sh çalıştırın (Docker içinde)."
    echo -e "${NC}"
    exit 1
fi

if [[ "$FILE_OUT" != *"statically linked"* ]]; then
    echo -e "${RED}✗ HATA: BusyBox linkaj tipi belirlenemedi!${NC}"
    exit 1
fi

echo -e "  ${GREEN}✓ BusyBox statik linklenmiş — devam ediliyor${NC}"
echo ""

# --- GÜVENLIK KONTROLÜ ---
if [ -z "$ROOTFS_DIR" ] || [ "$ROOTFS_DIR" == "/" ]; then
    echo -e "${RED}✗ Kritik Hata: ROOTFS_DIR değişkeni hatalı!${NC}"
    exit 1
fi

# --- ADIM 1: Dizin yapısı ---
echo -e "${YELLOW}[1] Dizin yapısı oluşturuluyor...${NC}"
rm -rf "$ROOTFS_DIR" "$ROOTFS_IMG"
mkdir -p "$ROOTFS_DIR"/{bin,sbin,lib,lib64,usr/bin,usr/sbin,usr/lib,etc,dev,proc,sys,tmp,root,var/log,run}

# --- ADIM 2: BusyBox kopyalama ---
echo -e "${YELLOW}[2] BusyBox kopyalanıyor...${NC}"
cp -a "$BUSYBOX_INSTALL"/* "$ROOTFS_DIR/"
echo -e "  ${GREEN}✓ BusyBox kopyalandı${NC}"

# --- ADIM 3: /init betiği (Linux satır sonları ile) ---
echo -e "${YELLOW}[3] /init betiği oluşturuluyor...${NC}"

# printf kullanımı: CRLF (\r\n) riskini sıfırlar
printf '#!/bin/sh\n' > "$ROOTFS_DIR/init"
printf 'mount -t proc proc /proc\n' >> "$ROOTFS_DIR/init"
printf 'mount -t sysfs sysfs /sys\n' >> "$ROOTFS_DIR/init"
printf 'mount -t devtmpfs devtmpfs /dev 2>/dev/null || true\n' >> "$ROOTFS_DIR/init"
printf 'export PATH=/bin:/sbin:/usr/bin:/usr/sbin\n' >> "$ROOTFS_DIR/init"
printf 'echo ""\n' >> "$ROOTFS_DIR/init"
printf 'echo "=== QEMU ARM64 Embedded Linux ==="\n' >> "$ROOTFS_DIR/init"
printf 'echo "Kernel: $(uname -r)"\n' >> "$ROOTFS_DIR/init"
printf 'echo ""\n' >> "$ROOTFS_DIR/init"
printf '# setsid: yeni oturum (session) acar\n' >> "$ROOTFS_DIR/init"
printf '# cttyhack: /dev/console u controlling terminal olarak atar\n' >> "$ROOTFS_DIR/init"
printf 'exec setsid cttyhack /bin/sh\n' >> "$ROOTFS_DIR/init"

chmod 755 "$ROOTFS_DIR/init"

# CRLF doğrulaması
if file "$ROOTFS_DIR/init" | grep -q "CRLF"; then
    echo -e "${RED}✗ HATA: /init dosyasında CRLF satır sonları var!${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓ /init oluşturuldu (LF satır sonları)${NC}"

# --- ADIM 4: etc/fstab ---
echo -e "${YELLOW}[4] /etc/fstab oluşturuluyor...${NC}"
printf '/dev/vda / ext4 defaults,rw 0 1\n' > "$ROOTFS_DIR/etc/fstab"
printf 'proc /proc proc defaults 0 0\n' >> "$ROOTFS_DIR/etc/fstab"
printf 'sysfs /sys sysfs defaults 0 0\n' >> "$ROOTFS_DIR/etc/fstab"
printf 'devtmpfs /dev devtmpfs defaults 0 0\n' >> "$ROOTFS_DIR/etc/fstab"
echo -e "  ${GREEN}✓ /etc/fstab hazır${NC}"

# --- ADIM 5: etc/inittab (isteğe bağlı ama yararlı) ---
printf '::sysinit:/init\n' > "$ROOTFS_DIR/etc/inittab"
printf '::askfirst:/bin/sh\n' >> "$ROOTFS_DIR/etc/inittab"
printf '::ctrlaltdel:/sbin/reboot\n' >> "$ROOTFS_DIR/etc/inittab"

# --- ADIM 6: Disk imajı oluşturma ---
echo -e "${YELLOW}[5] ext4 imajı oluşturuluyor (${ROOTFS_SIZE}MB)...${NC}"
dd if=/dev/zero of="$ROOTFS_IMG" bs=1M count="$ROOTFS_SIZE" 2>/dev/null
mkfs.ext4 -F -L "rootfs" "$ROOTFS_IMG" > /dev/null 2>&1
echo -e "  ${GREEN}✓ ext4 imajı oluşturuldu${NC}"

# --- ADIM 6.5: IPC Pipeline binary'leri enjekte et ---
IPC_SRC="$(dirname "$WORK_DIR")/source_code"
IPC_DST="$ROOTFS_DIR/usr/bin"
IPC_BINS="collector monitor display stress_mem"

echo -e "${YELLOW}[6] IPC binary'leri ekleniyor...${NC}"
if [ -d "$IPC_SRC" ]; then
    for bin in $IPC_BINS; do
        if [ -f "$IPC_SRC/$bin" ]; then
            cp "$IPC_SRC/$bin" "$IPC_DST/$bin"
            chmod 755 "$IPC_DST/$bin"
            echo -e "  ${GREEN}✓${NC} $bin → /usr/bin/$bin"
        else
            echo -e "  ${YELLOW}⚠${NC} $bin bulunamadı ($IPC_SRC/$bin) — atlanıyor"
        fi
    done

    # meminfo.sh betiğini de kopyala (uzantısız)
    if [ -f "$IPC_SRC/meminfo.sh" ]; then
        cp "$IPC_SRC/meminfo.sh" "$IPC_DST/meminfo"
        chmod 755 "$IPC_DST/meminfo"
        echo -e "  ${GREEN}✓${NC} meminfo.sh → /usr/bin/meminfo"
    else
        echo -e "  ${YELLOW}⚠${NC} meminfo.sh bulunamadı ($IPC_SRC/meminfo.sh) — atlanıyor"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} source_code/ bulunamadı — IPC binary'leri atlandı"
fi

# --- ADIM 7: Mount ve kopyalama ---
echo -e "${YELLOW}[6] RootFS imajına kopyalanıyor...${NC}"
MOUNT_POINT=$(mktemp -d)

# Temizleme trap'i — mount noktasını her durumda temizle
cleanup() {
    if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
        umount "$MOUNT_POINT" 2>/dev/null || true
    fi
    rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

mount -o loop "$ROOTFS_IMG" "$MOUNT_POINT"
cp -a "$ROOTFS_DIR"/. "$MOUNT_POINT/"
sync
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"
trap - EXIT

echo -e "  ${GREEN}✓ Kopyalama tamamlandı${NC}"

# --- ADIM 8: Son doğrulama ---
echo ""
echo -e "${YELLOW}[7] Son Doğrulama${NC}"

VERIFY_MOUNT=$(mktemp -d)
mount -o loop,ro "$ROOTFS_IMG" "$VERIFY_MOUNT" 2>/dev/null

PASS=0
FAIL=0

check() {
    local desc="$1"; local path="$2"
    if [ -e "$VERIFY_MOUNT/$path" ]; then
        echo -e "  ${GREEN}✓${NC} $desc"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}✗${NC} $desc — EKSİK: /$path"
        FAIL=$((FAIL+1))
    fi
}

check "/init betiği"           "init"
check "/bin/busybox"           "bin/busybox"
check "/bin/sh (symlink)"      "bin/sh"
check "/etc/fstab"             "etc/fstab"
check "/proc (mount noktası)"  "proc"
check "/sys (mount noktası)"   "sys"
check "/dev (mount noktası)"   "dev"

# /init izin kontrolü
INIT_PERMS=$(stat -c "%a" "$VERIFY_MOUNT/init" 2>/dev/null || echo "000")
if [ "$INIT_PERMS" = "755" ]; then
    echo -e "  ${GREEN}✓${NC} /init çalıştırma izni (755)"
    PASS=$((PASS+1))
else
    echo -e "  ${RED}✗${NC} /init izinleri hatalı: $INIT_PERMS (beklenen: 755)"
    FAIL=$((FAIL+1))
fi

umount "$VERIFY_MOUNT"
rmdir "$VERIFY_MOUNT"

echo ""
IMG_SIZE=$(du -h "$ROOTFS_IMG" | cut -f1)
echo -e "  İmaj boyutu : $IMG_SIZE"
echo -e "  Kontroller  : ${GREEN}$PASS başarılı${NC}, ${RED}$FAIL başarısız${NC}"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}✗ RootFS doğrulama başarısız!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ RootFS Oluşturma Tamamlandı!${NC}"
echo ""
echo -e "${YELLOW}Sıradaki adım:${NC}"
echo "  cd ../qemu && ./boot_kernel.sh"
