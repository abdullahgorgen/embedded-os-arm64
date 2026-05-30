#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>

#define BUFFER_SIZE 1024
#define PROC_PATH "/proc"

/* 
 * /proc dosya sistemi yapısını okuyan Sistem İzleyici
 * Hedef: CPU Mimarisi, RAM Kullanımı, Uptime
 */

typedef struct {
    char cpu_arch[256];         // CPU Mimarisi (aarch64, x86_64 vb.)
    unsigned int cpu_cores;     // Çekirdek Sayısı
    unsigned long total_mem;    // Toplam RAM (KB)
    unsigned long free_mem;     // Boş RAM (KB)
    unsigned long uptime_sec;   // Uptime (saniye)
} SystemInfo;

/**
 * /proc/cpuinfo dosyasından CPU bilgilerini oku
 */
int read_cpu_info(SystemInfo *sys_info) {
    FILE *fp;
    char line[BUFFER_SIZE];
    int cpu_count = 0;
    int arch_found = 0;

    fp = fopen(PROC_PATH "/cpuinfo", "r");
    if (fp == NULL) {
        perror("fopen(/proc/cpuinfo)");
        return -1;
    }

    while (fgets(line, sizeof(line), fp) != NULL) {
        // CPU mimarisi bulma
        if (strncmp(line, "CPU architecture:", 17) == 0) {
            sscanf(line, "CPU architecture: %s", sys_info->cpu_arch);
            arch_found = 1;
        }

        // Processor sayısını say
        if (strncmp(line, "processor", 9) == 0) {
            cpu_count++;
        }
    }

    fclose(fp);

    if (!arch_found) {
        // arm64 sistemlerde "CPU implementer" kontrol et
        fp = fopen(PROC_PATH "/cpuinfo", "r");
        if (fp) {
            while (fgets(line, sizeof(line), fp) != NULL) {
                if (strncmp(line, "Model name:", 11) == 0) {
                    sscanf(line, "Model name: %[^\n]", sys_info->cpu_arch);
                    break;
                }
            }
            fclose(fp);
        }
    }

    if (sys_info->cpu_arch[0] == '\0') {
        strcpy(sys_info->cpu_arch, "Unknown (arm64/QEMU)");
    }

    sys_info->cpu_cores = cpu_count;
    return 0;
}

/**
 * /proc/meminfo dosyasından RAM bilgilerini oku
 */
int read_memory_info(SystemInfo *sys_info) {
    FILE *fp;
    char line[BUFFER_SIZE];
    unsigned long memtotal = 0, memfree = 0;

    fp = fopen(PROC_PATH "/meminfo", "r");
    if (fp == NULL) {
        perror("fopen(/proc/meminfo)");
        return -1;
    }

    while (fgets(line, sizeof(line), fp) != NULL) {
        if (strncmp(line, "MemTotal:", 9) == 0) {
            sscanf(line, "MemTotal: %lu kB", &memtotal);
        } else if (strncmp(line, "MemFree:", 8) == 0) {
            sscanf(line, "MemFree: %lu kB", &memfree);
        }
    }

    fclose(fp);

    sys_info->total_mem = memtotal;
    sys_info->free_mem = memfree;
    return 0;
}

/**
 * /proc/uptime dosyasından sistem uptime'ını oku
 */
int read_uptime_info(SystemInfo *sys_info) {
    FILE *fp;
    double uptime_seconds;
    int idle_seconds;

    fp = fopen(PROC_PATH "/uptime", "r");
    if (fp == NULL) {
        perror("fopen(/proc/uptime)");
        return -1;
    }

    if (fscanf(fp, "%lf %d", &uptime_seconds, &idle_seconds) != 2) {
        fprintf(stderr, "Error parsing /proc/uptime\n");
        fclose(fp);
        return -1;
    }

    fclose(fp);

    sys_info->uptime_sec = (unsigned long)uptime_seconds;
    return 0;
}

/**
 * Sistem bilgilerini düzenli formatta ekrana yazdır
 */
void print_system_info(const SystemInfo *sys_info) {
    unsigned long used_mem = sys_info->total_mem - sys_info->free_mem;
    unsigned int uptime_hours = sys_info->uptime_sec / 3600;
    unsigned int uptime_mins = (sys_info->uptime_sec % 3600) / 60;
    unsigned int uptime_secs = sys_info->uptime_sec % 60;

    printf("\n");
    printf("╔════════════════════════════════════════════════════════╗\n");
    printf("║         SISTEM İZLEYİCİ - QEMU arm64                  ║\n");
    printf("╚════════════════════════════════════════════════════════╝\n");
    printf("\n");

    printf("📊 CPU BİLGİSİ\n");
    printf("  Mimari: %s\n", sys_info->cpu_arch);
    printf("  Çekirdek Sayısı: %u\n", sys_info->cpu_cores);
    printf("\n");

    printf("💾 BELLEK BİLGİSİ\n");
    printf("  Toplam Bellek: %lu KB (%.2f MB)\n", 
           sys_info->total_mem, 
           sys_info->total_mem / 1024.0);
    printf("  Boş Bellek: %lu KB (%.2f MB)\n", 
           sys_info->free_mem, 
           sys_info->free_mem / 1024.0);
    printf("  Kullanılan Bellek: %lu KB (%.2f MB)\n", 
           used_mem, 
           used_mem / 1024.0);
    printf("  Bellek Kullanım: %.2f%%\n", 
           (100.0 * used_mem) / sys_info->total_mem);
    printf("\n");

    printf("⏱️  SISTEM UPTIME'I\n");
    printf("  Uptime: %u saat %u dakika %u saniye\n", 
           uptime_hours, uptime_mins, uptime_secs);
    printf("  Toplam Saniye: %lu\n", sys_info->uptime_sec);
    printf("\n");
}

/**
 * Main - Tüm sistem bilgilerini topla ve göster
 */
int main(int argc, char *argv[]) {
    SystemInfo sys_info;
    memset(&sys_info, 0, sizeof(SystemInfo));

    printf("[*] Sistem İzleyici başlatılıyor...\n");

    // CPU bilgisi oku
    if (read_cpu_info(&sys_info) != 0) {
        fprintf(stderr, "CPU bilgisi okunamadı\n");
        return 1;
    }

    // RAM bilgisi oku
    if (read_memory_info(&sys_info) != 0) {
        fprintf(stderr, "RAM bilgisi okunamadı\n");
        return 1;
    }

    // Uptime bilgisi oku
    if (read_uptime_info(&sys_info) != 0) {
        fprintf(stderr, "Uptime bilgisi okunamadı\n");
        return 1;
    }

    // Bilgileri ekrana yazdır
    print_system_info(&sys_info);

    return 0;
}
