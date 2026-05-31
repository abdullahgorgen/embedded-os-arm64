/*
 * monitor.c — IPC Pipeline Aşama 2: Analiz ve Karar Mekanizması
 *
 * Görev : /tmp/pipe_1 FIFO'sundan collector'ın MemRawData struct'ını okur,
 *          bellek kullanım yüzdesini hesaplar, %80 eşiğine göre
 *          CRITICAL / NORMAL statüsü atar ve sonucu MemAnalysis struct'ı
 *          olarak /tmp/pipe_2 FIFO'suna yazar.
 *
 *          Ek özellik: Durum değişiminde /dev/sys_alarm (kernel modülü)
 *          arayüzüne '1' (CRITICAL) veya '0' (NORMAL) yazar.
 *
 * Derleme: aarch64-linux-gnu-gcc -static -o monitor monitor.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <sys/types.h>
#include <sys/stat.h>

/* ─── Sabitler ─────────────────────────────────────────── */
#define FIFO_PIPE1         "/tmp/pipe_1"
#define FIFO_PIPE2         "/tmp/pipe_2"
#define CRITICAL_THRESHOLD  80.0f   /* % — bu değerin üstü CRITICAL */
#define SYS_ALARM_DEV      "/dev/sys_alarm"  /* Kernel platform sürücüsü */

/* ─── Durum Enum'u ─────────────────────────────────────────── */
typedef enum {
    STATUS_NORMAL   = 0,
    STATUS_CRITICAL = 1
} MemStatus;

/* ─── Giriş Veri Yapısı (collector ile aynı) ───────────────── */
typedef struct {
    unsigned long mem_total_kb;
    unsigned long mem_free_kb;
    time_t        timestamp;
    unsigned int  seq;
} MemRawData;

/* ─── Çıkış Veri Yapısı (monitor → display) ────────────────── */
typedef struct {
    unsigned long mem_total_kb;   /* Toplam RAM (kB)              */
    unsigned long mem_used_kb;    /* Kullanılan RAM (kB)          */
    float         usage_pct;      /* Kullanım yüzdesi [0..100]    */
    MemStatus     status;         /* NORMAL veya CRITICAL         */
    time_t        timestamp;      /* Örnekleme anı                */
    unsigned int  seq;            /* Collector'dan gelen sıra no  */
} MemAnalysis;

/* ─── Analiz Motoru ────────────────────────────────────────── */
static void analyze(const MemRawData *raw, MemAnalysis *out)
{
    out->mem_total_kb = raw->mem_total_kb;
    out->mem_used_kb  = (raw->mem_total_kb > raw->mem_free_kb)
                        ? (raw->mem_total_kb - raw->mem_free_kb)
                        : 0UL;
    out->timestamp    = raw->timestamp;
    out->seq          = raw->seq;

    /* Sıfıra bölünmeyi önle */
    if (raw->mem_total_kb == 0) {
        out->usage_pct = 0.0f;
        out->status    = STATUS_NORMAL;
        return;
    }

    out->usage_pct = (float)out->mem_used_kb * 100.0f
                     / (float)raw->mem_total_kb;

    out->status = (out->usage_pct >= CRITICAL_THRESHOLD)
                  ? STATUS_CRITICAL
                  : STATUS_NORMAL;
}

/* ─── FIFO Okuyucu (blocking) ──────────────────────────────── */
/*
 * pipe_1'i blocking modda açar. collector henüz yazmamışsa
 * open() burada bloke olur — bu istenen davranış (back-pressure).
 */
static int read_from_pipe1(MemRawData *data)
{
    int fd;
    ssize_t n;

    fd = open(FIFO_PIPE1, O_RDONLY);   /* Blocking: veri gelene kadar bekle */
    if (fd < 0) {
        perror("[MONITOR] open(pipe_1)");
        return -1;
    }

    n = read(fd, data, sizeof(MemRawData));
    close(fd);

    if (n == 0) {
        fprintf(stderr, "[MONITOR] pipe_1 EOF — collector kapandı\n");
        return -1;
    }
    if (n != (ssize_t)sizeof(MemRawData)) {
        fprintf(stderr, "[MONITOR] Kısmi okuma: %zd/%zu bayt\n",
                n, sizeof(MemRawData));
        return -1;
    }
    return 0;
}

/* ─── FIFO Yazıcı ──────────────────────────────────────────── */
static int write_to_pipe2(const MemAnalysis *data)
{
    int fd;
    ssize_t written;

    fd = open(FIFO_PIPE2, O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        if (errno == ENXIO) {
            fprintf(stderr, "[MONITOR] display henüz açmadı pipe_2 "
                            "(seq=%u) — atlanıyor\n", data->seq);
        } else {
            perror("[MONITOR] open(pipe_2)");
        }
        return -1;
    }

    written = write(fd, data, sizeof(MemAnalysis));
    close(fd);

    if (written != (ssize_t)sizeof(MemAnalysis)) {
        fprintf(stderr, "[MONITOR] Kısmi yazma pipe_2: %zd/%zu bayt\n",
                written, sizeof(MemAnalysis));
        return -1;
    }
    return 0;
}

/* ─── Kernel Alarm Yazıcısı ─────────────────────────────────── */
/*
 * /dev/sys_alarm'a durum yazar: '1' = CRITICAL, '0' = NORMAL
 * Non-fatal: modül yüklenmemişse hata loglanır, çalışmaya devam eder.
 */
static void write_alarm(int alarm_fd, MemStatus status)
{
    const char val = (status == STATUS_CRITICAL) ? '1' : '0';
    ssize_t n;

    if (alarm_fd < 0) return;   /* Cihaz açılamadıysa atla */

    n = write(alarm_fd, &val, 1);
    if (n < 0)
        fprintf(stderr, "[MONITOR] /dev/sys_alarm yazılamadı: %s\n",
                strerror(errno));
}

/* ─── main ───────────────────────────────────────────────── */
int main(void)
{
    MemRawData   raw;
    MemAnalysis  analysis;
    const char  *status_str;
    MemStatus    prev_status = STATUS_NORMAL;   /* Durum değişimi takibi */
    int          alarm_fd;                      /* /dev/sys_alarm tanıtıcısı */

    fprintf(stdout,
            "[MONITOR] Başlatıldı.\n"
            "          Giriş : " FIFO_PIPE1 "\n"
            "          Çıkış : " FIFO_PIPE2 "\n"
            "          Eşik  : %.0f%%\n"
            "          Alarm : " SYS_ALARM_DEV "\n",
            CRITICAL_THRESHOLD);
    fflush(stdout);

    /* /dev/sys_alarm aç — modül yüklenmemişse devam et */
    alarm_fd = open(SYS_ALARM_DEV, O_WRONLY);
    if (alarm_fd < 0) {
        fprintf(stderr,
                "[MONITOR] UYARI: %s açılamadı (%s)\n"
                "          sys_alarm_driver.ko yüklenmemiş olabilir.\n"
                "          Pipeline devam ediyor, alarm devre dışı.\n",
                SYS_ALARM_DEV, strerror(errno));
    } else {
        fprintf(stdout, "[MONITOR] %s bağlantısı kuruldu (fd=%d)\n",
                SYS_ALARM_DEV, alarm_fd);
    }

    /* Her iki FIFO'yu oluştur — zaten varsa EEXIST sorun değil */
    if (mkfifo(FIFO_PIPE1, 0666) < 0 && errno != EEXIST)
        perror("[MONITOR] mkfifo(pipe_1)");   /* Uyarı, çıkış yok */

    if (mkfifo(FIFO_PIPE2, 0666) < 0 && errno != EEXIST) {
        perror("[MONITOR] mkfifo(pipe_2)");
        return EXIT_FAILURE;
    }

    /* ─── Ana Döngü ─────────────────────────────────────────── */
    while (1) {
        /* 1. Ham veriyi oku (blocking — collector yazana kadar bekle) */
        if (read_from_pipe1(&raw) < 0) {
            sleep(1);
            continue;
        }

        /* 2. Analiz et */
        analyze(&raw, &analysis);

        status_str = (analysis.status == STATUS_CRITICAL)
                     ? "CRITICAL" : "NORMAL";

        fprintf(stdout,
                "[MONITOR] #%u | Kullanım=%.1f%% | Durum=%s | "
                "Kullanılan=%lu kB / Toplam=%lu kB\n",
                analysis.seq, analysis.usage_pct, status_str,
                analysis.mem_used_kb, analysis.mem_total_kb);
        fflush(stdout);

        /* 3. Durum değişimi varsa kernel alarm arayüzüne yaz */
        if (analysis.status != prev_status) {
            write_alarm(alarm_fd, analysis.status);
            fprintf(stdout,
                    "[MONITOR] Durum değişimi: %s → %s → %s'e yazildı\n",
                    (prev_status == STATUS_CRITICAL) ? "CRITICAL" : "NORMAL",
                    status_str,
                    SYS_ALARM_DEV);
            fflush(stdout);
            prev_status = analysis.status;
        }

        /* 4. İşlenmiş veriyi pipe_2'ye yaz */
        write_to_pipe2(&analysis);
    }

    if (alarm_fd >= 0) close(alarm_fd);
    return EXIT_SUCCESS;
}
