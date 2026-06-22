# Setup HiveOS + Ollama + Keryx 32B externo

Este guia reproduz a configuracao validada para rodar Keryx no HiveOS com OPoI externo via Ollama.

## 1. Instalar ou garantir Ollama

```bash
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

systemctl enable ollama
```

## 2. Configurar Ollama para 32k e apenas um modelo carregado

```bash
mkdir -p /etc/systemd/system/ollama.service.d

cat > /etc/systemd/system/ollama.service.d/override.conf <<'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_CONTEXT_LENGTH=32768"
Environment="OLLAMA_KEEP_ALIVE=-1"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="OLLAMA_MAX_LOADED_MODELS=1"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q4_0"
Environment="OLLAMA_SCHED_SPREAD=true"
EOF

systemctl daemon-reload
systemctl restart ollama
sleep 5

systemctl status ollama --no-pager -l
ss -lntp | grep 11434
```

## 3. Garantir modelo GGUF 32B

Caminho esperado:

```text
/hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
```

Conferir:

```bash
ls -lh /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
```

Se precisar copiar de outro rig:

```bash
mkdir -p /hive/miners/custom/models/DeepSeek-R1-32B

scp root@IP_DO_RIG_ORIGEM:/hive/miners/custom/models/DeepSeek-R1-32B/model.gguf \
  /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
```

Se usar `rsync` e aparecer no remoto:

```text
bash: line 1: rsync: command not found
```

Instale `rsync` no rig de origem ou use `scp`.

## 4. Criar modelo Ollama `keryx32b` com contexto 32768

```bash
cat > /tmp/Modelfile.keryx32b <<'EOF'
FROM /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
PARAMETER num_ctx 32768
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER repeat_last_n -1
EOF

ollama create keryx32b -f /tmp/Modelfile.keryx32b
```

## 5. Pre-carregar o 32B

```bash
ollama stop keryx8b 2>/dev/null || true
ollama stop keryx32b 2>/dev/null || true

curl -sS --max-time 900 \
  http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "keryx32b",
    "prompt": "",
    "keep_alive": -1,
    "stream": false,
    "options": {
      "num_ctx": 32768
    }
  }'

ollama ps
nvidia-smi
free -h
```

Resultado validado em uma maquina com 3x RTX 3060 Ti 8 GB:

```text
keryx32b:latest    23 GB    11%/89% CPU/GPU    32768    Forever
```

## 6. Instalar pacote Keryx final with-plugins manualmente

```bash
miner stop 2>/dev/null || true
screen -wipe || true

cd /hive/miners/custom

URL="https://github.com/debianlima/keryx-bootstrap-custom/releases/download/v1.1/keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz"
SHA="c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e"

TMP="/tmp/keryx-v11-full"
PKG="/tmp/keryx-v11-full.tar.gz"

rm -rf "$TMP"
mkdir -p "$TMP"

wget -O "$PKG" "$URL" || exit 1
echo "$SHA  $PKG" | sha256sum -c - || exit 1

tar -xzf "$PKG" -C "$TMP" || exit 1

SRC="$(find "$TMP" -maxdepth 2 -type d -name 'keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins' | head -n1)"
echo "SRC=$SRC"

cp -f "$SRC/keryx-miner" /hive/miners/custom/keryx-miner
cp -f "$SRC/keryx-miner.bin" /hive/miners/custom/keryx-miner.bin
cp -f "$SRC/libkeryxcuda.so" /hive/miners/custom/libkeryxcuda.so
cp -f "$SRC/libkeryxopencl.so" /hive/miners/custom/libkeryxopencl.so

chmod 755 /hive/miners/custom/keryx-miner \
          /hive/miners/custom/keryx-miner.bin \
          /hive/miners/custom/libkeryxcuda.so \
          /hive/miners/custom/libkeryxopencl.so

./keryx-miner.bin --help | grep external-inference
strings ./keryx-miner.bin | grep -Eo 'GLIBC_[0-9]+\.[0-9]+' | sort -Vu | tail -20
```

## 7. Rodar Keryx apontando todos os modelos para `keryx32b`

```bash
cd /hive/miners/custom

./keryx-miner.bin \
  -s stratum+tcp://krx.baikalmine.com:9020 \
  --mining-address keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa.ESPOSA \
  --high \
  --external-inference-url http://127.0.0.1:11434/v1/chat/completions \
  --external-inference-model tinyllama=keryx32b \
  --external-inference-model deepseek-r1-8b=keryx32b \
  --external-inference-model deepseek-r1-32b=keryx32b \
  --external-inference-timeout-sec 900 \
  2>&1 | tee /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log
```

## 8. Argumentos para HiveOS / Flight Sheet

Colocar no campo extra/custom args:

```text
--high --external-inference-url http://127.0.0.1:11434/v1/chat/completions --external-inference-model tinyllama=keryx32b --external-inference-model deepseek-r1-8b=keryx32b --external-inference-model deepseek-r1-32b=keryx32b --external-inference-timeout-sec 900
```

Pool URL:

```text
stratum+tcp://krx.baikalmine.com:9020
```

Wallet/template usado nos testes:

```text
keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa.ESPOSA
```

## 9. Teste para GPU-only opcional

Para testar se o modelo cabe mais em GPU, criar outro nome para nao destruir o modelo atual:

```bash
cat > /tmp/Modelfile.keryx32b-gpu <<'EOF'
FROM /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
PARAMETER num_ctx 32768
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER repeat_last_n -1
PARAMETER num_gpu 999
EOF

ollama create keryx32b-gpu -f /tmp/Modelfile.keryx32b-gpu
```

Pre-carregar:

```bash
ollama stop keryx32b 2>/dev/null || true
ollama stop keryx32b-gpu 2>/dev/null || true

curl -sS --max-time 900 \
  http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "keryx32b-gpu",
    "prompt": "",
    "keep_alive": -1,
    "stream": false,
    "options": {
      "num_ctx": 32768,
      "num_gpu": 999
    }
  }'

ollama ps
nvidia-smi
free -h
```

Se der OOM, voltar para `keryx32b` misto CPU/GPU.
