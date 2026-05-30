# RootFS Oluşturma Rehberi

Bu doküman, ARM64 tabanlı gömülü Linux sistemi için BusyBox tabanlı minimal bir RootFS oluşturma sürecini adım adım açıklar.

---

# Gereksinimler

Aşağıdaki bileşenlerin sistemde hazır olması gerekir:

* Docker
* `arm64-embedded-dev:latest` Docker image
* Derlenmiş monitor uygulaması (`source_code/monitor`)
* `sudo` erişimi
* Linux host sistemi önerilir

---

# Kurulum Adımları

## 1. Docker Container Başlatma

Aşağıdaki komut ile geliştirme container’ını başlatın:

```bash
docker run -it --rm \
  -v $(pwd):/workspace \
  --privileged \
  arm64-embedded-dev:latest \
  bash
```

Container açıldıktan sonra çalışma dizinine geçin:

```bash
cd /workspace/rootfs
```

---

# 2. BusyBox Derleme

BusyBox statik ARM64 binary oluşturmak için:

```bash
./build_busybox.sh
```

## Beklenen Çıktı

```text
═══════════════════════════════════════════
BusyBox arm64 Statik Derleme Başlıyor
═══════════════════════════════════════════

[1/6] BusyBox 1.36.1 indiriliyor...
✓ BusyBox indirme tamamlandı

[2/6] BusyBox konfigürasyonu yapılıyor...
[3/6] Cross compile ayarlanıyor...
[4/6] BusyBox derleniyor...
[5/6] BusyBox install ediliyor...
[6/6] Temizlik yapılıyor...

✓ BusyBox Derleme Tamamlandı!
```

## Oluşturulan Dosyalar

```text
busybox-1.36.1/
busybox_install/
```

---

# 3. RootFS Oluşturma

BusyBox ve monitor uygulamasını içeren ext4 RootFS image oluşturmak için:

```bash
./build_rootfs.sh
```

## Beklenen Çıktı

```text
═══════════════════════════════════════════
RootFS Oluşturma (512MB ext4)
═══════════════════════════════════════════

[1/8] Eski RootFS temizleniyor...
[2/8] RootFS dizin yapısı oluşturuluyor...
[3/8] BusyBox kopyalanıyor...
[4/8] Sistem İzleyici uygulaması kopyalanıyor...
[5/8] Init scripti oluşturuluyor...
[6/8] Sistem kullanıcıları oluşturuluyor...
[7/8] ext4 disk image oluşturuluyor...
[8/8] RootFS disk image'a yazılıyor...

✓ RootFS Oluşturma Tamamlandı!

RootFS Image: /workspace/rootfs/rootfs.img
Boyut: 512M
```

## Oluşturulan Yapı

```text
rootfs_tree/
rootfs.img
```

---

# 4. RootFS Doğrulama

Oluşturulan RootFS image dosyasını kontrol etmek için:

```bash
./verify_rootfs.sh
```

## Beklenen Çıktı

```text
═══════════════════════════════════════════
RootFS Doğrulama
═══════════════════════════════════════════

[1] Dosya Bilgisi:
-rw-r--r-- 1 user user 512M rootfs.img

[2] Filesystem Türü:
rootfs.img: Linux rev 1.0 ext4 filesystem

[3] Filesystem Kontrol:
✓ Filesystem OK

[4] RootFS İçeriği:

Dizin Yapısı:
bin
dev
etc
proc
sys
tmp
usr
var

✓ /init var
✓ /bin/busybox var
✓ /usr/bin/monitor var

✓ RootFS doğrulama tamamlandı
```

---

# RootFS İçeriği

Oluşturulan RootFS aşağıdaki temel Linux dizin yapısını içerir:

```text
/
├── bin/
├── dev/
├── etc/
├── home/
├── proc/
├── root/
├── sys/
├── tmp/
├── usr/
│   ├── bin/
│   │   └── monitor
│   └── sbin/
├── var/
│   ├── log/
│   └── tmp/
└── init
```

---

# Init Sistemi

Sistem açıldığında `/init` scripti çalıştırılır.

Örnek init akışı:

```bash
#!/bin/sh

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev

echo "System Booting..."

/usr/bin/monitor &

exec /bin/sh
```

## Init Script Görevleri

* `/proc` mount edilir
* `/sys` mount edilir
* `/dev` mount edilir
* monitor uygulaması başlatılır
* shell açılır

---

# BusyBox Hakkında

BusyBox gömülü Linux sistemleri için tek binary içinde temel Linux araçlarını sağlayan hafif bir kullanıcı alanı paketidir.

Bu projede BusyBox:

* Statik derlenir
* ARM64 mimarisi için build edilir
* Shell araçlarını sağlar
* Init sistemi sağlar
* Minimal Linux kullanıcı alanı oluşturur

## Örnek BusyBox Komutları

```bash
ls
sh
mount
ps
top
cat
echo
dmesg
ifconfig
```

---

# ext4 Image Bilgileri

Oluşturulan image:

| Özellik    | Değer                   |
| ---------- | ----------------------- |
| Filesystem | ext4                    |
| Boyut      | 512MB                   |
| Mimari     | ARM64                   |
| Tip        | Minimal Embedded RootFS |

## Image İçeriğini Mount Etme

Host sistemde image mount etmek için:

```bash
mkdir mnt
sudo mount -o loop rootfs.img mnt
```

Unmount işlemi:

```bash
sudo umount mnt
```

---

# QEMU ile Test

RootFS image QEMU üzerinde test edilebilir.

Örnek kullanım:

```bash
qemu-system-aarch64 \
  -M virt \
  -cpu cortex-a57 \
  -m 512M \
  -kernel Image \
  -drive file=rootfs.img,format=raw \
  -append "root=/dev/vda rw console=ttyAMA0" \
  -nographic
```

---

# Proje Dosya Yapısı

```text
rootfs/
├── build_busybox.sh
├── build_rootfs.sh
├── verify_rootfs.sh
├── busybox-1.36.1/
├── busybox_install/
├── rootfs_tree/
├── rootfs.img
└── README_ROOTFS.md
```

## Dosya Açıklamaları

| Dosya / Dizin      | Açıklama                                                |
| ------------------ | ------------------------------------------------------- |
| `build_busybox.sh` | BusyBox kaynak kodunu indirir ve ARM64 için derler      |
| `build_rootfs.sh`  | RootFS dizin yapısını ve ext4 image dosyasını oluşturur |
| `verify_rootfs.sh` | RootFS image doğrulama işlemlerini yapar                |
| `busybox_install/` | BusyBox kurulum çıktıları                               |
| `rootfs_tree/`     | RootFS geçici çalışma dizini                            |
| `rootfs.img`       | Oluşturulan ext4 disk image                             |

---

# Sorun Giderme

## e2fs Araçları Eksik

Hata:

```text
mkfs.ext4: command not found
```

Çözüm:

```bash
apt-get update
apt-get install -y e2fsprogs
```

---

## e2fsck Permission Denied

Container içinde `sudo` gerekli değildir.

Yanlış kullanım:

```bash
sudo e2fsck -n rootfs.img
```

Doğru kullanım:

```bash
e2fsck -n rootfs.img
```

---

## BusyBox Derleme Timeout

Derleme işlemini arka planda çalıştırabilirsiniz:

```bash
./build_busybox.sh &
```

Durumu kontrol etmek için:

```bash
jobs
```

---

## rootfs.img Mount Hatası

Hata:

```text
wrong fs type, bad option, bad superblock
```

Kontrol:

```bash
file rootfs.img
e2fsck -f rootfs.img
```

---

## Monitor Binary Çalışmıyor

Binary mimarisini kontrol edin:

```bash
file /usr/bin/monitor
```

Beklenen çıktı:

```text
ELF 64-bit LSB executable, ARM aarch64
```

---

# Notlar

* RootFS ext4 formatında oluşturulur.
* Varsayılan image boyutu `512MB` olarak ayarlanmıştır.
* BusyBox statik derlenir.
* Sistem açılışında `/init` scripti çalıştırılır.
* `monitor` uygulaması `/usr/bin/monitor` altında bulunur.
* RootFS hem QEMU hem gerçek ARM64 cihazlarda kullanılabilir.
* Bu yapı minimal embedded Linux sistemi hedefler.

---

# Hızlı Başlangıç

Tüm işlemleri sırasıyla çalıştırmak için:

```bash
cd /workspace/rootfs

./build_busybox.sh
./build_rootfs.sh
./verify_rootfs.sh
```

Başarılı doğrulama sonrası:

```text
✓ BusyBox Derleme Tamamlandı
✓ RootFS Oluşturma Tamamlandı
✓ RootFS doğrulama tamamlandı
```
