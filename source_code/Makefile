# ═══════════════════════════════════════════════════════════════
# Makefile — ARM64 IPC Pipeline (collector / monitor / display)
#
# Kullanım:
#   make              → hepsini derle
#   make collector    → sadece collector
#   make monitor      → sadece monitor
#   make display      → sadece display
#   make verify       → binary doğrulama (statik + aarch64 kontrolü)
#   make clean        → binary'leri sil
#   make install ROOTFS_DIR=<yol>  → rootfs'e kopyala
# ═══════════════════════════════════════════════════════════════

# ─── Araç Zinciri ──────────────────────────────────────────────
CROSS_COMPILE ?= aarch64-linux-gnu-
CC             = $(CROSS_COMPILE)gcc
STRIP          = $(CROSS_COMPILE)strip

# ─── Derleme Bayrakları ────────────────────────────────────────
CFLAGS  = -Wall -Wextra -Wpedantic \
           -O2 \
           -static \
           -std=c99 \
           -D_POSIX_C_SOURCE=200809L

# strip: binary boyutunu küçültür (embedded için kritik)
LDFLAGS = -static

# ─── Hedef Binary'ler ──────────────────────────────────────────
TARGETS = collector monitor display

# ─── Kaynak → Binary Eşlemeleri ───────────────────────────────
collector_SRC = collector.c
monitor_SRC   = monitor.c
display_SRC   = display.c

# ─── Varsayılan Hedef ──────────────────────────────────────────
.PHONY: all clean verify install info rebuild

all: $(TARGETS)
	@echo ""
	@echo "✓ Tüm binary'ler ARM64 için derlendi:"
	@ls -lh $(TARGETS) 2>/dev/null || true
	@echo ""

# ─── Derleme Kuralları ─────────────────────────────────────────
collector: $(collector_SRC)
	@echo "[CC]  $< → $@"
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
	$(STRIP) $@
	@echo "[✓]   collector hazır"

monitor: $(monitor_SRC)
	@echo "[CC]  $< → $@"
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
	$(STRIP) $@
	@echo "[✓]   monitor hazır"

display: $(display_SRC)
	@echo "[CC]  $< → $@"
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
	$(STRIP) $@
	@echo "[✓]   display hazır"

# ─── Doğrulama ─────────────────────────────────────────────────
verify: $(TARGETS)
	@echo ""
	@echo "════ Binary Doğrulama ══════════════════════════════"
	@for bin in $(TARGETS); do \
		echo ""; \
		echo "  $$bin:"; \
		file $$bin; \
		if file $$bin | grep -q "statically linked"; then \
			echo "  ✓ Statik linkaj — tamam"; \
		else \
			echo "  ✗ DİNAMİK linkaj — HATA! '-static' flag'ini kontrol edin"; \
		fi; \
		if file $$bin | grep -q "ARM aarch64"; then \
			echo "  ✓ Mimari: ARM aarch64 — tamam"; \
		else \
			echo "  ✗ Yanlış mimari — CROSS_COMPILE kontrolü gerekli"; \
		fi; \
	done
	@echo ""
	@echo "════════════════════════════════════════════════════"

# ─── RootFS'e Kurulum ──────────────────────────────────────────
# Kullanım: make install ROOTFS_DIR=/path/to/rootfs_tree
ROOTFS_DIR ?= ../rootfs/rootfs_tree
INSTALL_BIN = $(ROOTFS_DIR)/usr/bin

install: $(TARGETS)
	@echo "[*] Kurulum hedefi: $(INSTALL_BIN)"
	@mkdir -p $(INSTALL_BIN)
	@for bin in $(TARGETS); do \
		cp -v $$bin $(INSTALL_BIN)/$$bin; \
		chmod 755 $(INSTALL_BIN)/$$bin; \
	done
	@echo "[✓] Tüm binary'ler $(INSTALL_BIN) dizinine kopyalandı"

# ─── Temizleme ─────────────────────────────────────────────────
clean:
	rm -f $(TARGETS) *.o
	@echo "[✓] Temizlendi"

rebuild: clean all

# ─── Bilgi ─────────────────────────────────────────────────────
info:
	@echo "Araç Zinciri : $(CROSS_COMPILE)"
	@echo "CC           : $(CC)"
	@echo "CFLAGS       : $(CFLAGS)"
	@echo "Hedefler     : $(TARGETS)"
