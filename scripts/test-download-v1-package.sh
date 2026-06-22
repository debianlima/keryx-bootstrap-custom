#!/usr/bin/env bash
set -Eeuo pipefail

# Teste do pacote final v1.1 WITH-PLUGINS.
# Este script valida download, SHA256, flags externas, GLIBC e presenca dos plugins recompilados.
# O pacote sem plugins serve apenas para diagnostico; para producao use o with-plugins.

URL="${KERYX_TEST_URL:-https://github.com/debianlima/keryx-bootstrap-custom/releases/download/v1.1/keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz}"
SHA256="${KERYX_TEST_SHA256:-c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e}"
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

DIR="$(dirname "$BIN")"
CUDA_PLUGIN="$(find "$WORKDIR/extract" -type f -name 'libkeryxcuda.so' | head -n 1 || true)"
OPENCL_PLUGIN="$(find "$WORKDIR/extract" -type f -name 'libkeryxopencl.so' | head -n 1 || true)"

if [ -z "$CUDA_PLUGIN" ] || [ -z "$OPENCL_PLUGIN" ]; then
  echo "ERRO: pacote final precisa conter libkeryxcuda.so e libkeryxopencl.so recompilados junto com o binario" >&2
  find "$WORKDIR/extract" -maxdepth 4 -type f | sort >&2
  exit 1
fi

chmod +x "$BIN" "$CUDA_PLUGIN" "$OPENCL_PLUGIN"
echo "[KERYX-TEST] Binario encontrado: $BIN"
echo "[KERYX-TEST] CUDA plugin: $CUDA_PLUGIN"
echo "[KERYX-TEST] OpenCL plugin: $OPENCL_PLUGIN"
"$BIN" --version || true
"$BIN" --help | grep -E -- '--external-inference-(url|model|api-key|timeout-sec)'

for f in "$BIN" "$CUDA_PLUGIN" "$OPENCL_PLUGIN"; do
  echo "[KERYX-TEST] GLIBC symbols: $f"
  strings "$f" | grep -Eo 'GLIBC_[0-9]+\.[0-9]+' | sort -Vu | tail -20 || true
  if strings "$f" | grep -q 'GLIBC_2.39'; then
    echo "ERRO: $f ainda exige GLIBC_2.39" >&2
    exit 1
  fi
done

echo "[KERYX-TEST] OK"
