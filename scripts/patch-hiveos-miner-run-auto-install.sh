#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "[KERYX-PATCH] Este patch precisa de root. Reexecutando com sudo..."
  exec sudo -E bash "$0" "$@"
fi

COMMON="/hive/bin/keryx-auto-install-common.sh"
MINER_TARGET="/hive/bin/miner"
MINER_ORIG="/hive/bin/miner.hiveos-original"
MINERRUN_TARGET="/hive/bin/miner-run"
MINERRUN_ORIG="/hive/bin/miner-run.hiveos-original"
LOG="/var/log/miner/keryx-auto-install.log"

for f in "$MINER_TARGET" "$MINERRUN_TARGET"; do
  if [ ! -f "$f" ]; then
    echo "[KERYX-PATCH] ERRO: $f nao encontrado"
    exit 1
  fi
done

cat > "$COMMON" <<'EOF'
#!/usr/bin/env bash
# KERYX_AUTO_INSTALL_COMMON

KERYX_AUTO_LOG="/var/log/miner/keryx-auto-install.log"

keryx_log() {
  mkdir -p /var/log/miner 2>/dev/null || true
  echo "$(date -Is) [KERYX-AUTO-INSTALL] $*" >> "$KERYX_AUTO_LOG"
}

keryx_custom_files_ok() {
  [ -f /hive/miners/custom/h-manifest.conf ] && \
  [ -f /hive/miners/custom/h-config.sh ] && \
  [ -f /hive/miners/custom/h-run.sh ]
}

keryx_load_hive_config() {
  [ -f /hive-config/rig.conf ] && . /hive-config/rig.conf 2>/dev/null || true
  [ -f /hive-config/wallet.conf ] && . /hive-config/wallet.conf 2>/dev/null || true
}

keryx_custom_enabled_in_rig() {
  keryx_load_hive_config
  [ "${MINER:-}" = "custom" ] || \
  [ "${MINER2:-}" = "custom" ] || \
  [ "${MINER3:-}" = "custom" ] || \
  [ "${MINER4:-}" = "custom" ] || \
  [ "${MINER5:-}" = "custom" ]
}

keryx_copy_extracted_tree() {
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
}

keryx_install_custom_if_needed() {
  keryx_load_hive_config

  if keryx_custom_files_ok; then
    return 0
  fi

  URL="${CUSTOM_INSTALL_URL:-}"
  if [ -z "$URL" ]; then
    keryx_log "CUSTOM_INSTALL_URL vazio; nao ha como baixar custom miner"
    return 0
  fi

  keryx_log "custom ausente/incompleto; baixando $URL"

  rm -rf /tmp/keryx-custom-install
  mkdir -p /tmp/keryx-custom-install /hive/miners/custom

  if ! wget -qO /tmp/keryx-custom-install/custom.tar.gz "$URL"; then
    keryx_log "ERRO: wget falhou em $URL"
    return 0
  fi

  if ! gzip -t /tmp/keryx-custom-install/custom.tar.gz >/dev/null 2>&1; then
    keryx_log "ERRO: pacote nao passou no gzip -t"
    return 0
  fi

  if ! tar -xzf /tmp/keryx-custom-install/custom.tar.gz -C /tmp/keryx-custom-install; then
    keryx_log "ERRO: tar falhou"
    return 0
  fi

  keryx_copy_extracted_tree

  chmod 755 /hive/miners/custom/h-run \
            /hive/miners/custom/h-run.sh \
            /hive/miners/custom/h-config.sh \
            /hive/miners/custom/h-stats.sh \
            /hive/miners/custom/keryx-bootstrap.sh \
            /hive/miners/custom/keryx-miner 2>/dev/null || true
  [ -f /hive/miners/custom/keryx-miner.bin ] && chmod 755 /hive/miners/custom/keryx-miner.bin || true

  if keryx_custom_files_ok; then
    keryx_log "custom miner instalado automaticamente em /hive/miners/custom"
  else
    keryx_log "ERRO: pacote extraido mas arquivos obrigatorios nao apareceram em /hive/miners/custom"
  fi
}
EOF

chmod 755 "$COMMON"

if [ ! -f "$MINER_ORIG" ] && ! grep -q 'KERYX_AUTO_INSTALL_MINER_WRAPPER' "$MINER_TARGET" 2>/dev/null; then
  cp -a "$MINER_TARGET" "$MINER_ORIG"
fi

cat > /hive/bin/miner.keryx-wrapper <<'EOF'
#!/usr/bin/env bash
# KERYX_AUTO_INSTALL_MINER_WRAPPER
set +e
ORIG="/hive/bin/miner.hiveos-original"
COMMON="/hive/bin/keryx-auto-install-common.sh"

[ -f "$COMMON" ] && . "$COMMON"

cmd="${1:-}"
case "$cmd" in
  start|restart|"")
    if type keryx_custom_enabled_in_rig >/dev/null 2>&1 && keryx_custom_enabled_in_rig; then
      keryx_install_custom_if_needed
    fi
    ;;
esac

exec "$ORIG" "$@"
EOF

chmod 755 /hive/bin/miner.keryx-wrapper
cp -a /hive/bin/miner.keryx-wrapper "$MINER_TARGET"

if [ ! -f "$MINERRUN_ORIG" ] && ! grep -q 'KERYX_AUTO_INSTALL_MINERRUN_WRAPPER' "$MINERRUN_TARGET" 2>/dev/null; then
  cp -a "$MINERRUN_TARGET" "$MINERRUN_ORIG"
fi

cat > /hive/bin/miner-run.keryx-wrapper <<'EOF'
#!/usr/bin/env bash
# KERYX_AUTO_INSTALL_MINERRUN_WRAPPER
set +e
ORIG="/hive/bin/miner-run.hiveos-original"
COMMON="/hive/bin/keryx-auto-install-common.sh"

[ -f "$COMMON" ] && . "$COMMON"

if [ "${1:-}" = "custom" ]; then
  if type keryx_install_custom_if_needed >/dev/null 2>&1; then
    keryx_install_custom_if_needed
  fi
fi

exec "$ORIG" "$@"
EOF

chmod 755 /hive/bin/miner-run.keryx-wrapper
cp -a /hive/bin/miner-run.keryx-wrapper "$MINERRUN_TARGET"

mkdir -p /var/log/miner
{
  echo "$(date -Is) [KERYX-PATCH] patch aplicado em /hive/bin/miner e /hive/bin/miner-run"
  echo "$(date -Is) [KERYX-PATCH] backups: $MINER_ORIG e $MINERRUN_ORIG"
} >> "$LOG"

echo "[KERYX-PATCH] OK: /hive/bin/miner e /hive/bin/miner-run agora tentam reinstalar o Custom Miner automaticamente."
echo "[KERYX-PATCH] Backups:"
echo "  $MINER_ORIG"
echo "  $MINERRUN_ORIG"
echo "[KERYX-PATCH] Log: $LOG"
