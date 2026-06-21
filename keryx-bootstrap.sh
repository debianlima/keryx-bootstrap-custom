#!/usr/bin/env bash
set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
. ./h-manifest.conf

PACKAGE_URL="${KERYX_PACKAGE_URL:-https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-miner-v032opoi_hiveosv5.tar.gz}"
PACKAGE_SHA256="${KERYX_PACKAGE_SHA256:-}"
TMP_BASE="${TMPDIR:-/tmp}/keryx-bootstrap.$$"
LOCK="/tmp/keryx-bootstrap-custom.lock"

log() { echo "$(date -Is) [KERYX-BOOTSTRAP] $*"; }

mkdir -p /var/log/miner "$DIR/models" "$DIR/.keryx-cache" "$DIR/tmp"
touch "$CUSTOM_LOG_BASENAME.log" 2>/dev/null || true

exec 9>"$LOCK"
if command -v flock >/dev/null 2>&1; then
  flock -w 180 9 || { log "ERRO: não consegui lock em $LOCK"; exit 1; }
fi

write_wrapper() {
  cat > "$DIR/keryx-miner" <<'WRAP'
#!/usr/bin/env bash
set -Eeuo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -x "$DIR/keryx-miner.bin" ]; then
  "$DIR/keryx-bootstrap.sh"
fi
exec "$DIR/keryx-miner.bin" "$@"
WRAP
  chmod 755 "$DIR/keryx-miner"
}

is_elf() {
  [ -f "$1" ] || return 1
  [ "$(head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "7f454c46" ]
}

if [ -x "$DIR/keryx-miner.bin" ]; then
  log "binário já existe: $DIR/keryx-miner.bin"
  write_wrapper
  chmod 755 "$DIR"/*.sh "$DIR/h-run" "$DIR/keryx-miner" "$DIR/keryx-miner.bin" 2>/dev/null || true
  exit 0
fi

rm -rf "$TMP_BASE"
mkdir -p "$TMP_BASE/extract"
ARCHIVE="$TMP_BASE/keryx-package.tar.gz"

log "baixando pacote Keryx real"
log "URL: $PACKAGE_URL"
if command -v curl >/dev/null 2>&1; then
  curl -L --fail --retry 5 --retry-delay 5 --connect-timeout 30 --max-time 1800 -o "$ARCHIVE" "$PACKAGE_URL"
else
  wget --tries=5 --timeout=30 -O "$ARCHIVE" "$PACKAGE_URL"
fi

log "verificando gzip"
gzip -t "$ARCHIVE"

if [ -n "$PACKAGE_SHA256" ]; then
  log "verificando sha256"
  printf '%s  %s\n' "$PACKAGE_SHA256" "$ARCHIVE" | sha256sum -c -
fi

log "listando pacote"
tar -tzf "$ARCHIVE" | head -40 || true

if ! tar -tzf "$ARCHIVE" | grep -Eq '(^|/)keryx-miner(\.bin)?$|^keryx-miner/'; then
  log "ERRO: pacote não parece conter keryx-miner/keryx-miner.bin"
  exit 1
fi

log "extraindo pacote em área temporária"
tar -xzf "$ARCHIVE" -C "$TMP_BASE/extract"

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
  log "binário ELF detectado como keryx-miner; renomeando para keryx-miner.bin"
  mv -f "$DIR/keryx-miner" "$DIR/keryx-miner.bin"
fi

if [ ! -f "$DIR/keryx-miner.bin" ]; then
  found="$(find "$DIR" -maxdepth 3 -type f \( -name 'keryx-miner.bin' -o -name 'keryx-miner' \) | head -n 1 || true)"
  if [ -n "$found" ] && is_elf "$found"; then
    log "binário encontrado em $found; copiando para $DIR/keryx-miner.bin"
    cp -f "$found" "$DIR/keryx-miner.bin"
  fi
fi

write_wrapper
chmod -R 755 "$DIR" 2>/dev/null || true
chmod 755 "$DIR/h-manifest.conf" "$DIR/h-config.sh" "$DIR/h-run.sh" "$DIR/h-run" "$DIR/h-stats.sh" "$DIR/keryx-bootstrap.sh" "$DIR/keryx-miner" 2>/dev/null || true
[ -f "$DIR/keryx-miner.bin" ] && chmod 755 "$DIR/keryx-miner.bin"

if [ ! -x "$DIR/keryx-miner.bin" ]; then
  log "ERRO: não encontrei keryx-miner.bin executável após baixar o pacote."
  ls -la "$DIR" || true
  exit 1
fi

log "bootstrap concluído"
rm -rf "$TMP_BASE"
