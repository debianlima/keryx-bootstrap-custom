# Replicacao em segundo rig - Keryx v1.1 + Ollama 32B

Este guia registra como replicar a configuracao validada em outro rig HiveOS.

## Contexto do rig destino

Rig citado:

```text
hostname: rig193C0C
GPUs: 2x RTX 3060 Ti 8 GB + 1x RTX 3070 Ti 8 GB
Arquitetura CUDA: sm86
Miner atual observado: xmrig-new + custom
```

Como 3060 Ti e 3070 Ti sao Ampere/sm86, o pacote v1.1 `with-plugins` usado no rig `hive9600k` tambem serve.

## 1. Instalar Ollama

```bash
sudo su

if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

systemctl enable ollama
```

## 2. Configurar Ollama para 32B / 32k

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

## 3. Resolver SSH host key se o IP foi reaproveitado

Sintoma observado:

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
Offending ECDSA key in /root/.ssh/known_hosts
Host key verification failed.
```

Se o IP e confiavel e esta na rede local:

```bash
ssh-keygen -f "/root/.ssh/known_hosts" -R "172.16.0.110"
ssh-keygen -f "/root/.ssh/known_hosts" -R "[172.16.0.110]:22"
```

Testar origem:

```bash
ssh root@172.16.0.110 'hostname; nvidia-smi -L; ls -lh /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf'
```

Resultado esperado no rig origem validado:

```text
hive9600k
3x NVIDIA GeForce RTX 3060 Ti
/hive/miners/custom/models/DeepSeek-R1-32B/model.gguf 19G
```

## 4. Copiar o modelo 32B

Se `rsync` falhar com:

```text
bash: line 1: rsync: command not found
```

use `scp`:

```bash
mkdir -p /hive/miners/custom/models/DeepSeek-R1-32B

scp root@172.16.0.110:/hive/miners/custom/models/DeepSeek-R1-32B/model.gguf \
  /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
```

Conferir:

```bash
ls -lh /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
```

## 5. Copiar o Modelfile do rig antigo, se existir

```bash
scp root@172.16.0.110:/tmp/Modelfile.keryx32b /tmp/Modelfile.keryx32b
cat /tmp/Modelfile.keryx32b
```

Se `/tmp/Modelfile.keryx32b` nao existir no rig antigo, recriar:

```bash
cat > /tmp/Modelfile.keryx32b <<'EOF'
FROM /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
PARAMETER num_ctx 32768
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER repeat_last_n -1
EOF
```

Criar modelo no Ollama:

```bash
ollama create keryx32b -f /tmp/Modelfile.keryx32b
```

## 6. Pre-carregar o modelo 32B

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

Resultado esperado, podendo variar conforme 3070 Ti:

```text
keryx32b:latest    23 GB    CPU/GPU    32768    Forever
```

## 7. Instalar Keryx v1.1 with-plugins

```bash
miner stop 2>/dev/null || true
screen -wipe || true

cd /hive/miners/custom

BKP="/hive/miners/custom.bkp.before-v11-full.$(date +%F-%H%M%S)"
cp -a /hive/miners/custom "$BKP"
echo "Backup criado em: $BKP"

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

## 8. Testar Keryx manualmente

```bash
cd /hive/miners/custom

RUST_BACKTRACE=1 ./keryx-miner.bin \
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

Logs esperados:

```text
External OPoI backend verified — virtual capabilities enabled.
OPoI: declaring 3 model(s) to pool bridge
Plugins found 3 workers
External OPoI: inference complete via 'deepseek-r1-32b'
Share accepted
```

## 9. HiveOS / Flight Sheet

Argumentos extras/custom:

```text
--high --external-inference-url http://127.0.0.1:11434/v1/chat/completions --external-inference-model tinyllama=keryx32b --external-inference-model deepseek-r1-8b=keryx32b --external-inference-model deepseek-r1-32b=keryx32b --external-inference-timeout-sec 900
```

Pool:

```text
stratum+tcp://krx.baikalmine.com:9020
```

Depois:

```bash
miner stop
miner start
miner
```

## 10. Monitoramento

```bash
watch -n 5 'ollama ps; echo; nvidia-smi --query-gpu=index,name,memory.used,memory.free,utilization.gpu,power.draw --format=csv,noheader,nounits; echo; free -h'
```

```bash
grep -iE "External OPoI|OPoI challenge|inference complete|Share accepted|rejected|error|panic|hashrate" \
  /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```

## Observacoes

- OPoI pausa todos os workers PoW enquanto uma unica inferencia esta pendente.
- `via 'tinyllama'` ou `via 'deepseek-r1-8b'` nao significa que o Ollama usou modelo inferior; com o mapeamento atual, todos apontam para `keryx32b`.
- `via 'deepseek-r1-32b'` indica que a capacidade solicitada pelo pool/Keryx foi a de 32B e tambem foi atendida pelo `keryx32b`.
