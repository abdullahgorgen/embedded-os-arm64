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
 * Collector Process: Sistem verilerini toplayıp IPC üzerinden gönderir
 * Aşama 4'te tam olarak kullanılacak
 */

typedef struct {
    unsigned int cpu_cores;
    unsigned long free_mem;
    unsigned long total_mem;
    unsigned long uptime_sec;
} CollectorData;

int read_cpu_cores() {
    FILE *fp = fopen("/proc/cpuinfo", "r");
    if (!fp) return -1;
    
    int cores = 0;
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "processor", 9) == 0) cores++;
    }
    fclose(fp);
    return cores;
}

int read_memory(unsigned long *free, unsigned long *total) {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) return -1;
    
    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "MemTotal:", 9) == 0) {
            sscanf(line, "MemTotal: %lu", total);
        } else if (strncmp(line, "MemFree:", 8) == 0) {
            sscanf(line, "MemFree: %lu", free);
        }
    }
    fclose(fp);
    return 0;
}

int read_uptime(unsigned long *uptime) {
    FILE *fp = fopen("/proc/uptime", "r");
    if (!fp) return -1;
    
    double uptime_sec;
    int idle;
    fscanf(fp, "%lf %d", &uptime_sec, &idle);
    *uptime = (unsigned long)uptime_sec;
    fclose(fp);
    return 0;
}

int main() {
    CollectorData data;
    
    printf("[Collector] Başlatılıyor...\n");
    
    // FIFO oluştur (eğer yoksa)
    mkfifo(FIFO_PATH, 0666);
    
    printf("[Collector] Veri toplanıyor...\n");
    data.cpu_cores = read_cpu_cores();
    read_memory(&data.free_mem, &data.total_mem);
    read_uptime(&data.uptime_sec);
    
    // FIFO'ya yaz
    FILE *fp = fopen(FIFO_PATH, "w");
    if (!fp) {
        perror("fopen FIFO");
        return 1;
    }
    
    fwrite(&data, sizeof(CollectorData), 1, fp);
    fclose(fp);
    
    printf("[Collector] Veriler gönderildi.\n");
    
    return 0;
}
