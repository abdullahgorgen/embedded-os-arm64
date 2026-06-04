# ARM64 Embedded Linux: Dinamik Bellek İzleme (IPC) ve Özel Çekirdek Sürücüsü Entegrasyonu 

## 1. Proje Özeti ve Akademik Amacı

Bu proje, ARM64 (aarch64) mimarisi hedeflenerek tasarlanmış, QEMU sanallaştırma ortamı üzerinde çalıştırılan ve BusyBox tabanlı minimal bir Kök Dosya Sistemi (RootFS) barındıran tam donanımlı bir Gömülü Linux (v6.1.75) işletim sistemidir. Akademik bağlamda "Yapay Zeka Destekli Mühendislik Geliştirme Süreci" yaklaşımı benimsenerek, gömülü sistemlerin temel alt katmanlarının (Derleme araç zinciri, Çekirdek yapılandırması, Cihaz Ağacı ve IPC) otonom şekilde entegre edilmesi hedeflenmiştir. 

Sistem, işletim sisteminin bellek tüketimini dinamik olarak test eden, bu tüketimi adlandırılmış boru hattı (Named Pipe - FIFO) mekanizması ile süreçler arası iletişim (IPC) sağlayarak toplayan, analiz eden ve terminal tabanlı bir arayüz ile görselleştiren kullanıcı uzayı (User Space) uygulamalarından oluşmaktadır. Ayrıca, analitik veriler neticesinde kritik bellek eşiği (%80) aşıldığında, ağaç dışı (Out-of-Tree) derlenmiş ve özel bir Device Tree (DTS) düğümü (marmara,system-alarm) ile eşleştirilmiş `sys_alarm_driver.ko` çekirdek modülü üzerinden donanımsal bir alarm mekanizması tetiklenmektedir. Tüm bu karmaşık mimari bileşenler, sistem izolasyonunu ve tekrarlanabilirliği sağlamak amacıyla kök dizindeki merkezi `Makefile` tarafından yönetilen Docker tabanlı üretim hattıyla derlenmektedir.

## 2. Mimari Detaylar

### 2.1. Kullanıcı Uzayı (User Space ve IPC)
Kullanıcı uzayında yer alan süreçler, sistem belleğini manipüle eden ve ardından izleyerek kararlar alan C dili ile yazılmış dört temel bileşenden oluşur. Bu bileşenler bağımsız (statik) olarak derlenmiş ve FIFO boru hattı ile ardışık bağlanmıştır:
*   **`stress_mem`:** Sistemi yük testine tabi tutan temel modüldür. Sonsuz bir döngü içerisinde önceden tanımlanmış maksimum eşiğe (400 MB) ulaşana kadar belleği 50 MB'lık bloklar halinde ayırarak fiziksel RAM sınırlarını zorlar ve sınır aşıldığında tahsis edilen alanı serbest bırakır.
*   **`collector`:** Sistem çekirdeğinin sağladığı `/proc/meminfo` sanal dosyasını dinleyerek toplam ve boş bellek (MemTotal, MemFree) metriklerini toplar ve ikili (binary) bir yapı halinde `/tmp/pipe_1` boru hattına aktarır.
*   **`monitor`:** Sistem durum analiz modülüdür. `/tmp/pipe_1` üzerinden ham veriyi devralır, bellek doluluk yüzdesini hesaplar. Bu oran %80'lik kritik seviyeyi aştığında çekirdek uzayındaki `/dev/sys_alarm` düğümüne `1` değerini (alarm aktif), eşik altına düştüğünde ise `0` değerini gönderir. Ardından işlenmiş yapısal durumu `/tmp/pipe_2` boru hattına iletir.
*   **`display`:** `/tmp/pipe_2` boru hattından gelen işlenmiş verileri okur ve tek TTY konsolu kısıtlamalarına uygun olarak sürekli güncellenen, renkli bir ASCII bar grafiği formatında sisteme yansıtır.

### 2.2. Çekirdek Uzayı (Kernel Space)
Sistem donanım soyutlamasını ve reaksiyonunu sağlamak üzere Linux çekirdek mimarisine uygun, karakter tabanlı bir platform sürücüsü geliştirilmiştir:
*   **`sys_alarm_driver.ko`:** Çekirdek ağacı dışında (Out-of-Tree) ARM64 mimarisine çapraz derlenmiş platform sürücüsüdür.
*   **Donanım Adreslemesi ve Yaşam Döngüsü:** Sürücü, Device Tree içerisindeki `marmara,system-alarm` compatible dizilimi ile eşleştiğinde `probe()` fonksiyonunu tetikler. Bu aşamada QEMU virt makinesi için rezerve edilmiş güvenli `0x09080000` MMIO adres aralığı `devm_ioremap_resource()` fonksiyonu ile sanal belleğe eşlenir.
*   **File Operations (fops) Mantığı:** Sürücü başlatıldığında `misc_register` aracılığıyla `/dev/sys_alarm` kullanıcı uzayı cihaz dosyasını oluşturur. Uygulanan `write()` file_operations fonksiyonu üzerinden karakter okur; eğer '1' gelirse çekirdek günlüğüne (dmesg) `[DONANIM] Kirmizi Alarm Aktif!` şeklinde, '0' gelirse `[DONANIM] Alarm Devre Disi.` şeklinde uyarı mesajı basarak donanımsal seviye reaksiyonları simüle eder.

## 3. Güncel Dizin Hiyerarşisi

Aşağıdaki yapı, kaynak kod yönetim sistemindeki (Repository) temel durumu ifade eder. Özellikle `rootfs`, `qemu` ve `dts` dizinleri depoda yalnızca kalıcı kılınabilmesi amacıyla `.gitkeep` dosyasıyla barındırılmaktadır. Kök dizindeki `Makefile` tek kullanıcı arayüzüdür; ağır derleme ve imaj üretim betikleri yalnızca `scripts/` altında iç uygulama detayı olarak tutulur.

```text
├── docker
│   └── Dockerfile
├── dts
│   └── .gitkeep
├── qemu
│   └── .gitkeep
├── rootfs
│   └── .gitkeep
├── scripts
│   ├── build_all.sh
│   └── build_kernel_full.sh
├── source_code
│   ├── driver
│   │   ├── Makefile
│   │   └── sys_alarm_driver.c
│   ├── Makefile
│   ├── collector.c
│   ├── display.c
│   ├── meminfo.sh
│   ├── monitor.c
│   └── stress_mem.c
├── .gitignore
├── Makefile
└── README.md
```

## 4. Kurulum ve Otonom Derleme Adımları

Derleme, başlatma, temizleme ve tam sıfırlama işlemleri proje kök dizinindeki evrensel `Makefile` üzerinden yürütülür. Kullanıcı, Docker konteynerini veya alt bash betiklerini doğrudan çağırmaz; müdahale noktası yalnızca `make` hedefleridir. Kök `Makefile`, Docker imajı üretimini, çekirdek derlemesini, sistem imajı paketlemesini, QEMU başlatmasını ve host üzerinde çalışan temizlik adımlarını merkezi olarak orkestre eder.

### 4.1. Projenin Klonlanması
Mimarinin yapı taşlarını barındıran kaynak kod deposunu yerel çalışma ortamınıza indiriniz ve proje kök dizinine geçiş yapınız:
```bash
git clone https://github.com/abdullahgorgen/embedded-os-arm64.git
cd embedded-os-arm64
```

### 4.2. Tam Otonom Derleme
Docker imajı, Linux çekirdeği, kullanıcı uzayı bileşenleri, çekirdek modülü, Device Tree çıktıları ve RootFS imajı tek komutla sıralı biçimde üretilir:
```bash
make all
```
`make all` hedefi sırasıyla `docker-image`, `kernel` ve `system` hedeflerini çalıştırır.

### 4.3. Ayrık Derleme Hedefleri
Gerektiğinde üretim hattının belirli bir aşaması doğrudan çağrılabilir:
```bash
make docker-image
make kernel
make system
make boot
```
`make docker-image`, `docker/Dockerfile` üzerinden `arm64-embedded-dev:latest` imajını doğrudan üretir. `make kernel`, `scripts/build_kernel_full.sh` iş mantığını ayrıcalıklı Docker konteyneri içinde çalıştırır ve `qemu/Image` çıktısını üretir. `make system`, `scripts/build_all.sh` iş mantığını aynı kontrollü konteyner ortamında yürütür; kullanıcı uzayı binary'lerini, `sys_alarm_driver.ko` modülünü, özel DTB dosyasını ve `rootfs/rootfs.img` imajını üretir. `make boot`, üretilen kernel, DTB ve RootFS imajını QEMU üzerinde başlatır.

Konteyner içinde root yetkisiyle üretilen dosyaların host üzerinde silinememesi veya değiştirilememesi problemini engellemek için derleme betikleri işlem sonunda `/workspace` sahipliğini host kullanıcı kimliğine devreder.

`make system` hedefinin yürüttüğü işlemler sırasıyla şunlardır:
1.  **Çekirdek Hazırlığı:** Ağaç dışı (Out-of-Tree) modül derlemesi için kaynak kodda `modules_prepare` çalıştırılır.
2.  **Kullanıcı Uzayı Derlemesi:** C kaynak kodları statik olarak (`-static`) derlenir, `strip` işleminden geçirilerek RootFS için sahnelenir.
3.  **Kernel Sürücü Derlemesi:** Çapraz araç zinciriyle `sys_alarm_driver.ko` oluşturulur.
4.  **Device Tree Manipülasyonu:** QEMU üzerinden çıkartılan ham `virt` cihaz ağacına `marmara,system-alarm` düğümü enjekte edilir ve yeni bir `custom_virt_machine.dtb` dosyası üretilir.
5.  **RootFS Paketleme:** Ext4 formatında imaj yaratılır, BusyBox kopyalanır, gerekli `fstab` ve `init` betikleri ayarlanır; IPC çalıştırılabilir dosyaları `/usr/bin/` dizinine, çekirdek modülü ise `/lib/modules/` dizinine yerleştirilir.

### 4.4. Ortam Temizliği
Temizlik işlemleri Docker konteyneri başlatmadan, doğrudan host makine üzerinde standart shell komutlarıyla çalışır:
```bash
make clean
make distclean
```
`make clean`, kullanıcı uzayı binary'lerini, sürücü ara çıktılarını, Device Tree çıktılarını, RootFS staging dizinini ve `rootfs.img` dosyasını siler. `make distclean`, standart temizliğe ek olarak indirilen Linux kaynak ağacını, Linux arşivini, `qemu/Image` dosyasını, BusyBox kaynaklarını, BusyBox arşivini ve BusyBox kurulum dizinini kaldırır.

## 5. Sistemin Başlatılması ve Test

Oluşturulan nihai `Image`, `custom_virt_machine.dtb` ve `rootfs.img` bileşenleri kullanılarak emülatör Makefile üzerinden başlatılır. Ana makinede şu komutu çalıştırın:
```bash
make boot
```
Boot sırasında RootFS içindeki `/etc/init.d/rcS` betiği otomatik çalışır ve `sys_alarm_driver.ko` modülünü `/sbin/insmod /lib/modules/sys_alarm_driver.ko` komutuyla sisteme yükler. Bu nedenle kullanıcı terminalinde ayrıca `insmod` çalıştırılmayacaktır.

Sistem yüklendikten sonra kök (`~ #`) terminalinde yalnızca test yükü ve IPC izleme hattı manuel başlatılır:
```sh
# 1. Bellek yük testini arka planda başlatın
stress_mem &

# 2. IPC boru hattını ve terminal arayüzünü başlatın
meminfo
```
`stress_mem` ve `meminfo` init sürecine dahil edilmez; bu süreçlerin yaşam döngüsü kullanıcı kontrolündedir. Sistem %80 bellek kullanımını aştığında `monitor`, otomatik yüklenmiş `/dev/sys_alarm` sürücüsüne alarm durumunu iletir ve çekirdek alanında donanımsal alarm mesajları üretilir.
