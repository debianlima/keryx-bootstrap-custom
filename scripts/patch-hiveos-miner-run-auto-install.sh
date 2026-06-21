#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "[KERYX-PATCH] Este patch precisa de root. Reexecutando com sudo..."
  exec sudo -E bash "$0" "$@"
fi

TARGET="/hive/bin/miner-run"
ORIG="/hive/bin/miner-run.hiveos-original"
WRAP="/hive/bin/miner-run.keryx-wrapper"

if [ ! -f "$TARGET" ]; then
  echo "[KERYX-PATCH] ERRO: $TARGET nao encontrado"
  exit 1
fi

if grep -q 'KERYX_AUTO_INSTALL_WRAPPER' "$TARGET" 2>/dev/null; then
  echo "[KERYX-PATCH] Wrapper ja esta ativo em $TARGET"
  exit 0
fi

if [ ! -f "$ORIG" ]; then
  cp -a "$TARGET" "$ORIG"
fi

cat > "$WRAP" <<'EOF'
#!/usr/bin/env bash
# KERYX_AUTO_INSTALL_WRAPPER
set +e

ORIG="/hive/bin/miner-run.hiveos-original"
LOG="/var/log/miner/keryx-auto-install.log"

log() {
  mkdir -p /var/log/miner 2>/dev/null || true
  echo "$(date -Is) [KERYX-AUTO-INSTALL] $*" >> "$LOG"
}

install_custom_if_needed() {
  [ "${1:-}" = "custom" ] || return 0

  if [ -f /hive/miners/custom/h-manifest.conf ] && \
     [ -f /hive/miners/custom/h-config.sh ] && \
     [ -f /hive/miners/custom/h-run.sh ]; then
    return 0
  fi

  [ -f /hive-config/rig.conf ] && . /hive-config/rig.conf 2>/dev/null || true
  [ -f /hive-config/wallet.conf ] && . /hive-config/wallet.conf 2>/dev/null || true

  URL="${CUSTOM_INSTALL_URL:-}"
  if [ -z "$URL" ]; then
    log "CUSTOM_INSTALL_URL vazio; nao ha como baixar custom miner"
    return 0
  fi

  log "custom ausente/incompleto; baixando $URL"

  rm -rf /tmp/keryx-custom-install
  mkdir -p /tmp/keryx-custom-install /hive/miners/custom

  if ! wget -qO /tmp/keryx-custom-install/custom.tar.gz "$URL"; then
    log "ERRO: wget falhou em $URL"
    return 0
  fi

  if ! gzip -t /tmp/keryx-custom-install/custom.tar.gz >/dev/null 2>&1; then
    log "ERRO: pacote nao passou no gzip -t"
    return 0
  fi

  if ! tar -xzf /tmp/keryx-custom-install/custom.tar.gz -C /tmp/keryx-custom-install; then
    log "ERRO: tar falhou"
    return 0
  fi

  # Formato 1: arquivos direto na raiz do pacote
  if [ -f /tmp/keryx-custom-install/h-manifest.conf ]; then
    cp -af /tmp/keryx-custom-install/. /hive/miners/custom/
  fi

  # Formato 2: subpasta custom/
  if [ -f /tmp/keryx-custom-install/custom/h-manifest.conf ]; then
    cp -af /tmp/keryx-custom-install/custom/. /hive/miners/custom/
  fi

  # Formato 3: subpasta com o nome do CUSTOM_MINER
  if [ -n "${CUSTOM_MINER:-}" ] && [ -f "/tmp/keryx-custom-install/$CUSTOM_MINER/h-manifest.conf" ]; then
    cp -af "/tmp/keryx-custom-install/$CUSTOM_MINER/." /hive/miners/custom/
  fi

  chmod 755 /hive/miners/custom/h-run \
            /hive/miners/custom/h-run.sh \
            /hive/miners/custom/h-config.sh \
            /hive/miners/custom/h-stats.sh \
            /hive/miners/custom/keryx-bootstrap.sh \
            /hive/miners/custom/keryx-miner 2>/dev/null || true
  [ -f /hive/miners/custom/keryx-miner.bin ] && chmod 755 /hive/miners/custom/keryx-miner.bin || true

  if [ -f /hive/miners/custom/h-manifest.conf ] && \
     [ -f /hive/miners/custom/h-config.sh ] && \
     [ -f /hive/miners/custom/h-run.sh ]; then
    log "custom miner instalado automaticamente em /hive/miners/custom"
  else
    log "ERRO: pacote extraido mas arquivos obrigatorios nao apareceram em /hive/miners/custom"
  fi
}

install_custom_if_needed "$@"

exec "$ORIG" "$@"
EOF

chmod 755 "$WRAP"
cp -a "$WRAP" "$TARGET"

echo "[KERYX-PATCH] OK: /hive/bin/miner-run agora reinstala o Custom Miner automaticamente se /hive/miners/custom estiver ausente/incompleto."
echo "[KERYX-PATCH] Backup original: $ORIG"
echo "[KERYX-PATCH] Log: /var/log/miner/keryx-auto-install.log"
