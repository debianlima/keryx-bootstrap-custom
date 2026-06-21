#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
. ./h-manifest.conf

KERYX_REPO="${KERYX_REPO:-Keryx-Labs/keryx-miner}"
KERYX_TAG="${KERYX_TAG:-v0.3.2-OPoI}"
KERYX_CUDA_ARCH="${KERYX_CUDA_ARCH:-sm86}"
PACKAGE_URL="${KERYX_PACKAGE_URL:-${KERYX_REAL_PACKAGE_URL:-}}"
PACKAGE_SHA256="${KERYX_PACKAGE_SHA256:-}"
TMP_BASE="${TMPDIR:-/tmp}/keryx-bootstrap.$$"
LOCK="/tmp/keryx-bootstrap-custom.lock"

log() { echo "$(date -Is) [KERYX-BOOTSTRAP] $*"; }

mkdir -p /var/log/miner "$DIR/models" "$DIR/.keryx-cache" "$DIR/tmp"
touch "$CUSTOM_LOG_BASENAME.log" 2>/dev/null || true

exec 9>"$LOCK"
if command -v flock >/dev/null 2>&1; then
  flock -w 180 9 || { log "ERRO: nao consegui lock em $LOCK"; exit 1; }
fi

write_wrapper() {
  # Nunca deixar o pacote oficial sobrescrever o wrapper local com o binario real.
  # O HiveOS pode chamar CUSTOM_MINERBIN diretamente em alguns fluxos; por isso
  # keryx-miner precisa voltar para h-run.sh, que gera config.ini e chama o binario.
  cat > "$DIR/keryx-miner" <<'WRAP'
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/h-run.sh" "$@"
WRAP
  chmod 755 "$DIR/keryx-miner"
}

is_elf() {
  [ -f "$1" ] || return 1
  [ "$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "7f454c46" ]
}

fetch_url_to_file() {
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 5 --retry-delay 5 --connect-timeout 30 --max-time 1800 -o "$out" "$url"
  else
    wget --tries=5 --timeout=30 -O "$out" "$url"
  fi
}

resolve_package_url() {
  [ -n "$PACKAGE_URL" ] && { echo "$PACKAGE_URL"; return 0; }

  api="https://api.github.com/repos/$KERYX_REPO/releases/tags/$KERYX_TAG"
  json="$TMP_BASE/release.json"

  log "descobrindo pacote real no GitHub"
  log "repo: $KERYX_REPO"
  log "tag:  $KERYX_TAG"
  log "arch: $KERYX_CUDA_ARCH"
  log "api:  $api"

  fetch_url_to_file "$api" "$json"

  urls="$(grep -Eo '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' "$json" \
    | sed -E 's/^.*"(https:[^"]+)".*$/\1/' \
    | grep -Ei '\.(tar\.gz|tgz|zip)$' || true)"

  if [ -z "$urls" ]; then
    log "ERRO: nao encontrei assets .tar.gz/.tgz/.zip no release $KERYX_TAG"
    log "Trecho do JSON:"
    head -80 "$json" || true
    return 1
  fi

  selected="$(printf '%s\n' "$urls" | grep -Ei "$KERYX_CUDA_ARCH" | grep -Ei 'linux|ubuntu|hive|x86_64|amd64' | head -n 1 || true)"
  [ -n "$selected" ] || selected="$(printf '%s\n' "$urls" | grep -Ei "$KERYX_CUDA_ARCH" | head -n 1 || true)"
  [ -n "$selected" ] || selected="$(printf '%s\n' "$urls" | grep -Ei 'linux|ubuntu|hive|x86_64|amd64' | head -n 1 || true)"
  [ -n "$selected" ] || selected="$(printf '%s\n' "$urls" | head -n 1 || true)"

  if [ -z "$selected" ]; then
    log "ERRO: nao consegui escolher asset para baixar"
    printf '%s\n' "$urls" || true
    return 1
  fi

  log "asset escolhido: $selected"
  echo "$selected"
}

if [ -x "$DIR/keryx-miner.bin" ]; then
  log "binario ja existe: $DIR/keryx-miner.bin"
  write_wrapper
  chmod 755 "$DIR"/*.sh "$DIR/h-run" "$DIR/keryx-miner" "$DIR/keryx-miner.bin" 2>/dev/null || true
  exit 0
fi

rm -rf "$TMP_BASE"
mkdir -p "$TMP_BASE/extract"

PACKAGE_URL="$(resolve_package_url | tail -n 1)"
ARCHIVE="$TMP_BASE/keryx-package"

case "$PACKAGE_URL" in
  *.zip) ARCHIVE="$ARCHIVE.zip" ;;
  *.tgz|*.tar.gz) ARCHIVE="$ARCHIVE.tar.gz" ;;
  *) ARCHIVE="$ARCHIVE.pkg" ;;
esac

log "baixando pacote Keryx real"
log "URL: $PACKAGE_URL"
fetch_url_to_file "$PACKAGE_URL" "$ARCHIVE"

if [ -n "$PACKAGE_SHA256" ]; then
  log "verificando sha256"
  printf '%s  %s\n' "$PACKAGE_SHA256" "$ARCHIVE" | sha256sum -c -
fi

log "identificando pacote"
if command -v file >/dev/null 2>&1 && file "$ARCHIVE" 2>/dev/null | grep -qi 'zip'; then
  unzip -l "$ARCHIVE" | head -40 || true
  unzip -q "$ARCHIVE" -d "$TMP_BASE/extract"
elif gzip -t "$ARCHIVE" 2>/dev/null; then
  tar -tzf "$ARCHIVE" | head -40 || true
  tar -xzf "$ARCHIVE" -C "$TMP_BASE/extract"
elif unzip -t "$ARCHIVE" >/dev/null 2>&1; then
  unzip -l "$ARCHIVE" | head -40 || true
  unzip -q "$ARCHIVE" -d "$TMP_BASE/extract"
else
  log "ERRO: pacote baixado nao parece zip nem tar.gz valido"
  command -v file >/dev/null 2>&1 && file "$ARCHIVE" || true
  head -40 "$ARCHIVE" || true
  exit 1
fi

SRC=""
if [ -d "$TMP_BASE/extract/keryx-miner" ]; then
  SRC="$TMP_BASE/extract/keryx-miner"
else
  first_dir="$(find "$TMP_BASE/extract" -mindepth 1 -maxdepth 1 -type d | head -n 1 || true)"
  if [ -n "$first_dir" ]; then SRC="$first_dir"; else SRC="$TMP_BASE/extract"; fi
fi
log "origem detectada: $SRC"

shopt -s dotglob nullglob
for item in "$SRC"/* "$SRC"/.[!.]* "$SRC"/..?*; do
  [ -e "$item" ] || continue
  name="$(basename "$item")"
  case "$name" in
    h-manifest.conf|h-run.sh|h-run|h-config.sh|h-stats.sh|keryx-bootstrap.sh|config.ini)
      log "preservando script local: $name"; continue ;;
  esac
  cp -a "$item" "$DIR/"
done
shopt -u dotglob nullglob

if is_elf "$DIR/keryx-miner"; then
  log "binario ELF detectado como keryx-miner; renomeando para keryx-miner.bin"
  mv -f "$DIR/keryx-miner" "$DIR/keryx-miner.bin"
fi

if [ ! -f "$DIR/keryx-miner.bin" ]; then
  found="$(find "$DIR" -maxdepth 4 -type f \( -name 'keryx-miner.bin' -o -name 'keryx-miner' \) | head -n 1 || true)"
  if [ -n "$found" ] && is_elf "$found"; then
    log "binario encontrado em $found; copiando para $DIR/keryx-miner.bin"
    cp -f "$found" "$DIR/keryx-miner.bin"
  fi
fi

write_wrapper
chmod -R 755 "$DIR" 2>/dev/null || true
chmod 755 "$DIR/h-manifest.conf" "$DIR/h-config.sh" "$DIR/h-run.sh" "$DIR/h-run" "$DIR/h-stats.sh" "$DIR/keryx-bootstrap.sh" "$DIR/keryx-miner" 2>/dev/null || true
[ -f "$DIR/keryx-miner.bin" ] && chmod 755 "$DIR/keryx-miner.bin"

if [ ! -x "$DIR/keryx-miner.bin" ]; then
  log "ERRO: nao encontrei keryx-miner.bin executavel apos baixar o pacote."
  log "Arquivos encontrados:"
  find "$DIR" -maxdepth 3 -type f -print | sort || true
  exit 1
fi

log "bootstrap concluido"
rm -rf "$TMP_BASE"
