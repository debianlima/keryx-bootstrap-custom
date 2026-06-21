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

run_fast_models_download() {
  FAST_URL="${KERYX_FAST_MODELS_URL:-https://huggingface.co/fearke85/keryx-miner-models/resolve/main/download-models.sh}"
  MARKER="$DIR/.keryx-cache/fast-models.done"
  SCRIPT="$DIR/tmp/keryx-download-models.sh"

  [ "${KERYX_FAST_MODELS:-0}" = "1" ] || return 0

  if [ -f "$MARKER" ] && [ "${KERYX_FAST_MODELS_FORCE:-0}" != "1" ]; then
    log "download rápido de modelos já marcado como concluído: $MARKER"
    return 0
  fi

  log "download rápido de modelos habilitado por Extra config"
  log "script alternativo: $FAST_URL"

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$SCRIPT" "$FAST_URL"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$SCRIPT" "$FAST_URL"
  else
    log "ERRO: nem wget nem curl encontrados para baixar modelos rápidos"
    return 0
  fi

  chmod 755 "$SCRIPT"
  set +e
  if [ "$(id -u)" -eq 0 ]; then
    bash "$SCRIPT" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
  else
    sudo bash "$SCRIPT" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
  fi
  set -e

  if [ "$rc" -eq 0 ]; then
    date -Is > "$MARKER"
    log "download rápido de modelos concluído"
  else
    log "AVISO: download rápido de modelos falhou com código $rc; o minerador continuará e poderá baixar pelo método original"
  fi

  return 0
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

log "gerando config.ini a partir do Flight Sheet/defaults"
"$DIR/h-config.sh" | tee -a "$CUSTOM_LOG_BASENAME.log" || true

[ -f "$DIR/keryx-local-options.env" ] && . "$DIR/keryx-local-options.env" || true

CONF="$(tr '\n' ' ' < "$CUSTOM_CONFIG_FILENAME" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

if ! echo "$CONF" | grep -q -- '--mining-address'; then
  log "ERRO: config.ini não contém --mining-address."
  log "Conteúdo atual do config.ini: $CONF"
  exit 2
fi

if ! echo "$CONF" | grep -q -- ' -s ' && ! echo "$CONF" | grep -q -- '^-s '; then
  log "ERRO: config.ini não contém pool -s."
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

run_fast_models_download

log "iniciando keryx-miner.bin"
log "config: $CONF"

if command -v stdbuf >/dev/null 2>&1; then
  stdbuf -oL -eL "$DIR/keryx-miner.bin" $CONF "$@" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
else
  "$DIR/keryx-miner.bin" $CONF "$@" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
fi
