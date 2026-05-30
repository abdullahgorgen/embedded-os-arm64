/*
 * collector.c — IPC Pipeline Aşama 1: Veri Üretici
 *
 * Görev : /proc/meminfo'dan MemTotal ve MemFree değerlerini okur,
 *          bir MemRawData struct'ı içine paketler ve
 *          /tmp/pipe_1 FIFO'suna her 2 saniyede bir yazar.
 *
 * Derleme: aarch64-linux-gnu-gcc -static -o collector collector.c
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

/* ─── Sabitler ─────────────────────────────────────────────── */
#define FIFO_PIPE1   "/tmp/pipe_1"
#define MEMINFO_PATH "/proc/meminfo"
#define INTERVAL_SEC  2          /* Örnekleme aralığı (saniye) */
#define LINE_BUF      256

/* ─── Veri Yapısı ──────────────────────────────────────────── */
/*
 * MemRawData: collector → monitor arasında taşınan ham veri.
 * Struct binary olarak FIFO'ya yazılır; monitor aynı typedef'i
 * include etmeden okuyabilmek için ortak tanım burada tutulur.
 */
typedef struct {
    unsigned long mem_total_kb;   /* /proc/meminfo: MemTotal   */
    unsigned long mem_free_kb;    /* /proc/meminfo: MemFree    */
    time_t        timestamp;      /* Örnekleme anı (epoch)     */
    unsigned int  seq;            /* Mesaj sıra numarası       */
} MemRawData;

/* ─── /proc/meminfo Okuyucu ────────────────────────────────── */
static int read_meminfo(unsigned long *total, unsigned long *free_mem)
{
    FILE *fp;
    char line[LINE_BUF];
    int found_total = 0, found_free = 0;

    fp = fopen(MEMINFO_PATH, "r");
    if (!fp) {
        perror("[COLLECTOR] fopen(" MEMINFO_PATH ")");
        return -1;
    }

    while (fgets(line, sizeof(line), fp)) {
        if (!found_total && strncmp(line, "MemTotal:", 9) == 0) {
            sscanf(line, "MemTotal: %lu kB", total);
            found_total = 1;
        } else if (!found_free && strncmp(line, "MemFree:", 8) == 0) {
            sscanf(line, "MemFree: %lu kB", free_mem);
            found_free = 1;
        }
        /* Her iki değer de bulunduysa döngüyü erken kır */
        if (found_total && found_free) break;
    }

    fclose(fp);

    if (!found_total || !found_free) {
        fprintf(stderr, "[COLLECTOR] MemTotal veya MemFree okunamadı\n");
        return -1;
    }
    return 0;
}

/* ─── FIFO'ya Yazıcı ───────────────────────────────────────── */
/*
 * FIFO her döngüde O_WRONLY | O_NONBLOCK ile açılır.
 * Okuyucu (monitor) hazır değilse ENXIO döner → hata loglanır,
 * bir sonraki döngüde yeniden denenir.
 */
static int write_to_fifo(const MemRawData *data)
{
    int fd;
    ssize_t written;

    /* Engelleme olmadan aç: okuyucu yoksa hemen hata ver */
    fd = open(FIFO_PIPE1, O_WRONLY | O_NONBLOCK);
    if (fd < 0) {
        if (errno == ENXIO) {
            fprintf(stderr, "[COLLECTOR] Okuyucu yok — monitor başlatıldı mı? "
                            "(seq=%u)\n", data->seq);
        } else {
            perror("[COLLECTOR] open(pipe_1)");
        }
        return -1;
    }

    written = write(fd, data, sizeof(MemRawData));
    close(fd);

    if (written != (ssize_t)sizeof(MemRawData)) {
        fprintf(stderr, "[COLLECTOR] Kısmi yazma: %zd/%zu bayt\n",
                written, sizeof(MemRawData));
        return -1;
    }
    return 0;
}

/* ─── main ─────────────────────────────────────────────────── */
int main(void)
{
    MemRawData data;
    unsigned int seq = 0;
    int ret;

    fprintf(stdout,
            "[COLLECTOR] Başlatıldı. FIFO: " FIFO_PIPE1
            ", Aralık: %d sn\n", INTERVAL_SEC);
    fflush(stdout);

    /* FIFO oluştur — zaten varsa mkfifo EEXIST döner, sorun değil */
    if (mkfifo(FIFO_PIPE1, 0666) < 0 && errno != EEXIST) {
        perror("[COLLECTOR] mkfifo(" FIFO_PIPE1 ")");
        return EXIT_FAILURE;
    }

    /* ─── Ana Döngü ─────────────────────────────────────────── */
    while (1) {
        memset(&data, 0, sizeof(data));
        data.seq       = ++seq;
        data.timestamp = time(NULL);

        ret = read_meminfo(&data.mem_total_kb, &data.mem_free_kb);
        if (ret == 0) {
            ret = write_to_fifo(&data);
            if (ret == 0) {
                fprintf(stdout,
                        "[COLLECTOR] #%u gönderildi | "
                        "Total=%lu kB  Free=%lu kB\n",
                        data.seq, data.mem_total_kb, data.mem_free_kb);
                fflush(stdout);
            }
        }

        sleep(INTERVAL_SEC);
    }

    /* Buraya ulaşılmaz */
    return EXIT_SUCCESS;
}
