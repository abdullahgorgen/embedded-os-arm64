# ARM64 Embedded Linux: Dinamik Bellek İzleme (IPC) ve Özel Çekirdek Sürücüsü Entegrasyonu 

## 1. Proje Özeti ve Akademik Amacı

Bu proje, ARM64 (aarch64) mimarisi hedeflenerek tasarlanmış, QEMU sanallaştırma ortamı üzerinde çalıştırılan ve BusyBox tabanlı minimal bir Kök Dosya Sistemi (RootFS) barındıran tam donanımlı bir Gömülü Linux (v6.1.75) işletim sistemidir. Akademik bağlamda "Yapay Zeka Destekli Mühendislik Geliştirme Süreci" yaklaşımı benimsenerek, gömülü sistemlerin temel alt katmanlarının (Derleme araç zinciri, Çekirdek yapılandırması, Cihaz Ağacı ve IPC) otonom şekilde entegre edilmesi hedeflenmiştir. 

Sistem, işletim sisteminin bellek tüketimini dinamik olarak test eden, bu tüketimi adlandırılmış boru hattı (Named Pipe - FIFO) mekanizması ile süreçler arası iletişim (IPC) sağlayarak toplayan, analiz eden ve terminal tabanlı bir arayüz ile görselleştiren kullanıcı uzayı (User Space) uygulamalarından oluşmaktadır. Ayrıca, analitik veriler neticesinde kritik bellek eşiği (%80) aşıldığında, ağaç dışı (Out-of-Tree) derlenmiş ve özel bir Device Tree (DTS) düğümü (marmara,system-alarm) ile eşleştirilmiş `sys_alarm_driver.ko` çekirdek modülü üzerinden donanımsal bir alarm mekanizması tetiklenmektedir. Tüm bu karmaşık mimari bileşenler, sistem izolasyonunu ve tekrarlanabilirliği sağlamak amacıyla Docker konteynerleri içerisinde yürütülen otonom bash betikleriyle derlenmektedir.

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

Aşağıdaki yapı, kaynak kod yönetim sistemindeki (Repository) temel durumu ifade eder. Özellikle `rootfs`, `qemu` ve `dts` dizinleri depoda yalnızca kalıcı kılınabilmesi amacıyla `.gitkeep` dosyasıyla veya asgari betiklerle barındırılmaktadır. İlgili otonom betikler (`build_kernel_full.sh` ve `build_all.sh`) çalıştırıldığında; Linux kaynak kodları `qemu/` dizinine indirilir, derlenen Ext4 imajları `rootfs/` dizinine yaratılır ve özel Device Tree yapıları `dts/` dizininde dinamik olarak doldurulur.

```text
├── docker
│   ├── Dockerfile
│   └── build.sh
├── dts
│   └── extract_dts.sh
├── qemu
│   └── Makefile
├── rootfs
│   └── .gitkeep
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
├── README.md
├── boot_qemu.sh
├── build_all.sh
├── build_kernel_full.sh
└── clean_all.sh
```

## 4. Kurulum ve Otonom Derleme Adımları

Tüm süreç, ana makinenin yalıtımını korumak ve bağımlılık sorunlarını minimize etmek için Docker ile otomatize edilmiştir. 

### 4.1. Projenin Klonlanması
Mimarinin yapı taşlarını barındıran kaynak kod deposunu yerel çalışma ortamınıza indiriniz ve proje kök dizinine geçiş yapınız:
```bash
git clone https://github.com/abdullahgorgen/embedded-os-arm64.git
cd embedded-os-arm64
```

### 4.2. Konteyner İmajının Hazırlanması (arm64-embedded-dev)
Projeyi sisteminize ilk klonladığınızda, çapraz derleyici (cross-compiler) ve QEMU araçlarını barındıran temel Docker imajını oluşturmanız gerekmektedir.
```bash
cd docker
./build.sh
cd ..
```

### 4.3. Çekirdek İndirme ve Çapraz Derleme
Çekirdeğin (Linux v6.1.75) sıfırdan indirilip, `aarch64-linux-gnu-` ön ekiyle derlenmesi için aşağıdaki otonom betik kullanılır. İşlem sonucunda `qemu/Image` oluşturulur.
```bash
docker run --rm -it --privileged -v $(pwd):/workspace arm64-embedded-dev:latest bash /workspace/build_kernel_full.sh
```

### 4.4. Sistemin Otonom Derlenmesi
Projenin kullanıcı uzayı, çekirdek eklentisi, RootFS paketlemesi ve donanım ağacı operasyonları tek bir komutla derlenir.
```bash
docker run --rm -it --privileged -v $(pwd):/workspace -e "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" arm64-embedded-dev:latest bash /workspace/build_all.sh
```
`build_all.sh` betiğinin yürüttüğü işlemler sırasıyla şunlardır:
1.  **Çekirdek Hazırlığı:** Ağaç dışı (Out-of-Tree) modül derlemesi için kaynak kodda `modules_prepare` çalıştırılır.
2.  **Kullanıcı Uzayı Derlemesi:** C kaynak kodları statik olarak (`-static`) derlenir, `strip` işleminden geçirilerek RootFS için sahnelenir.
3.  **Kernel Sürücü Derlemesi:** Çapraz araç zinciriyle `sys_alarm_driver.ko` oluşturulur.
4.  **Device Tree Manipülasyonu:** QEMU üzerinden çıkartılan ham `virt` cihaz ağacına `marmara,system-alarm` düğümü enjekte edilir ve yeni bir `custom_virt_machine.dtb` dosyası üretilir.
5.  **RootFS (Kök Dosya Sistemi) Paketlenmesi:** Ext4 formatında imaj yaratılır, BusyBox kopyalanır, gerekli fstab/init betikleri ayarlanır ve üretilen tüm IPC çalıştırılabilir dosyaları `/usr/bin/` dizinine, çekirdek modülü ise `/lib/modules/` dizinine yerleştirilir.

### 4.5. Ortam Temizliği
Derleme sonrası üretilen .o dosyaları, modüller ve imajları temizlemek için iki aşamalı `clean_all.sh` yapısı kurgulanmıştır.
*   **Standart Temizlik:** Yalnızca kullanıcı uzayı ve modül kalıntılarını temizler.
*   **Derin Temizlik (`--deep`):** Çekirdek kaynak kodları dahil indirilen ve üretilen her şeyi arındırarak depoyu fabrika ayarlarına döndürür.
```bash
docker run --rm -it --privileged -v $(pwd):/workspace arm64-embedded-dev:latest bash /workspace/clean_all.sh
```

## 5. Sistemin Başlatılması ve Test

Oluşturulan nihai `Image`, `custom_virt_machine.dtb` ve `rootfs.img` bileşenleri kullanılarak emülatörün başlatılması tek bir otonom betik üzerinden gerçekleştirilir. Ana makinede (WSL terminalinde) şu komutu çalıştırın:
```bash
./boot_qemu.sh
```
Sistem yüklendikten sonra kök (`~ #`) terminalinde sırasıyla şu test senaryosunu icra edin:

```sh
# 1. Platform sürücüsünü sisteme yükleyin
insmod /lib/modules/sys_alarm_driver.ko

# 2. Arka planda donanım yük testini başlatın
stress_mem &

# 3. İletişim boru hattını (IPC Pipeline) ve grafiksel arayüzü başlatın
meminfo
```
Sistem %80 bellek kullanımını aştığında, arka planda çekirdek alanında donanımsal alarmların (dmesg) tetiklendiği raporlanacaktır.

