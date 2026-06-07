SHELL := /bin/bash

PROJECT_ROOT := $(CURDIR)
IMAGE_NAME := arm64-embedded-dev:latest
DOCKER_RUN := docker run --rm -it --privileged \
	-v "$(PROJECT_ROOT):/workspace" \
	-v /dev:/dev \
	-e HOST_UID="$(shell id -u)" \
	-e HOST_GID="$(shell id -g)" \
	-e PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
	$(IMAGE_NAME)

.PHONY: all docker-image kernel system boot clean distclean

all: docker-image kernel system

docker-image:
	docker build \
		--build-arg UID="$(shell id -u)" \
		--build-arg GID="$(shell id -g)" \
		-t $(IMAGE_NAME) \
		./docker

kernel:
	$(DOCKER_RUN) bash /workspace/scripts/build_kernel_full.sh

system:
	$(DOCKER_RUN) bash /workspace/scripts/build_all.sh

boot:
	@echo "========================================="
	@echo "  QEMU ARM64 Simulasyonu Baslatiliyor..."
	@echo "  Cikis: Ctrl+A, ardindan X"
	@echo "========================================="
	$(DOCKER_RUN) qemu-system-aarch64 \
		-machine virt -cpu cortex-a72 -m 512M -smp 2 \
		-kernel /workspace/qemu/Image \
		-dtb /workspace/dts/custom_virt_machine.dtb \
		-drive file=/workspace/rootfs/rootfs.img,format=raw,if=virtio \
		-append "root=/dev/vda rw console=ttyAMA0 earlycon init=/init" \
		-nographic

clean:
	@echo "[*] Standart temizlik baslatiliyor..."
	@$(MAKE) -C source_code clean >/dev/null 2>&1 || true
	@$(MAKE) -C source_code/driver KDIR="$(PROJECT_ROOT)/qemu/linux-6.1.75" clean >/dev/null 2>&1 || true
	rm -f dts/*.dtb dts/*.dts
	rm -rf rootfs/rootfs_tree
	rm -f rootfs/rootfs.img
	@echo "[✓] Standart temizlik tamamlandi."

distclean: clean
	@echo "[*] Tam temizlik baslatiliyor..."
	rm -rf qemu/linux-6.1.75
	rm -f qemu/linux-6.1.75.tar.xz
	rm -f qemu/Image
	rm -rf rootfs/busybox-1.36.1
	rm -f rootfs/busybox-1.36.1.tar.bz2
	rm -rf rootfs/busybox_install
	@echo "[✓] Tam temizlik tamamlandi."
