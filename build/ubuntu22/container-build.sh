#!/usr/bin/env bash
set -Eeuo pipefail

SRC_IN="${SRC_IN:-/src}"
OUT="${OUT:-/out}"
CUDA_COMPUTE_CAP="${CUDA_COMPUTE_CAP:-86}"
PACKAGE_BASENAME="${PACKAGE_BASENAME:-keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-ubuntu22}"
BUILD_DIR="${BUILD_DIR:-/work/src}"
LOG="/tmp/keryx-build.log"

log() { echo "$(date -Is) [KERYX-UBUNTU22-BUILD] $*"; }

if [ ! -f "$SRC_IN/Cargo.toml" ]; then
  echo "ERRO: /src precisa apontar para a raiz do fonte com Cargo.toml" >&2
  find "$SRC_IN" -maxdepth 3 -name Cargo.toml -print >&2 || true
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$OUT"
log "copiando fonte para area gravavel"
cp -a "$SRC_IN/." "$BUILD_DIR/"
cd "$BUILD_DIR"

# Alguns fontes originais tinham uma dev-dependency sha3 vinda direto do GitHub.
# Ela nao e necessaria para compilar o binario e pode quebrar builds offline/restritos.
if grep -q 'sha3.*git' Cargo.toml 2>/dev/null; then
  log "removendo dev-dependency sha3 git do Cargo.toml para build do binario"
  python3 - <<'PY'
from pathlib import Path
p = Path('Cargo.toml')
lines = p.read_text().splitlines()
out = []
for line in lines:
    if 'sha3' in line and 'git' in line:
        continue
    out.append(line)
p.write_text('\n'.join(out) + '\n')
PY
fi

export CUDA_COMPUTE_CAP
export CARGO_NET_GIT_FETCH_WITH_CLI=true

log "versoes"
rustc --version
cargo --version
nvcc --version | tail -n 3
ldd --version | head -n 1

log "iniciando cargo build release para sm${CUDA_COMPUTE_CAP}"
set -o pipefail
cargo build --release --bin keryx-miner 2>&1 | tee "$LOG"

BIN="$BUILD_DIR/target/release/keryx-miner"
if [ ! -x "$BIN" ]; then
  echo "ERRO: binario nao encontrado em $BIN" >&2
  exit 1
fi

PKG_DIR="$OUT/$PACKAGE_BASENAME"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"
cp -f "$BIN" "$PKG_DIR/keryx-miner.bin"
cp -f "$BIN" "$PKG_DIR/keryx-miner"
chmod 755 "$PKG_DIR/keryx-miner" "$PKG_DIR/keryx-miner.bin"
cp -f "$LOG" "$PKG_DIR/build.log"

{
  echo "# Keryx Miner build for HiveOS / Ubuntu 22.04"
  echo
  echo "Built inside nvidia/cuda:12.4.1-devel-ubuntu22.04"
  echo "Expected glibc baseline: 2.35"
  echo "CUDA_COMPUTE_CAP=$CUDA_COMPUTE_CAP"
  echo
  rustc --version
  cargo --version
  nvcc --version | tail -n 3
  ldd --version | head -n 1
} > "$PKG_DIR/README-BUILD.txt"

{
  echo "# ldd --version"
  ldd --version | head -n 1
  echo
  echo "# ldd keryx-miner.bin"
  ldd "$PKG_DIR/keryx-miner.bin" || true
} > "$PKG_DIR/LDD.txt"

"$PKG_DIR/keryx-miner.bin" --help > "$PKG_DIR/HELP.txt" 2>&1 || true
"$PKG_DIR/keryx-miner.bin" --version > "$PKG_DIR/VERSION.txt" 2>&1 || true

strings "$PKG_DIR/keryx-miner.bin" | grep -Eo 'GLIBC_[0-9]+\.[0-9]+' | sort -Vu > "$PKG_DIR/GLIBC_SYMBOLS.txt" || true

if grep -q 'GLIBC_2.39' "$PKG_DIR/GLIBC_SYMBOLS.txt"; then
  echo "ERRO: binario ainda exige GLIBC_2.39" >&2
  cat "$PKG_DIR/GLIBC_SYMBOLS.txt" >&2
  exit 1
fi

if ! grep -q -- '--external-inference-url' "$PKG_DIR/HELP.txt"; then
  echo "ERRO: help nao mostra --external-inference-url" >&2
  exit 1
fi

if ! strings "$PKG_DIR/keryx-miner.bin" | grep -q 'keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa'; then
  echo "ERRO: carteira devwallet esperada nao encontrada no binario" >&2
  exit 1
fi

(
  cd "$OUT"
  tar -czf "$PACKAGE_BASENAME.tar.gz" "$PACKAGE_BASENAME"
  zip -qr "$PACKAGE_BASENAME.zip" "$PACKAGE_BASENAME"
  sha256sum "$PACKAGE_BASENAME.tar.gz" "$PACKAGE_BASENAME.zip" > "$PACKAGE_BASENAME.SHA256SUMS.txt"
)

log "build concluido"
log "arquivos gerados em $OUT:"
ls -lh "$OUT" | sed -n '1,80p'
