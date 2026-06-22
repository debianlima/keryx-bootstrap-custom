#!/usr/bin/env bash
set -Eeuo pipefail

URL="${KERYX_TEST_URL:-https://github.com/debianlima/keryx-bootstrap-custom/releases/download/v1.1/keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix.zip}"
SHA256="${KERYX_TEST_SHA256:-7232c21a65334c7c04dd42250e87acfd821b2daec3fe53403ca71c88da83b02f}"
WORKDIR="${KERYX_TEST_WORKDIR:-/tmp/keryx-download-v1-test}"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/extract"
PKG="$WORKDIR/keryx-package"

case "$URL" in
  *.zip) PKG="$PKG.zip" ;;
  *.tgz|*.tar.gz) PKG="$PKG.tar.gz" ;;
  *) PKG="$PKG.pkg" ;;
esac

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
if gzip -t "$PKG" >/dev/null 2>&1; then
  tar -xzf "$PKG" -C "$WORKDIR/extract"
elif unzip -t "$PKG" >/dev/null 2>&1; then
  unzip -q "$PKG" -d "$WORKDIR/extract"
else
  echo "ERRO: pacote nao parece .tar.gz nem .zip valido" >&2
  file "$PKG" 2>/dev/null || true
  exit 1
fi

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
strings "$BIN" | grep -Eo 'GLIBC_[0-9]+\.[0-9]+' | sort -Vu | tail -20 || true

if strings "$BIN" | grep -q 'GLIBC_2.39'; then
  echo "ERRO: binario ainda exige GLIBC_2.39" >&2
  exit 1
fi

echo "[KERYX-TEST] OK"
