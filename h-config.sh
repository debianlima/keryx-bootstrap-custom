#!/usr/bin/env bash
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIR/h-manifest.conf" ] && . "$DIR/h-manifest.conf"

: "${CUSTOM_CONFIG_FILENAME:=$DIR/config.ini}"

# Defaults usados quando o Flight Sheet não personalizar os campos.
DEFAULT_POOL="${KERYX_DEFAULT_POOL:-stratum+tcp://krx.baikalmine.com:9020}"
DEFAULT_WALLET="${KERYX_DEFAULT_WALLET:-keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa}"
DEFAULT_EXTRA="${KERYX_DEFAULT_EXTRA:---light}"

POOL="${CUSTOM_URL:-${CUSTOM_POOL:-}}"
WALLET="${CUSTOM_TEMPLATE:-${CUSTOM_WALLET:-}}"
EXTRA="${CUSTOM_USER_CONFIG:-}"

[ -n "$POOL" ] || POOL="$DEFAULT_POOL"
[ -n "$WALLET" ] || WALLET="$DEFAULT_WALLET"
[ -n "$EXTRA" ] || EXTRA="$DEFAULT_EXTRA"

FAST_MODELS=0
FAST_MODELS_FORCE=0
MINER_EXTRA=""

# Opções locais consumidas pelo wrapper. Elas NÃO são repassadas ao binário,
# para não quebrar caso o minerador original não reconheça esses argumentos.
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

CONF="-s $POOL --mining-address $WALLET$MINER_EXTRA"

mkdir -p "$(dirname "$CUSTOM_CONFIG_FILENAME")"
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
