# ═══════════════════════════════════════════════════════════════
# Makefile — sys_alarm_driver Out-of-Tree Kernel Modülü
#
# Hedef    : ARM64 Linux 6.1.75 için sys_alarm_driver.ko
# Kullanım :
#   make              → modülü derle
#   make clean        → build dosyalarını temizle
#   make install ROOTFS=<yol>  → .ko dosyasını rootfs'e kopyala
# ═══════════════════════════════════════════════════════════════

# ─── Out-of-tree modül hedefi ─────────────────────────────────
obj-m := sys_alarm_driver.o

# ─── Mimari ve araç zinciri ───────────────────────────────────
ARCH          := arm64
CROSS_COMPILE := aarch64-linux-gnu-

# ─── Kernel kaynak ağacı ──────────────────────────────────────
# Docker içi yol: /workspace/qemu/linux-6.1.75
# Host WSL yolu  : /home/abdullah/199825113_abdullahgörgen/qemu/linux-6.1.75
KDIR ?= /workspace/qemu/linux-6.1.75

# ─── Modül kaynak dizini ──────────────────────────────────────
M := $(shell pwd)

# ─── Derleme ──────────────────────────────────────────────────
.PHONY: all clean install verify

all:
	@echo "[*] Kernel modülü derleniyor..."
	@echo "    KDIR : $(KDIR)"
	@echo "    ARCH : $(ARCH)"
	@echo "    CC   : $(CROSS_COMPILE)gcc"
	$(MAKE) -C $(KDIR) \
	        M=$(M) \
	        ARCH=$(ARCH) \
	        CROSS_COMPILE=$(CROSS_COMPILE) \
	        modules
	@echo "[✓] sys_alarm_driver.ko derlendi:"
	@ls -lh sys_alarm_driver.ko
	@file sys_alarm_driver.ko

# ─── Temizleme ────────────────────────────────────────────────
clean:
	$(MAKE) -C $(KDIR) M=$(M) clean
	@echo "[✓] Temizlendi"

# ─── RootFS'e Kurulum ─────────────────────────────────────────
# Kullanım: make install ROOTFS=/workspace/rootfs/rootfs_tree
ROOTFS      ?= /workspace/rootfs/rootfs_tree
MODULES_DIR  = $(ROOTFS)/lib/modules

install: all
	@echo "[*] Kurulum: $(MODULES_DIR)"
	@mkdir -p $(MODULES_DIR)
	@cp sys_alarm_driver.ko $(MODULES_DIR)/
	@chmod 644 $(MODULES_DIR)/sys_alarm_driver.ko
	@echo "[✓] sys_alarm_driver.ko → $(MODULES_DIR)/"

# ─── Doğrulama ────────────────────────────────────────────────
verify:
	@if [ -f sys_alarm_driver.ko ]; then \
		echo "=== sys_alarm_driver.ko Doğrulama ==="; \
		file sys_alarm_driver.ko; \
		modinfo sys_alarm_driver.ko 2>/dev/null || true; \
	else \
		echo "sys_alarm_driver.ko bulunamadı — önce 'make' çalıştırın"; \
	fi
