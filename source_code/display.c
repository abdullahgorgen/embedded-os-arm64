/*
 * display.c — IPC Pipeline Aşama 3: Görüntüleyici
 *
 * Görev : /tmp/pipe_2 FIFO'sundan monitor'ın MemAnalysis struct'ını okur
 *          ve her güncellemeyi terminalde ASCII tablo formatında gösterir.
 *          Ekran her döngüde yerinde güncellenir (ANSI escape kodları).
 *
 * Derleme: aarch64-linux-gnu-gcc -static -o display display.c
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
#define FIFO_PIPE2    "/tmp/pipe_2"
#define BAR_WIDTH     30          /* ASCII progress bar genişliği */

/* ─── ANSI Renk Kodları ────────────────────────────────────── */
#define ANSI_RESET    "\033[0m"
#define ANSI_BOLD     "\033[1m"
#define ANSI_RED      "\033[31m"
#define ANSI_GREEN    "\033[32m"
#define ANSI_YELLOW   "\033[33m"
#define ANSI_CYAN     "\033[36m"
#define ANSI_WHITE    "\033[37m"
#define ANSI_BG_RED   "\033[41m"
#define ANSI_BG_GREEN "\033[42m"

/* ANSI: İmleç başa dön + ekranı temizle */
#define CLEAR_SCREEN  "\033[2J\033[H"

/* ─── Veri Yapısı (monitor ile aynı) ───────────────────────── */
typedef enum {
    STATUS_NORMAL   = 0,
    STATUS_CRITICAL = 1
} MemStatus;

typedef struct {
    unsigned long mem_total_kb;
    unsigned long mem_used_kb;
    float         usage_pct;
    MemStatus     status;
    time_t        timestamp;
    unsigned int  seq;
} MemAnalysis;

/* ─── Yardımcı: Progress Bar Çizici ───────────────────────── */
static void draw_progress_bar(float pct, int width)
{
    int filled = (int)(pct / 100.0f * width);
    if (filled > width)  filled = width;
    if (filled < 0)      filled = 0;

    /* Renk: %80+ kırmızı, %50+ sarı, diğer yeşil */
    const char *color = ANSI_GREEN;
    if (pct >= 80.0f)      color = ANSI_RED;
    else if (pct >= 50.0f) color = ANSI_YELLOW;

    printf("%s[%s", ANSI_WHITE, color);
    for (int i = 0; i < filled; i++)  putchar('#');
    printf("%s", ANSI_WHITE);
    for (int i = filled; i < width; i++) putchar('-');
    printf("]%s", ANSI_RESET);
}

/* ─── Yardımcı: kB → MB/GB dönüşüm ────────────────────────── */
static void format_mem(unsigned long kb, char *buf, size_t bufsz)
{
    if (kb >= (1024UL * 1024UL))
        snprintf(buf, bufsz, "%.2f GB", kb / (1024.0 * 1024.0));
    else
        snprintf(buf, bufsz, "%.1f MB", kb / 1024.0);
}

/* ─── Yardımcı: timestamp → HH:MM:SS ───────────────────────── */
static void format_time(time_t t, char *buf, size_t bufsz)
{
    struct tm *tm_info = localtime(&t);
    if (tm_info)
        strftime(buf, bufsz, "%H:%M:%S", tm_info);
    else
        snprintf(buf, bufsz, "??:??:??");
}

/* ─── Ekran Çizici ─────────────────────────────────────────── */
static void render(const MemAnalysis *d)
{
    char total_str[24], used_str[24], free_str[24], time_str[16];
    unsigned long free_kb = (d->mem_total_kb > d->mem_used_kb)
                            ? (d->mem_total_kb - d->mem_used_kb) : 0UL;

    format_mem(d->mem_total_kb, total_str, sizeof(total_str));
    format_mem(d->mem_used_kb,  used_str,  sizeof(used_str));
    format_mem(free_kb,         free_str,  sizeof(free_str));
    format_time(d->timestamp,   time_str,  sizeof(time_str));

    /* Durum rengi */
    const char *status_color  = (d->status == STATUS_CRITICAL)
                                 ? ANSI_RED : ANSI_GREEN;
    const char *status_label  = (d->status == STATUS_CRITICAL)
                                 ? "CRITICAL ⚠" : "NORMAL   ✓";

    /* ── Ekranı temizle ve tabloyu bas ── */
    fputs(CLEAR_SCREEN, stdout);

    /* Başlık */
    printf("%s╔══════════════════════════════════════════════╗%s\n",
           ANSI_CYAN, ANSI_RESET);
    printf("%s║%s %s  ARM64 BELLEK İZLEYİCİ — IPC Pipeline  %s%s║%s\n",
           ANSI_CYAN, ANSI_RESET,
           ANSI_BOLD, ANSI_RESET,
           ANSI_CYAN, ANSI_RESET);
    printf("%s╚══════════════════════════════════════════════╝%s\n",
           ANSI_CYAN, ANSI_RESET);

    /* Meta bilgisi */
    printf("\n  %sSıra No  :%s  #%u\n",        ANSI_WHITE, ANSI_RESET, d->seq);
    printf("  %sZaman    :%s  %s\n",            ANSI_WHITE, ANSI_RESET, time_str);

    /* Ayırıcı */
    printf("\n%s  ────────────────────────────────────────────%s\n",
           ANSI_WHITE, ANSI_RESET);

    /* Bellek değerleri */
    printf("  %sToplam   :%s  %s\n", ANSI_WHITE, ANSI_RESET, total_str);
    printf("  %sKullanım :%s  %s\n", ANSI_WHITE, ANSI_RESET, used_str);
    printf("  %sSerbest  :%s  %s\n", ANSI_WHITE, ANSI_RESET, free_str);

    /* Progress bar */
    printf("\n  %s%.1f%%%s  ", ANSI_BOLD, d->usage_pct, ANSI_RESET);
    draw_progress_bar(d->usage_pct, BAR_WIDTH);
    putchar('\n');

    /* Durum etiketi */
    printf("\n  %sDurum    :%s %s%s %s%s\n",
           ANSI_WHITE, ANSI_RESET,
           ANSI_BOLD, status_color,
           status_label,
           ANSI_RESET);

    /* Alt ayırıcı */
    printf("\n%s  ────────────────────────────────────────────%s\n",
           ANSI_WHITE, ANSI_RESET);
    printf("  %s[collector → pipe_1 → monitor → pipe_2 → display]%s\n\n",
           ANSI_CYAN, ANSI_RESET);

    fflush(stdout);
}

/* ─── FIFO Okuyucu (blocking) ──────────────────────────────── */
static int read_from_pipe2(MemAnalysis *data)
{
    int fd;
    ssize_t n;

    /* Blocking open: monitor henüz yazmamışsa burada bekle */
    fd = open(FIFO_PIPE2, O_RDONLY);
    if (fd < 0) {
        perror("[DISPLAY] open(pipe_2)");
        return -1;
    }

    n = read(fd, data, sizeof(MemAnalysis));
    close(fd);

    if (n == 0) {
        fprintf(stderr, "[DISPLAY] pipe_2 EOF — monitor kapandı\n");
        return -1;
    }
    if (n != (ssize_t)sizeof(MemAnalysis)) {
        fprintf(stderr, "[DISPLAY] Kısmi okuma: %zd/%zu bayt\n",
                n, sizeof(MemAnalysis));
        return -1;
    }
    return 0;
}

/* ─── main ─────────────────────────────────────────────────── */
int main(void)
{
    MemAnalysis data;

    fprintf(stdout,
            "[DISPLAY] Başlatıldı. Bekleniyor: " FIFO_PIPE2 "\n");
    fflush(stdout);

    /* pipe_2 yoksa oluştur */
    if (mkfifo(FIFO_PIPE2, 0666) < 0 && errno != EEXIST) {
        perror("[DISPLAY] mkfifo(pipe_2)");
        return EXIT_FAILURE;
    }

    /* ─── Ana Döngü ─────────────────────────────────────────── */
    while (1) {
        /* Blocking okuma: monitor yazana kadar bekle */
        if (read_from_pipe2(&data) < 0) {
            sleep(1);
            continue;
        }

        /* Veriyi ekranda göster */
        render(&data);
    }

    return EXIT_SUCCESS;
}
