#!/usr/bin/env bash
set -Eeuo pipefail

# Build host script.
# Usage:
#   ./build-ubuntu22-hiveos.sh /path/to/keryx-source-dir-or-zip /path/to/output

INPUT="${1:-.}"
OUT="${2:-$PWD/dist-ubuntu22}"
IMAGE="${KERYX_BUILDER_IMAGE:-keryx-ubuntu22-hiveos-builder:cuda12.4-rust1.88}"
CUDA_COMPUTE_CAP="${CUDA_COMPUTE_CAP:-86}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_CONTEXT="$SCRIPT_DIR/build/ubuntu22"
TMP=""

cleanup() {
  [ -n "$TMP" ] && rm -rf "$TMP" || true
}
trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado." >&2
  echo "Instale Docker ou rode em uma maquina com Docker disponivel." >&2
  exit 1
fi

SRC="$INPUT"
if [ -f "$INPUT" ]; then
  TMP="$(mktemp -d)"
  case "$INPUT" in
    *.zip)
      unzip -q "$INPUT" -d "$TMP"
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "$INPUT" -C "$TMP"
      ;;
    *)
      echo "ERRO: arquivo de entrada precisa ser .zip, .tar.gz ou diretorio." >&2
      exit 1
      ;;
  esac
  SRC="$(find "$TMP" -type f -name Cargo.toml -printf '%h\n' | head -n 1 || true)"
  if [ -z "$SRC" ]; then
    echo "ERRO: nao encontrei Cargo.toml dentro do pacote $INPUT" >&2
    find "$TMP" -maxdepth 4 -type f | sort >&2
    exit 1
  fi
elif [ -d "$INPUT" ]; then
  if [ ! -f "$INPUT/Cargo.toml" ]; then
    FOUND="$(find "$INPUT" -type f -name Cargo.toml -printf '%h\n' | head -n 1 || true)"
    [ -n "$FOUND" ] && SRC="$FOUND"
  fi
else
  echo "ERRO: entrada nao existe: $INPUT" >&2
  exit 1
fi

if [ ! -f "$SRC/Cargo.toml" ]; then
  echo "ERRO: nao encontrei Cargo.toml em $SRC" >&2
  exit 1
fi

mkdir -p "$OUT"
SRC="$(cd "$SRC" && pwd)"
OUT="$(cd "$OUT" && pwd)"

echo "[KERYX-BUILD] Fonte: $SRC"
echo "[KERYX-BUILD] Saida:  $OUT"
echo "[KERYX-BUILD] Image:  $IMAGE"
echo "[KERYX-BUILD] CUDA_COMPUTE_CAP=$CUDA_COMPUTE_CAP"

docker build -t "$IMAGE" "$BUILD_CONTEXT"

docker run --rm \
  -e CUDA_COMPUTE_CAP="$CUDA_COMPUTE_CAP" \
  -v "$SRC:/src:ro" \
  -v "$OUT:/out" \
  "$IMAGE"
