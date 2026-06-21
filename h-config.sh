#!/usr/bin/env bash
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$DIR/h-manifest.conf" ] && . "$DIR/h-manifest.conf"

: "${CUSTOM_CONFIG_FILENAME:=$DIR/config.ini}"

POOL="${CUSTOM_URL:-${CUSTOM_POOL:-}}"
WALLET="${CUSTOM_TEMPLATE:-${CUSTOM_WALLET:-}}"
EXTRA="${CUSTOM_USER_CONFIG:-}"

# Default safe tier for 8 GB cards. Override in HiveOS User Config with:
# --no-opoi, --high, --very-high, or another Keryx flag set.
if [ -z "$EXTRA" ]; then
  EXTRA="--light"
fi

CONF=""
if [ -n "$POOL" ]; then
  CONF="$CONF -s $POOL"
fi
if [ -n "$WALLET" ]; then
  CONF="$CONF --mining-address $WALLET"
fi
CONF="$CONF $EXTRA"

mkdir -p "$(dirname "$CUSTOM_CONFIG_FILENAME")"
printf '%s\n' "$CONF" > "$CUSTOM_CONFIG_FILENAME"
printf '%s\n' "$CONF"
