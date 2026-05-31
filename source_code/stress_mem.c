/*
 * stress_mem.c — Dinamik Bellek Manipülatörü
 *
 * Amaç    : IPC pipeline'ının NORMAL ↔ CRITICAL geçişlerini tetiklemek
 * için belleği kademeli olarak doldurur ve serbest bırakır.
 *
 * Davranış:
 * - Başlangıçta tek satır uyarı mesajı basar, sonra sessizleşir.
 * - Her ALLOC_INTERVAL_SEC saniyede bir CHUNK_MB'lık bellek tahsis
 * ederek fiziksel RAM'e yazar (memset → swap'a kaçmasını önler).
 * - Toplam tahsis PEAK_MB'a ulaştığında tüm bellek free() ile
 * serbest bırakılır ve döngü baştan başlar.
 * - Döngü içi tüm mesajlar /tmp/stress.log dosyasına yazılır.
 *
 * Kullanım : ./stress_mem &
 *
 * Derleme  : aarch64-linux-gnu-gcc -static -O2 -o stress_mem stress_mem.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <signal.h>
#include <errno.h>
#include <stdarg.h>

/* ─── Ayarlar ───────────────────────────────────────────────── */
#define CHUNK_MB          50          /* Her adımda tahsis edilecek MB  */
#define PEAK_MB          400          /* Bu değere ulaşınca sıfırla     */
#define ALLOC_INTERVAL_SEC  3         /* Tahsis adımları arası bekleme  */
#define LOG_PATH         "/tmp/stress.log"

/* Maksimum chunk sayısı: PEAK_MB / CHUNK_MB (yuvarla yukarı) */
#define MAX_CHUNKS       ((PEAK_MB + CHUNK_MB - 1) / CHUNK_MB)

/* ─── Global değişkenler ────────────────────────────────────── */
static void  *chunks[MAX_CHUNKS];    /* Tahsis edilen blok adresleri   */
static int    chunk_count = 0;       /* Şu an kaç blok tahsis edildi   */
static FILE  *log_fp      = NULL;    /* Log dosyası tanıtıcısı         */

/* ─── Sinyal yöneticisi ─────────────────────────────────────── */
static volatile sig_atomic_t running = 1;

static void sig_handler(int sig)
{
    (void)sig;
    running = 0;
}

/* ─── Yardımcı: zaman damgalı log ──────────────────────────── */
static void log_msg(const char *fmt, ...)
{
    if (!log_fp) return;

    /* HH:MM:SS damgası */
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    if (t) fprintf(log_fp, "[%02d:%02d:%02d] ", t->tm_hour, t->tm_min, t->tm_sec);

    va_list ap;
    va_start(ap, fmt);
    vfprintf(log_fp, fmt, ap);
    va_end(ap);
    fputc('\n', log_fp);
    fflush(log_fp);
}

/* ─── Bellek Serbest Bırakıcı ───────────────────────────────── */
static void free_all(void)
{
    for (int i = 0; i < chunk_count; i++) {
        if (chunks[i]) {
            free(chunks[i]);
            chunks[i] = NULL;
        }
    }
    int freed = chunk_count;
    chunk_count = 0;
    log_msg("SERBEST BIRAKMA: %d chunk (%d MB) serbest bırakıldı — yeni döngü başlıyor",
            freed, freed * CHUNK_MB);
}

/* ─── main ─────────────────────────────────────────────────── */
int main(void)
{
    size_t chunk_bytes = (size_t)CHUNK_MB * 1024UL * 1024UL;

    /* Tek seferlik kullanıcı uyarısı — terminale (Kalın Sarı/Turuncu) */
    printf("\033[1;33mUYARI: Sistem belleği dinamik olarak manipüle ediliyor...\033[0m\n");
    printf("       Log: " LOG_PATH " | Peak: %d MB | Adım: %d MB / %d sn\n",
           PEAK_MB, CHUNK_MB, ALLOC_INTERVAL_SEC);
    fflush(stdout);

    /* Bundan sonra stdout'a hiç yazma — tüm çıktı log dosyasına */
    log_fp = fopen(LOG_PATH, "w");
    if (!log_fp) {
        log_fp = NULL;
    }

    /* Sinyal yakalayıcıları kur (Ctrl+C / kill ile temiz çıkış) */
    signal(SIGINT,  sig_handler);
    signal(SIGTERM, sig_handler);

    log_msg("stress_mem başlatıldı | PID=%d | Peak=%d MB | Chunk=%d MB",
            (int)getpid(), PEAK_MB, CHUNK_MB);

    memset(chunks, 0, sizeof(chunks));

    /* ─── Ana Döngü ─────────────────────────────────────────── */
    while (running) {
        if (chunk_count < MAX_CHUNKS) {
            /* Yeni chunk tahsis et */
            void *ptr = malloc(chunk_bytes);
            if (!ptr) {
                log_msg("malloc() başarısız (chunk %d) — bellek yetersiz, serbest bırakılıyor",
                        chunk_count);
                free_all();
                sleep(ALLOC_INTERVAL_SEC);
                continue;
            }

            /* Fiziksel RAM'e yaz: swap'a kaçmasını önler */
            memset(ptr, 0xAB, chunk_bytes);

            chunks[chunk_count++] = ptr;
            int total_mb = chunk_count * CHUNK_MB;

            log_msg("TAHSİS: chunk #%d | +%d MB | Toplam: %d MB / %d MB (%%%d)",
                    chunk_count, CHUNK_MB, total_mb, PEAK_MB,
                    (int)((long)total_mb * 100 / PEAK_MB));

            /* Zirveye ulaştık mı? */
            if (chunk_count >= MAX_CHUNKS) {
                log_msg("ZİRVE ULAŞILDI: %d MB — serbest bırakma hazırlığı (%d sn bekle)",
                        total_mb, ALLOC_INTERVAL_SEC);
                sleep(ALLOC_INTERVAL_SEC);
                free_all();
            }
        }

        sleep(ALLOC_INTERVAL_SEC);
    }

    /* Sinyal alındı — temizlik */
    log_msg("Sinyal alındı — tüm bellek serbest bırakılıyor");
    free_all();

    if (log_fp) fclose(log_fp);
    return EXIT_SUCCESS;
}