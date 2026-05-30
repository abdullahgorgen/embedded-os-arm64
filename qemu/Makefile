# Kernel Derleme Makefile

.PHONY: all build clean boot docker-build docker-boot help

KERNEL_VERSION ?= 6.1.75
WORK_DIR := $(shell pwd)
IMAGE := Image
ROOTFS := rootfs.img
DOCKER_IMAGE := arm64-embedded-dev:latest

all: build

help:
	@echo "=== Kernel Derleme Komutları ==="
	@echo ""
	@echo "make build          - Kernel derle (native)"
	@echo "make build-docker   - Docker'da kernel derle"
	@echo "make boot           - QEMU'da boot et"
	@echo "make clean          - Kernel build'ı temizle"
	@echo "make verify         - Kernel Image'ı doğrula"
	@echo "make help           - Bu mesajı göster"
	@echo ""

build:
	@echo "[*] Kernel derleniyor..."
	@chmod +x build_kernel.sh
	@./build_kernel.sh

build-docker:
	@echo "[*] Docker'da kernel derleniyor..."
	@chmod +x build_kernel_docker.sh
	@./build_kernel_docker.sh

boot: verify
	@echo "[*] QEMU boot ediliyor..."
	@chmod +x boot_kernel.sh
	@./boot_kernel.sh

verify:
	@echo "[*] Kernel Image doğrulanıyor..."
	@if [ ! -f "$(IMAGE)" ]; then \
		echo "✗ Image bulunamadı: $(IMAGE)"; \
		exit 1; \
	fi
	@file $(IMAGE)
	@ls -lh $(IMAGE)
	@echo "✓ Image doğrulandı"

clean:
	@echo "[*] Kernel build temizleniyor..."
	@rm -rf linux-$(KERNEL_VERSION)/build
	@echo "✓ Temizlik tamamlandı"

.DEFAULT_GOAL := help
