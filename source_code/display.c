#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define FIFO_PATH "/tmp/collector_to_display"
#define BUFFER_SIZE 1024

/*
 * Display Process: Collector'dan gelen verileri alıp gösterir
 * Aşama 4'te tam olarak kullanılacak
 */

typedef struct {
    unsigned int cpu_cores;
    unsigned long free_mem;
    unsigned long total_mem;
    unsigned long uptime_sec;
} CollectorData;

int main() {
    CollectorData data;
    
    printf("[Display] Başlatılıyor...\n");
    printf("[Display] Collector'dan veri bekleniyor...\n");
    
    // FIFO'dan oku
    FILE *fp = fopen(FIFO_PATH, "r");
    if (!fp) {
        perror("fopen FIFO");
        return 1;
    }
    
    if (fread(&data, sizeof(CollectorData), 1, fp) != 1) {
        fprintf(stderr, "Veri okunamadı\n");
        fclose(fp);
        return 1;
    }
    
    fclose(fp);
    
    // Verileri göster
    printf("\n");
    printf("╔════════════════════════════════════════╗\n");
    printf("║    DISPLAY - Collector Verileri       ║\n");
    printf("╚════════════════════════════════════════╝\n");
    printf("CPU Cores: %u\n", data.cpu_cores);
    printf("Total Memory: %lu KB\n", data.total_mem);
    printf("Free Memory: %lu KB\n", data.free_mem);
    printf("Uptime: %lu seconds\n", data.uptime_sec);
    
    return 0;
}
