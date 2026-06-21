#!/usr/bin/env bash
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

[ -t 1 ] && [ -f colors ] && . colors || true
. ./h-manifest.conf

mkdir -p /var/log/miner "$DIR/models" "$DIR/.keryx-cache" "$DIR/tmp"
touch "$CUSTOM_LOG_BASENAME.log"

log() {
  echo "$(date -Is) [KERYX-HIVEOS] $*" | tee -a "$CUSTOM_LOG_BASENAME.log"
}

show_diag() {
  log "===== DIAGNOSTICO RAPIDO ====="
  log "PWD=$(pwd)"
  log "DIR=$DIR"
  log "CUSTOM_CONFIG_FILENAME=${CUSTOM_CONFIG_FILENAME:-}"
  log "CUSTOM_LOG_BASENAME=${CUSTOM_LOG_BASENAME:-}"
  log "Arquivos principais:"
  ls -la "$DIR"/h-run "$DIR"/h-run.sh "$DIR"/h-config.sh "$DIR"/h-stats.sh "$DIR"/keryx-bootstrap.sh "$DIR"/keryx-miner "$DIR"/keryx-miner.bin 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log" || true
  log "config.ini:"
  cat "$CUSTOM_CONFIG_FILENAME" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log" || true
  log "Processos Keryx:"
  pgrep -af 'keryx-miner|keryx-bootstrap|download-models' 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log" || true
  log "Ultimas linhas do log:"
  tail -80 "$CUSTOM_LOG_BASENAME.log" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.diag.log" || true
  log "===== FIM DIAGNOSTICO ====="
}

run_fast_models_download() {
  FAST_URL="${KERYX_FAST_MODELS_URL:-https://huggingface.co/fearke85/keryx-miner-models/resolve/main/download-models.sh}"
  MARKER="$DIR/.keryx-cache/fast-models.done"
  SCRIPT="$DIR/tmp/keryx-download-models.sh"

  [ "${KERYX_FAST_MODELS:-0}" = "1" ] || return 0

  if [ -f "$MARKER" ] && [ "${KERYX_FAST_MODELS_FORCE:-0}" != "1" ]; then
    log "download rapido de modelos ja marcado como concluido: $MARKER"
    return 0
  fi

  log "download rapido de modelos habilitado por Extra config"
  log "script alternativo: $FAST_URL"

  if command -v wget >/dev/null 2>&1; then
    wget -qO "$SCRIPT" "$FAST_URL"
    rc=$?
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$SCRIPT" "$FAST_URL"
    rc=$?
  else
    log "ERRO: nem wget nem curl encontrados para baixar modelos rapidos"
    return 0
  fi

  if [ "$rc" -ne 0 ]; then
    log "AVISO: falha ao baixar script de modelos rapidos, rc=$rc. Continuando pelo metodo original."
    return 0
  fi

  chmod 755 "$SCRIPT" 2>/dev/null || true
  if [ "$(id -u)" -eq 0 ]; then
    bash "$SCRIPT" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
  else
    sudo bash "$SCRIPT" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
  fi

  if [ "$rc" -eq 0 ]; then
    date -Is > "$MARKER"
    log "download rapido de modelos concluido"
  else
    log "AVISO: download rapido de modelos falhou com codigo $rc; o minerador continuara e podera baixar pelo metodo original"
  fi

  return 0
}

start_once() {
  log "============================================================"
  log "KERYX START LOOP: $(date -Is)"
  log "Diretorio de execucao: $DIR"
  log "============================================================"

  if [ ! -x "$DIR/keryx-miner.bin" ]; then
    log "binario keryx-miner.bin ausente; executando bootstrap"
    "$DIR/keryx-bootstrap.sh" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
    if [ "$rc" -ne 0 ]; then
      log "ERRO: keryx-bootstrap.sh falhou com codigo $rc"
      return "$rc"
    fi
  fi

  if [ ! -x "$DIR/keryx-miner.bin" ]; then
    log "ERRO: keryx-miner.bin nao foi instalado apos bootstrap."
    return 11
  fi

  log "gerando config.ini a partir do Flight Sheet/defaults"
  "$DIR/h-config.sh" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
  rc=${PIPESTATUS[0]}
  if [ "$rc" -ne 0 ]; then
    log "ERRO: h-config.sh falhou com codigo $rc"
    return "$rc"
  fi

  [ -f "$DIR/keryx-local-options.env" ] && . "$DIR/keryx-local-options.env" || true

  CONF="$(tr '\n' ' ' < "$CUSTOM_CONFIG_FILENAME" | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')"

  if ! echo "$CONF" | grep -q -- '--mining-address'; then
    log "ERRO: config.ini nao contem --mining-address."
    log "Conteudo atual do config.ini: $CONF"
    return 12
  fi

  if ! echo "$CONF" | grep -q -- ' -s ' && ! echo "$CONF" | grep -q -- '^-s '; then
    log "ERRO: config.ini nao contem pool -s."
    log "Conteudo atual do config.ini: $CONF"
    return 13
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
    rc=${PIPESTATUS[0]}
  else
    "$DIR/keryx-miner.bin" $CONF "$@" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
  fi

  log "keryx-miner.bin saiu com codigo $rc"
  return "$rc"
}

log "h-run.sh chamado pelo HiveOS em $DIR"

while true; do
  start_once "$@"
  rc=$?
  log "Processo Keryx terminou/falhou com codigo $rc. A tela sera mantida viva para nao voltar ao prompt preto."
  show_diag
  log "Nova tentativa automatica em 30 segundos. Para sair: Ctrl+C ou miner stop."
  for i in 30 20 10; do
    log "retry em ${i}s..."
    sleep 10
  done
done
