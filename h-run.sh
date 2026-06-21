#!/usr/bin/env bash
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR" || exit 1

load_hiveos_flight_sheet() {
  [ -f /hive-config/rig.conf ] && . /hive-config/rig.conf 2>/dev/null || true
  [ -f /hive-config/wallet.conf ] && . /hive-config/wallet.conf 2>/dev/null || true
}

load_hiveos_flight_sheet

[ -t 1 ] && [ -f colors ] && . colors || true
. ./h-manifest.conf

mkdir -p /var/log/miner "$DIR/models" "$DIR/.keryx-cache" "$DIR/tmp"
touch "$CUSTOM_LOG_BASENAME.log"

log() {
  echo "$(date -Is) [KERYX-HIVEOS] $*" | tee -a "$CUSTOM_LOG_BASENAME.log"
}

send_hive_message() {
  msg="$*"
  log "AVISO PARA O USUARIO: $msg"

  for cmd in message sendmessage send_message hive-sendmsg hive-send-message; do
    if command -v "$cmd" >/dev/null 2>&1; then
      "$cmd" "$msg" >/dev/null 2>&1 || true
    fi
  done

  [ -x /hive/bin/message ] && /hive/bin/message "$msg" >/dev/null 2>&1 || true
  [ -x /hive/sbin/message ] && /hive/sbin/message "$msg" >/dev/null 2>&1 || true
}

notify_old_kernel_once() {
  marker="/tmp/keryx-old-kernel-docker-message.sent"
  [ -f "$marker" ] && return 0

  msg="Keryx Miner: este HiveOS esta com kernel $(uname -r), inferior a 6.6. Recomendo atualizar o HiveOS/kernel. Enquanto isso, o Keryx vai rodar em container Ubuntu 22.04; o sistema tentara instalar wget, ca-certificates e Docker se necessario."
  send_hive_message "$msg"
  date -Is > "$marker" 2>/dev/null || true
}

show_diag() {
  log "===== DIAGNOSTICO RAPIDO ====="
  log "PWD=$(pwd)"
  log "DIR=$DIR"
  log "KERNEL=$(uname -r) $(uname -v)"
  log "CUSTOM_CONFIG_FILENAME=${CUSTOM_CONFIG_FILENAME:-}"
  log "CUSTOM_LOG_BASENAME=${CUSTOM_LOG_BASENAME:-}"
  log "CUSTOM_URL=${CUSTOM_URL:-}"
  log "CUSTOM_TEMPLATE=${CUSTOM_TEMPLATE:-}"
  log "CUSTOM_USER_CONFIG=${CUSTOM_USER_CONFIG:-}"
  log "CUSTOM_ALGO=${CUSTOM_ALGO:-}"
  log "Arquivos principais:"
  ls -la "$DIR"/h-run "$DIR"/h-run.sh "$DIR"/h-config.sh "$DIR"/h-stats.sh "$DIR"/keryx-bootstrap.sh "$DIR"/keryx-miner "$DIR"/keryx-miner.bin 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log" || true
  log "config.ini:"
  cat "$CUSTOM_CONFIG_FILENAME" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log" || true
  log "Processos Keryx/Docker:"
  pgrep -af 'keryx-miner|keryx-bootstrap|download-models|docker' 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log" || true
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

prepare_config() {
  load_hiveos_flight_sheet
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

  export CONF
  return 0
}

kernel_requires_docker() {
  krel="$(uname -r 2>/dev/null || echo '')"
  major="$(printf '%s\n' "$krel" | sed -E 's/^([0-9]+).*/\1/')"
  minor="$(printf '%s\n' "$krel" | sed -E 's/^[0-9]+\.([0-9]+).*/\1/')"

  case "$major" in ''|*[!0-9]*) major=0 ;; esac
  case "$minor" in ''|*[!0-9]*) minor=0 ;; esac

  [ "$major" -lt 6 ] && return 0
  [ "$major" -gt 6 ] && return 1
  [ "$minor" -lt 6 ] && return 0
  return 1
}

ensure_host_deps() {
  marker="/tmp/keryx-host-deps-installed.sent"
  [ -f "$marker" ] && return 0

  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    log "Instalando dependencias base no host: wget ca-certificates"
    apt-get update 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    apt-get install -y wget ca-certificates 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    date -Is > "$marker" 2>/dev/null || true
  else
    log "AVISO: apt-get nao encontrado no host; nao foi possivel instalar wget/ca-certificates."
  fi

  return 0
}

ensure_docker() {
  ensure_host_deps

  if ! command -v docker >/dev/null 2>&1; then
    log "Docker nao encontrado; tentando instalar docker.io"
    if command -v apt-get >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get update 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
      apt-get install -y docker.io 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    fi
  fi

  if ! command -v docker >/dev/null 2>&1; then
    log "ERRO: Docker nao esta instalado e nao foi possivel instalar automaticamente."
    return 1
  fi

  systemctl start docker >/dev/null 2>&1 || service docker start >/dev/null 2>&1 || true

  if ! docker info >/dev/null 2>&1; then
    log "ERRO: Docker instalado, mas daemon nao respondeu."
    return 1
  fi

  return 0
}

ensure_docker_image() {
  image="keryx-hiveos-ubuntu22:22.04"
  if docker image inspect "$image" >/dev/null 2>&1; then
    return 0
  fi

  log "Criando imagem Docker $image baseada no Ubuntu 22.04"
  cat > "$DIR/tmp/Dockerfile.keryx" <<'DOCKERFILE'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates libssl3 libstdc++6 libgcc-s1 && update-ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /miners
DOCKERFILE

  docker build -t "$image" -f "$DIR/tmp/Dockerfile.keryx" "$DIR/tmp" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
  return ${PIPESTATUS[0]}
}

run_miner_native() {
  log "iniciando keryx-miner.bin nativo"
  log "config: $CONF"

  if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL "$DIR/keryx-miner.bin" $CONF "$@" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
  else
    "$DIR/keryx-miner.bin" $CONF "$@" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"
    rc=${PIPESTATUS[0]}
  fi
  return "$rc"
}

run_miner_docker() {
  image="keryx-hiveos-ubuntu22:22.04"
  cname="keryx-miner-${HOSTNAME:-hive}"

  notify_old_kernel_once
  log "Kernel inferior a 6.6 detectado: $(uname -r) $(uname -v)"
  log "Usando Docker Ubuntu 22.04 na mesma screen do HiveOS."

  ensure_docker || return 31
  ensure_docker_image || return 32

  docker rm -f "$cname" >/dev/null 2>&1 || true

  log "iniciando keryx-miner.bin dentro do container $image"
  log "config: $CONF"

  docker run --rm --name "$cname" \
    --gpus all \
    --network host \
    --ipc host \
    -v "$DIR:/miners" \
    -v /etc/localtime:/etc/localtime:ro \
    -e NVIDIA_VISIBLE_DEVICES=all \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    -e KERYX_HOME=/miners \
    -e XDG_CACHE_HOME=/miners/.keryx-cache \
    -e HF_HOME=/miners/.keryx-cache/huggingface \
    -e TMPDIR=/miners/tmp \
    -e RUST_BACKTRACE="${RUST_BACKTRACE:-1}" \
    -e LD_LIBRARY_PATH=/miners:/miners/lib:/miners/libs:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/lib/x86_64-linux-gnu \
    -w /miners "$image" \
    /bin/bash -lc "chmod 755 /miners/keryx-miner.bin 2>/dev/null || true; /miners/keryx-miner.bin $CONF" 2>&1 | tee -a "$CUSTOM_LOG_BASENAME.log"

  return ${PIPESTATUS[0]}
}

start_once() {
  log "============================================================"
  log "KERYX START LOOP: $(date -Is)"
  log "Diretorio de execucao: $DIR"
  log "Kernel: $(uname -r) $(uname -v)"
  log "============================================================"

  prepare_config || return $?

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

  export KERYX_HOME="$DIR"
  export XDG_CACHE_HOME="$DIR/.keryx-cache"
  export HF_HOME="$DIR/.keryx-cache/huggingface"
  export TMPDIR="$DIR/tmp"
  export RUST_BACKTRACE="${RUST_BACKTRACE:-1}"
  export LD_LIBRARY_PATH="$DIR:$DIR/lib:$DIR/libs:$DIR/cuda/lib64:$DIR/cuda/targets/x86_64-linux/lib:/usr/local/cuda/lib64:/usr/local/cuda/targets/x86_64-linux/lib:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

  ulimit -n 1048576 2>/dev/null || true

  run_fast_models_download

  if [ "${KERYX_FORCE_DOCKER:-0}" = "1" ] || kernel_requires_docker; then
    run_miner_docker "$@"
    rc=$?
  else
    run_miner_native "$@"
    rc=$?
  fi

  log "keryx-miner terminou com codigo $rc"
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
