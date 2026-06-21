#!/usr/bin/env bash
set -euo pipefail

miner stop 2>/dev/null || true
sleep 3
screen -wipe || true

cd /hive/miners/custom

BK="/hive/miners/custom/_bkp_keryx_$(date +%F_%H%M%S)"
mkdir -p "$BK"
cp -a h-manifest.conf h-config.sh h-run h-run.sh h-stats.sh keryx-bootstrap.sh keryx-miner config.ini keryx-miner.bin lib*.so models escrow.key "$BK" 2>/dev/null || true

BASE="https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main"
wget -qO h-manifest.conf "$BASE/h-manifest.conf"
wget -qO h-config.sh "$BASE/h-config.sh"
wget -qO h-run.sh "$BASE/h-run.sh"
wget -qO h-stats.sh "$BASE/h-stats.sh"
wget -qO h-run "$BASE/h-run"
wget -qO keryx-miner "$BASE/keryx-miner"
wget -qO keryx-bootstrap.sh "$BASE/keryx-bootstrap.sh"

chmod 755 h-run h-run.sh h-config.sh h-stats.sh keryx-bootstrap.sh keryx-miner
[ -f keryx-miner.bin ] && chmod 755 keryx-miner.bin || true

: > /var/log/miner/keryx-miner.log

echo "===== KERYX V14 INSTALADO ====="
echo "Backup: $BK"
echo "Agora rode: miner-run custom 3"
echo "Se o teste direto funcionar, pare com Ctrl+C e depois rode: miner start"
