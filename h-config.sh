#!/usr/bin/env bash
# h-config.sh precisa funcionar de dois jeitos:
# 1) quando o HiveOS faz `source h-config.sh` dentro do miner-run;
# 2) quando chamamos direto para debug/manual.
# Agora ele NAO usa pool/wallet/extra padrao: tudo vem do Flight Sheet/API do HiveOS.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_hiveos_flight_sheet() {
  [ -f /hive-config/rig.conf ] && . /hive-config/rig.conf 2>/dev/null || true
  [ -f /hive-config/wallet.conf ] && . /hive-config/wallet.conf 2>/dev/null || true
}

load_hiveos_flight_sheet
[ -f "$DIR/h-manifest.conf" ] && . "$DIR/h-manifest.conf"

[ -n "${CUSTOM_CONFIG_FILENAME:-}" ] || CUSTOM_CONFIG_FILENAME="$DIR/config.ini"
[ -n "${CUSTOM_LOG_BASENAME:-}" ] || CUSTOM_LOG_BASENAME="/var/log/miner/keryx-miner"
MINER_API_PORT="${WEB_PORT:-3338}"

# O miner-run do HiveOS chama miner_ver e, se ela devolver algo, tenta instalar
# pacote apt hive-miners-custom-<versao>. Para custom local/bootstrap isso NAO
# pode acontecer. Entao a funcao existe, mas retorna vazio.
miner_ver() {
  echo ""
}

miner_fork() {
  echo ""
}

miner_config_gen() {
  load_hiveos_flight_sheet

  POOL="${CUSTOM_URL:-${CUSTOM_POOL:-}}"
  WALLET="${CUSTOM_TEMPLATE:-${CUSTOM_WALLET:-}}"
  USER_EXTRA="${CUSTOM_USER_CONFIG:-}"

  FAST_MODELS=0
  FAST_MODELS_FORCE=0
  MINER_EXTRA=""

  # Opcoes locais consumidas pelo wrapper. Elas NAO sao repassadas ao binario.
  # Se o Extra config estiver vazio, nao forca --light nem qualquer outro default.
  for arg in $USER_EXTRA; do
    case "$arg" in
      --fast-models|--fast-model-download|--download-models-fast|--hf-models)
        FAST_MODELS=1
        ;;
      --fast-models-force|--force-fast-models)
        FAST_MODELS=1
        FAST_MODELS_FORCE=1
        ;;
      --no-fast-models)
        FAST_MODELS=0
        FAST_MODELS_FORCE=0
        ;;
      *)
        MINER_EXTRA="$MINER_EXTRA $arg"
        ;;
    esac
  done

  if [ -z "$POOL" ]; then
    echo "ERRO: CUSTOM_URL/Pool URL vazio no Flight Sheet do HiveOS." >&2
    return 13
  fi

  if [ -z "$WALLET" ]; then
    echo "ERRO: CUSTOM_TEMPLATE/Wallet and worker template vazio no Flight Sheet do HiveOS." >&2
    return 12
  fi

  CONF="-s $POOL --mining-address $WALLET$MINER_EXTRA"

  mkdir -p "$(dirname "$CUSTOM_CONFIG_FILENAME")" /var/log/miner "$DIR/models" "$DIR/.keryx-cache" "$DIR/tmp"
  printf '%s\n' "$CONF" > "$CUSTOM_CONFIG_FILENAME"

  cat > "$DIR/keryx-local-options.env" <<EOF
KERYX_FAST_MODELS=$FAST_MODELS
KERYX_FAST_MODELS_FORCE=$FAST_MODELS_FORCE
KERYX_EFFECTIVE_POOL="$POOL"
KERYX_EFFECTIVE_WALLET="$WALLET"
KERYX_MINER_EXTRA="$MINER_EXTRA"
KERYX_HIVEOS_CUSTOM_MINER="${CUSTOM_MINER:-}"
KERYX_HIVEOS_ALGO="${CUSTOM_ALGO:-}"
KERYX_HIVEOS_PASS="${CUSTOM_PASS:-}"
KERYX_HIVEOS_TLS="${CUSTOM_TLS:-}"
KERYX_HIVEOS_INSTALL_URL="${CUSTOM_INSTALL_URL:-}"
EOF

  printf '%s\n' "$CONF"
  return 0
}

# Debug/manual: ./h-config.sh
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  miner_config_gen "$@"
fi
