#!/usr/bin/env bash
# h-config.sh precisa funcionar de dois jeitos:
# 1) quando o HiveOS faz `source h-config.sh` dentro do miner-run;
# 2) quando chamamos direto para debug/manual.
# Por isso este arquivo DEFINE as funcoes esperadas pelo HiveOS e so gera
# config automaticamente quando executado diretamente.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIR/h-manifest.conf" ] && . "$DIR/h-manifest.conf"

[ -n "${CUSTOM_CONFIG_FILENAME:-}" ] || CUSTOM_CONFIG_FILENAME="$DIR/config.ini"
[ -n "${CUSTOM_LOG_BASENAME:-}" ] || CUSTOM_LOG_BASENAME="/var/log/miner/keryx-miner"
MINER_API_PORT="${WEB_PORT:-3338}"

# Defaults usados quando o Flight Sheet nao personalizar os campos.
DEFAULT_POOL="${KERYX_DEFAULT_POOL:-stratum+tcp://krx.baikalmine.com:9020}"
DEFAULT_WALLET="${KERYX_DEFAULT_WALLET:-keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa}"
DEFAULT_EXTRA="${KERYX_DEFAULT_EXTRA:---light}"

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
  POOL="${CUSTOM_URL:-${CUSTOM_POOL:-}}"
  WALLET="${CUSTOM_TEMPLATE:-${CUSTOM_WALLET:-}}"
  USER_EXTRA="${CUSTOM_USER_CONFIG:-}"

  [ -n "$POOL" ] || POOL="$DEFAULT_POOL"
  [ -n "$WALLET" ] || WALLET="$DEFAULT_WALLET"

  FAST_MODELS=0
  FAST_MODELS_FORCE=0
  MINER_EXTRA=""

  # Se o campo extra estiver vazio, usa --light. Se tiver apenas flags locais
  # (--no-fast-models, --fast-models etc.), mantem --light mesmo assim.
  EXTRA="${USER_EXTRA:-$DEFAULT_EXTRA}"

  # Opcoes locais consumidas pelo wrapper. Elas NAO sao repassadas ao binario,
  # para nao quebrar caso o minerador original nao reconheca esses argumentos.
  for arg in $EXTRA; do
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

  if [ -z "$(printf '%s' "$MINER_EXTRA" | tr -d '[:space:]')" ]; then
    MINER_EXTRA=" $DEFAULT_EXTRA"
  fi

  CONF="-s $POOL --mining-address $WALLET$MINER_EXTRA"

  mkdir -p "$(dirname "$CUSTOM_CONFIG_FILENAME")" /var/log/miner "$DIR/models" "$DIR/.keryx-cache" "$DIR/tmp"
  printf '%s\n' "$CONF" > "$CUSTOM_CONFIG_FILENAME"

  cat > "$DIR/keryx-local-options.env" <<EOF
KERYX_FAST_MODELS=$FAST_MODELS
KERYX_FAST_MODELS_FORCE=$FAST_MODELS_FORCE
KERYX_DEFAULT_POOL="$DEFAULT_POOL"
KERYX_DEFAULT_WALLET="$DEFAULT_WALLET"
KERYX_EFFECTIVE_POOL="$POOL"
KERYX_EFFECTIVE_WALLET="$WALLET"
KERYX_MINER_EXTRA="$MINER_EXTRA"
EOF

  printf '%s\n' "$CONF"
  return 0
}

# Debug/manual: ./h-config.sh
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  miner_config_gen "$@"
fi
