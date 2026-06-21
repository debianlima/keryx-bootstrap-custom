#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

[ -t 1 ] && [ -f colors ] && . colors || true
. ./h-manifest.conf

mkdir -p /var/log/miner "$DIR/models" "$DIR/.keryx-cache" "$DIR/tmp"
touch "$CUSTOM_LOG_BASENAME.log"

log() {
  echo "$(date -Is) [KERYX-HIVEOS] $*" | tee -a "$CUSTOM_LOG_BASENAME.log"
}

log "h-run.sh chamado em $DIR"

if [ ! -x "$DIR/keryx-miner.bin" ]; then
  log "binário keryx-miner.bin ausente; executando bootstrap"
  "$DIR/keryx-bootstrap.sh" | tee -a "$CUSTOM_LOG_BASENAME.log"
fi

if [ ! -x "$DIR/keryx-miner.bin" ]; then
  log "ERRO: keryx-miner.bin não foi instalado. Confira KERYX_PACKAGE_URL ou o pacote release."
  exit 1
fi

if [ ! -s "$CUSTOM_CONFIG_FILENAME" ]; then
  log "config.ini ausente; gerando com h-config.sh"
  "$DIR/h-config.sh" | tee -a "$CUSTOM_LOG_BASENAME.log" || true
fi

CONF="$(tr '\n' ' ' < "$CUSTOM_CONFIG_FILENAME" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

if ! grep -q -- '--mining-address' "$CUSTOM_CONFIG_FILENAME"; then
  log "ERRO: config.ini não contém --mining-address. Configure Wallet/Template no Flight Sheet do HiveOS."
  log "Conteúdo atual do config.ini: $CONF"
  exit 2
fi

if ! grep -q -- ' -s ' "$CUSTOM_CONFIG_FILENAME" && ! grep -q -- '^-s ' "$CUSTOM_CONFIG_FILENAME"; then
  log "ERRO: config.ini não contém pool -s. Configure Pool/URL no Flight Sheet do HiveOS."
  log "Conteúdo atual do config.ini: $CONF"
  exit 2
fi

export KERYX_HOME="$DIR"
export XDG_CACHE_HOME="$DIR/.keryx-cache"
export HF_HOME="$DIR/.keryx-cache/huggingface"
export TMPDIR="$DIR/tmp"
export RUST_BACKTRACE="${RUST_BACKTRACE:-1}"
export LD_LIBRARY_PATH="$DIR:$DIR/lib:$DIR/libs:$DIR/cuda/lib64:$DIR/cuda/targets/x86_64-linux/lib:/usr/local/cuda/lib64:/usr/local/cuda/targets/x86_64-linux/lib:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

ulimit -n 1048576 2>/dev/null || true

log "iniciando keryx-miner.bin"
log "config: $CONF"

if command -v stdbuf >/dev/null 2>&1; then
  stdbuf -oL -eL "$DIR/keryx-miner.bin" $CONF "$@" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
else
  "$DIR/keryx-miner.bin" $CONF "$@" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
fi
