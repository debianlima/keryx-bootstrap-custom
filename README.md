# keryx-bootstrap-custom

sudo -i

cat > /root/install-keryx-v5-manual.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

URL="https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-miner-v032opoi_hiveosv5.tar.gz"

BASE="/hive/miners/custom/keryx-miner"
CUSTOM_DIR="/hive/miners/custom"
TMP="/tmp/keryx-miner-v5.tar.gz"

echo "============================================================"
echo "Instalador manual Keryx HiveOS v5"
echo "URL: $URL"
echo "============================================================"

echo
echo "[1/9] Parando minerador..."
miner stop 2>/dev/null || true
pkill -f keryx-miner 2>/dev/null || true
sleep 3

echo
echo "[2/9] Limpando instalações antigas do Keryx..."
cd "$CUSTOM_DIR"

rm -rf "$BASE"
rm -rf /hive/miners/custom/keryx-miner-v0.3.2-OPoI
rm -rf /hive/miners/custom/keryx-bootstrap-custom-bootstrap
rm -rf /hive/miners/custom/bootstrap
rm -f "$TMP"

echo
echo "[3/9] Baixando pacote v5..."
if command -v curl >/dev/null 2>&1; then
  curl -L --fail --retry 5 --retry-delay 5 --connect-timeout 30 -o "$TMP" "$URL"
else
  wget --tries=5 --timeout=30 -O "$TMP" "$URL"
fi

echo
echo "[4/9] Conferindo pacote..."
gzip -t "$TMP"

echo
echo "Primeiros arquivos dentro do pacote:"
tar -tzf "$TMP" | head -30

if ! tar -tzf "$TMP" | grep -q '^keryx-miner/h-run.sh$'; then
  echo
  echo "ERRO: pacote não está no formato esperado do HiveOS."
  echo "Esperado: keryx-miner/h-run.sh"
  exit 1
fi

echo
echo "[5/9] Extraindo em $CUSTOM_DIR..."
tar -xzf "$TMP" -C "$CUSTOM_DIR"

if [ ! -d "$BASE" ]; then
  echo "ERRO: pasta $BASE não foi criada."
  exit 1
fi

echo
echo "[6/9] Ajustando permissões..."
chmod -R 755 "$BASE"
chmod +x "$BASE"/h-run.sh "$BASE"/h-run "$BASE"/h-config.sh "$BASE"/h-stats.sh "$BASE"/keryx-bootstrap.sh "$BASE"/keryx-miner 2>/dev/null || true

mkdir -p "$BASE/models" "$BASE/.keryx-cache" /var/log/miner
chmod -R 755 "$BASE/models" "$BASE/.keryx-cache"

echo
echo "[7/9] Testando sintaxe dos scripts..."
cd "$BASE"

bash -n h-run.sh
bash -n h-stats.sh
bash -n h-config.sh
bash -n keryx-bootstrap.sh
bash -n keryx-miner

echo
echo "[8/9] Gerando config.ini..."
./h-config.sh || true

echo
echo "Config atual:"
cat config.ini 2>/dev/null || echo "config.ini não encontrado"

echo
echo "[9/9] Instalação concluída."
echo
echo "Pasta instalada:"
ls -la "$BASE"

echo
echo "Modelos/cache:"
ls -la "$BASE/models" "$BASE/.keryx-cache" 2>/dev/null || true

echo
echo "Para testar direto no terminal:"
echo "cd $BASE && ./h-run.sh"
echo
echo "Para iniciar pelo HiveOS, primeiro confirme que o Flight Sheet está com:"
echo "Miner name: keryx-miner"
echo "Install URL: $URL"
echo
echo "Depois rode:"
echo "miner start"
echo
echo "Log:"
echo "tail -f /var/log/miner/keryx-miner.log"
EOF

chmod 755 /root/install-keryx-v5-manual.sh

/root/install-keryx-v5-manual.sh
