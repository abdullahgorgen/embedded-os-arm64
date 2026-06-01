# Gömülü Linux IPC ve Platform Sürücüsü Entegrasyonu

## 1. Proje Özeti ve Amacı
Bu proje, ARM64 (aarch64) mimarisi hedeflenerek QEMU sanallaştırma ortamı üzerinde çalışacak şekilde tasarlanmış, baştan sona entegre bir gömülü Linux sistemini temsil etmektedir. Projenin temel amacı, işletim sisteminin bellek tüketimini gerçek zamanlı izleyen, süreçler arası iletişim (IPC) mekanizmalarıyla verileri işleyen ve kritik eşik aşıldığında özel olarak geliştirilmiş bir çekirdek platform sürücüsü (Kernel Platform Driver) aracılığıyla donanımsal alarm üreten kapalı devre bir ekosistem inşa etmektir. Kök dosya sistemi (RootFS) BusyBox tabanlı olarak mimariye uygun minimum düzeyde yapılandırılmış olup, Linux çekirdeği (v6.1.75) ve cihaz ağacı (Device Tree) hedefe özgü optimize edilmiştir.

## 2. Sistem Mimarisi ve Özellikler

### Kullanıcı Uzayı (User Space)
Kullanıcı uzayındaki işlemler, sistem belleğini manipüle eden ve bu manipülasyonu analiz eden 4 farklı C bileşeni ile orkestre edilmektedir:
*   **`stress_mem`:** Sistemi dinamik olarak manipüle eden test bileşenidir. Sonsuz bir döngü içerisinde önceden belirlenmiş eşiğe (400 MB) kadar belleği 50 MB'lık bloklar halinde tahsis eder (`malloc`) ve fiziksel RAM'e yazar (`memset`). Hedefe ulaştığında ayrılan belleği serbest bırakarak bir "bellek sızıntısı/baskısı" simülasyonu yaratır.
*   **`collector`:** `/proc/meminfo` dosyasından anlık bellek durumunu (MemTotal, MemFree) okuyup yapısal bir formata dönüştürerek birinci Named Pipe (FIFO) mekanizması olan `/tmp/pipe_1`'e aktarır.
*   **`monitor`:** Analiz ve karar mekanizmasıdır. `/tmp/pipe_1`'den okuduğu veriler üzerinden bellek kullanım yüzdesini hesaplar. Önceden tanımlanmış %80 kritik eşik (CRITICAL_THRESHOLD) değeri aşıldığında çekirdek uzayı bileşeni olan `/dev/sys_alarm` aygıt dosyasına yazma işlemi gerçekleştirir. Çıktılarını formatlayarak `/tmp/pipe_2`'ye yazar.
*   **`display`:** `/tmp/pipe_2`'den gelen işlenmiş verileri okuyarak tek TTY (single TTY) kısıtlamasına uygun, ASCII grafikli ve renkli bir arayüz ile terminal ekranına yansıtır.

### Çekirdek Uzayı (Kernel Space)
Sistemde karakter aygıtı arayüzü sunan, ağaç dışı (Out-of-Tree) derlenen `sys_alarm_driver.ko` platform sürücüsü bulunmaktadır:
*   **Görev:** Kullanıcı uzayındaki `monitor` uygulamasının aldığı kritik eşik kararlarına göre donanımsal düzeyde (dmesg logları aracılığıyla simüle edilen) reaksiyon vermek.
*   **Donanım Adreslemesi:** Sürücü, `marmara,system-alarm` compatible özelliğine sahip Device Tree düğümü ile eşleşir. `0x09080000` MMIO adresinden başlar. `devm_ioremap_resource` ile güvenli sanal bellek ataması sağlanır ve `misc_register` aracılığıyla `/dev/sys_alarm` dinamik düğümü oluşturulur.

### Donanım Soyutlama Katmanı
Sanal donanımın çekirdeğe tanıtılması Device Tree Source (DTS) manipülasyonu ile sağlanır:
*   QEMU virt makinesinin orijinal DTB yapısı çıkarılarak (dumpdtb) DTS formatına ayrıştırılır.
*   Kök düğüm içerisine `system_alarm@09080000` bileşeni özellikleri (compatible, reg, status, label) ile enjekte edilir.
*   Enjeksiyonun ardından yapı, QEMU tarafından okunabilecek `custom_virt_machine.dtb` (Device Tree Blob) formatına geri derlenir.

## 3. Gereksinimler (Prerequisites)
Sistemin izolasyonunu korumak ve bağımlılık çakışmalarını önlemek amacıyla tüm süreç bir Docker konteyneri içerisinde yürütülür. Host sistem üzerinde aşağıdakilerin bulunması zorunludur:
*   **İşletim Sistemi:** Windows Subsystem for Linux 2 (WSL2 - Ubuntu 22.04 veya eşdeğeri).
*   **Docker Engine:** Konteyner tabanlı çapraz derleme ortamı (`arm64-embedded-dev:latest` imajı) için.
*   **Derleme Araçları (Konteyner içi):** `aarch64-linux-gnu-gcc` aracı zinciri, `make`, `bc`, `bison`, `flex`, `python3`, `device-tree-compiler`.
*   **Emülatör (Konteyner içi):** `qemu-system-aarch64`.

## 4. Temizlik ve Derleme Süreci (Build Instructions)

Tüm derleme işlemleri, yol kısıtlamaları ve kök dosya sistemi (RootFS) izinleri nedeniyle ayrıcalıklı Docker modunda çalıştırılmalıdır.

### İlk Kurulum: Docker İmajının İnşası
Projenin izolasyonunu sağlamak ve gerekli araç zincirlerini (çapraz derleyici vb.) yapılandırmak için öncelikle geliştirme ortamı konteyner imajının inşa edilmesi gerekir. `docker/build.sh` betiği ile bu imaj yerel sisteminizde oluşturulur. Bu işlemi projeyi ilk indirdiğinizde bir kez yapmanız yeterlidir:
```bash
cd docker
./build.sh
cd ..
```

### Derleme
Tüm proje yapısı tek bir otomasyon betiği olan `build_all.sh` üzerinden derlenir. Aşağıdaki komut kullanılarak tüm yapılandırma yürütülür (veya docker başlatıcısı `run_build_in_docker.sh` ile):
```bash
docker run --rm -it --privileged -v $(pwd):/workspace -e "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" arm64-embedded-dev:latest bash /workspace/build_all.sh
```
`build_all.sh` betiğinin işlev adımları:
1.  **Kernel Hazırlığı:** Linux kaynak koduna geçiş yapılır, `defconfig` ayarlanır ve Out-of-Tree sürücü derlemesi için gerekli olan semboller/başlıklar `make modules_prepare` komutuyla üretilir.
2.  **Platform Sürücüsünün Derlenmesi:** `sys_alarm_driver.c`, çapraz derleme aracı ile `.ko` olarak derlenir.
3.  **Kullanıcı Uzayı (IPC) Derlemesi:** C kaynak kodları statik olarak (`-static`) derlenir ve gereksiz sembollerden (`strip`) arındırılır.
4.  **Device Tree Üretimi:** Orijinal QEMU virt DTB dosyası ayrıştırılır, özel `marmara,system-alarm` düğümü eklenir ve `custom_virt_machine.dtb` olarak derlenir.
5.  **RootFS Paketleme:** BusyBox, `ext4` formatında oluşturulan 512 MB boyutundaki boş imaj dosyasına yerleştirilir. Gerekli sistem dizinleri açılır, `/etc/fstab`, `/init` betiği yapılandırılır. Akabinde IPC süreçleri `/usr/bin/` dizinine, çekirdek modülü ise `/lib/modules/` dizinine taşınır ve imaj bağlanarak (`mount`) değişiklikler diske yazılır.

### Ortam Temizliği
Önceki derlemelerden kalan nesne dosyaları, derlenmiş kernel modülleri, imajlar ve IPC uygulamalarının temizlenmesi gereklidir. `clean_all.sh` betiği bu arındırma işlemini gerçekleştirir:
```bash
docker run --rm -it --privileged -v $(pwd):/workspace arm64-embedded-dev:latest bash /workspace/clean_all.sh
```

## 5. Sistemin Başlatılması (Execution)
Derleme aşamasından elde edilen Kernel (`Image`), Device Tree (`custom_virt_machine.dtb`) ve Dosya Sistemi (`rootfs.img`) kullanılarak sanal makinenin başlatılması için QEMU komutu aşağıdaki gibidir:

```bash
docker run --rm -it --privileged -v $(pwd):/workspace -e "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" arm64-embedded-dev:latest qemu-system-aarch64 \
    -machine virt \
    -cpu cortex-a72 \
    -m 512M \
    -smp 2 \
    -kernel /workspace/qemu/Image \
    -dtb /workspace/dts/custom_virt_machine.dtb \
    -drive file=/workspace/rootfs/rootfs.img,format=raw,if=virtio \
    -append "root=/dev/vda rw console=ttyAMA0 earlycon init=/init" \
    -nographic
```

Sistem başlatıldıktan sonra Root terminaline (`~ #`) ulaşıldığında sırasıyla çalıştırılacak komutlar:
```sh
# 1. Çekirdek sürücüsünü yükle
insmod /lib/modules/sys_alarm_driver.ko

# 2. Bellek manipülatörünü arka planda başlat
stress_mem &

# 3. IPC Orkestrasyonunu çalıştır
meminfo
```

## 6. Dizin Hiyerarşisi (Repository Structure)

```text

embedded-os-arm64/
├── README.md               # Proje dokümantasyonu
├── build_all.sh            # Tam üretim ve derleme (pipeline) betiği
├── clean_all.sh            # Çalışma alanı temizlik betiği (varsa/opsiyonel)
├── run_build_in_docker.sh  # Docker sarmalayıcısı (varsa/opsiyonel)
├── docker/
│   ├── Dockerfile          # Çapraz derleme ve QEMU ortamı kapsayıcı tarifi
│   └── build.sh            # Docker imajı (arm64-embedded-dev) oluşturma betiği
├── dts/
│   ├── extract_dts.sh      # QEMU'dan orijinal DTB çekme betiği
│   ├── custom_virt_machine.dts  # Sanal donanım eklenmiş Device Tree Source
│   └── custom_virt_machine.dtb  # QEMU'da koşturulacak derlenmiş DTB
├── qemu/
│   ├── linux-6.1.75/       # Çekirdek kaynak kodu (ve modules_prepare hedefi)
│   └── Image               # Derlenmiş ARM64 Linux Çekirdeği
├── rootfs/
│   ├── build_rootfs.sh     # Busybox paketleme ve binary enjeksiyon betiği
│   └── rootfs.img          # Üretilen nihai dosya sistemi diski (ext4)
└── source_code/
    ├── Makefile            # IPC uygulamaları C kodları derleme talimatları
    ├── meminfo.sh          # IPC arka plan/ön plan orkestrasyon betiği
    ├── collector.c         # Veri üretim C modülü (Aşama 1)
    ├── monitor.c           # Analiz, Alarm ve Karar C modülü (Aşama 2)
    ├── display.c           # ASCII TTY gösterim C modülü (Aşama 3)
    ├── stress_mem.c        # Dinamik Bellek Manipülatör C modülü
    └── driver/
        ├── sys_alarm_driver.c # Kernel karakter/platform aygıtı sürücüsü
        └── Makefile           # Out-of-tree modül (.ko) derleme talimatları
```
