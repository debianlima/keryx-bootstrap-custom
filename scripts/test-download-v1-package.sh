#!/usr/bin/env bash
set -Eeuo pipefail

URL="${KERYX_TEST_URL:-https://github.com/debianlima/keryx-bootstrap-custom/releases/download/v1.0/keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-linux-amd64.tar.gz}"
SHA256="${KERYX_TEST_SHA256:-ca7097c3be648eac5d0e89a1ce6ef4bdef92a0f387cb0e62dac16deddec88558}"
WORKDIR="${KERYX_TEST_WORKDIR:-/tmp/keryx-download-v1-test}"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/extract"
PKG="$WORKDIR/keryx.tar.gz"

echo "[KERYX-TEST] Baixando: $URL"

if command -v curl >/dev/null 2>&1; then
  curl -L --fail --retry 3 --retry-delay 3 --connect-timeout 30 --max-time 1800 -o "$PKG" "$URL"
elif command -v wget >/dev/null 2>&1; then
  wget --tries=3 --timeout=30 -O "$PKG" "$URL"
else
  echo "ERRO: precisa de curl ou wget" >&2
  exit 1
fi

echo "[KERYX-TEST] Validando SHA256"
printf '%s  %s\n' "$SHA256" "$PKG" | sha256sum -c -

echo "[KERYX-TEST] Extraindo"
tar -xzf "$PKG" -C "$WORKDIR/extract"

BIN="$(find "$WORKDIR/extract" -type f \( -name 'keryx-miner.bin' -o -name 'keryx-miner' \) | head -n 1 || true)"
if [ -z "$BIN" ]; then
  echo "ERRO: binario nao encontrado no pacote" >&2
  find "$WORKDIR/extract" -maxdepth 4 -type f | sort >&2
  exit 1
fi

chmod +x "$BIN"
echo "[KERYX-TEST] Binario encontrado: $BIN"
"$BIN" --version || true
"$BIN" --help | grep -E -- '--external-inference-(url|model|api-key|timeout-sec)'

echo "[KERYX-TEST] OK"
