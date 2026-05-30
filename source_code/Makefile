# Çapraz Derleme Makefile - arm64 (aarch64) hedefi

CROSS_COMPILE ?= aarch64-linux-gnu-
CC = $(CROSS_COMPILE)gcc
CFLAGS = -Wall -Wextra -O2 -static

# Program adları
MONITOR_BIN = monitor
COLLECTOR_BIN = collector
DISPLAY_BIN = display

# Kaynak dosyaları
MONITOR_SRC = monitor.c
COLLECTOR_SRC = collector.c
DISPLAY_SRC = display.c

# Hedef (tüm programlar)
all: $(MONITOR_BIN) $(COLLECTOR_BIN) $(DISPLAY_BIN)

# Monitor uygulaması
$(MONITOR_BIN): $(MONITOR_SRC)
	$(CC) $(CFLAGS) -o $@ $^
	@echo "[✓] $(MONITOR_BIN) başarıyla derlendi"

# Collector uygulaması (IPC)
$(COLLECTOR_BIN): $(COLLECTOR_SRC)
	$(CC) $(CFLAGS) -o $@ $^
	@echo "[✓] $(COLLECTOR_BIN) başarıyla derlendi"

# Display uygulaması (IPC)
$(DISPLAY_BIN): $(DISPLAY_SRC)
	$(CC) $(CFLAGS) -o $@ $^
	@echo "[✓] $(DISPLAY_BIN) başarıyla derlendi"

# Temizleme
clean:
	rm -f $(MONITOR_BIN) $(COLLECTOR_BIN) $(DISPLAY_BIN) *.o
	@echo "[✓] Temizlik tamamlandı"

# Yeniden derleme
rebuild: clean all

# Derleme bilgisini göster
info:
	@echo "Cross-Compile Toolchain: $(CROSS_COMPILE)"
	@echo "CC: $(CC)"
	@echo "CFLAGS: $(CFLAGS)"

.PHONY: all clean rebuild info
