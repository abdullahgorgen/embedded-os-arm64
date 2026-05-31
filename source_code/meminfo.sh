#!/bin/sh
# meminfo.sh — IPC Pipeline Orkestrasyon Betiği
#
# Kullanım : ./meminfo.sh
#            (isteğe bağlı arka plan stress testi: ./stress_mem & ardından ./meminfo.sh)
#
# Davranış :
#   1. collector ve monitor arka planda başlatılır, logları /tmp/'a yazılır.
#   2. display ön planda çalışır.
#   3. Kullanıcı Ctrl+C ile çıktığında trap devreye girerek
#      arka plan süreçlerini temiz şekilde sonlandırır.
#
# POSIX uyumlu (#!/bin/sh — bash gerektirmez, BusyBox ash ile çalışır)

# ─── PATH'i güvence altına al ────────────────────────────────
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

# ─── Sabitler ────────────────────────────────────────────────
COLLECTOR_BIN="collector"
MONITOR_BIN="monitor"
DISPLAY_BIN="display"

COLLECTOR_LOG="/tmp/collector.log"
MONITOR_LOG="/tmp/monitor.log"

# ─── Temizleme Fonksiyonu ─────────────────────────────────────
cleanup() {
    printf '\n[meminfo] Çıkış sinyali alındı — arka plan süreçleri durduruluyor...\n'

    # collector'ı durdur
    if [ -n "$COLLECTOR_PID" ] && kill -0 "$COLLECTOR_PID" 2>/dev/null; then
        kill "$COLLECTOR_PID" 2>/dev/null
        printf '[meminfo] collector (PID %s) durduruldu\n' "$COLLECTOR_PID"
    fi

    # monitor'ı durdur
    if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID" 2>/dev/null
        printf '[meminfo] monitor   (PID %s) durduruldu\n' "$MONITOR_PID"
    fi

    # stress_mem varsa onu da durdur (opsiyonel)
    STRESS_PID=$(pidof stress_mem 2>/dev/null || true)
    if [ -n "$STRESS_PID" ]; then
        kill "$STRESS_PID" 2>/dev/null
        printf '[meminfo] stress_mem (PID %s) durduruldu\n' "$STRESS_PID"
    fi

    # FIFO'ları temizle (bir sonraki çalıştırmada sorun çıkmasın)
    rm -f /tmp/pipe_1 /tmp/pipe_2

    printf '[meminfo] Temizlik tamamlandı. Çıkılıyor.\n'
    exit 0
}

# ─── Sinyal Tuzakları ─────────────────────────────────────────
trap cleanup INT TERM HUP

# ─── Bağımlılık Kontrolü ─────────────────────────────────────
for bin in "$COLLECTOR_BIN" "$MONITOR_BIN" "$DISPLAY_BIN"; do
    if ! command -v "$bin" > /dev/null 2>&1; then
        printf '[meminfo] HATA: "%s" bulunamadı! PATH=%s\n' "$bin" "$PATH"
        exit 1
    fi
done

# ─── Başlangıç Mesajı ────────────────────────────────────────
printf '══════════════════════════════════════════\n'
printf '  ARM64 IPC Pipeline — Orkestrasyon\n'
printf '══════════════════════════════════════════\n'
printf 'Log dosyaları: %s  %s\n' "$COLLECTOR_LOG" "$MONITOR_LOG"
printf 'Çıkmak için : Ctrl+C\n'
printf '══════════════════════════════════════════\n\n'

# ─── Arka Plan Süreçlerini Başlat ────────────────────────────
# Önceki log dosyalarını temizle
: > "$COLLECTOR_LOG"
: > "$MONITOR_LOG"

# collector başlat
"$COLLECTOR_BIN" > "$COLLECTOR_LOG" 2>&1 &
COLLECTOR_PID=$!
printf '[meminfo] collector başlatıldı (PID: %s)\n' "$COLLECTOR_PID"

# monitor başlat
"$MONITOR_BIN" > "$MONITOR_LOG" 2>&1 &
MONITOR_PID=$!
printf '[meminfo] monitor   başlatıldı (PID: %s)\n' "$MONITOR_PID"

# Süreçlerin FIFO'ları oluşturması için kısa bekleme
sleep 1
printf '[meminfo] display başlatılıyor...\n\n'

# ─── Ön Plan: display ────────────────────────────────────────
# display'den gelen Ctrl+C → trap → cleanup()
"$DISPLAY_BIN"

# display normal çıkış yaptıysa da temizlik yap
cleanup
