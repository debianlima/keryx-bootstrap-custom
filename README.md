# keryx-bootstrap-custom

Bootstrap e pacote custom para rodar **Keryx Miner 0.3.2 no HiveOS** com backend externo de inferencia OPoI via API OpenAI-compatible.

## Estado atual

Versao funcional validada: **v1.1 reasoning-fix with-plugins**.

Esta versao foi validada em producao experimental com:

```text
HiveOS custom miner
Keryx Miner 0.3.2
3 workers CUDA
Ollama local em http://127.0.0.1:11434/v1/chat/completions
Modelo Ollama keryx32b criado a partir de DeepSeek-R1-32B GGUF
Contexto 32768
keep_alive=-1 / Forever
--high ativo, declarando TinyLlama + DeepSeek-R1-8B + DeepSeek-R1-32B
Todos os modelos internos apontando para keryx32b
Shares aceitas depois de desafio OPoI
```

Log validado esperado:

```text
External OPoI backend verified — virtual capabilities enabled.
OPoI Phase-3 active — 3 local model(s) selected.
SlmEngine: 'tinyllama' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-8b' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-32b' served by external backend — skipping local model prefetch.
Plugins found 3 workers
OPoI: declaring 3 model(s) to pool bridge
External OPoI: inference complete via 'deepseek-r1-32b'
OPoI challenge: done ... — PoW resumes on next notify
Share accepted
```

## Documentacao principal

Leia nesta ordem:

1. [`docs/HANDOFF-v1.1.md`](docs/HANDOFF-v1.1.md) - estado atual, arquitetura e comandos validados.
2. [`docs/FILES-CHANGED-v1.1.md`](docs/FILES-CHANGED-v1.1.md) - mapa dos arquivos alterados e motivo de cada mudanca.
3. [`docs/HIVEOS-OLLAMA-32B-SETUP.md`](docs/HIVEOS-OLLAMA-32B-SETUP.md) - procedimento de instalacao/replicacao em outro rig.
4. [`docs/TROUBLESHOOTING-v1.1.md`](docs/TROUBLESHOOTING-v1.1.md) - erros encontrados e solucoes.

## Pacote final recomendado

Usar o pacote **with-plugins**, nao o pacote sem plugins.

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/v1.1/keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz
```

SHA256:

```text
c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e
```

Conteudo esperado:

```text
keryx-miner
keryx-miner.bin
libkeryxcuda.so
libkeryxopencl.so
```

Motivo: o pacote sem plugins valida o backend externo, mas falha em producao com `No workers specified`. Plugins antigos misturados com binario novo causam panic `Mismatch between definition and access`.

## Bootstrap

`keryx-bootstrap.sh` agora aponta por padrao para o pacote final `v1.1 reasoning-fix-with-plugins`.

Observacao importante: se `/hive/miners/custom/keryx-miner.bin` ja existir, o bootstrap nao baixa novamente; ele apenas regrava o wrapper `keryx-miner`. Para forcar nova instalacao, remova ou renomeie o binario atual antes de rodar o bootstrap, ou use instalacao manual.

## Teste do pacote

```bash
wget -O /tmp/test-download-v1-package.sh \
  https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/test-download-v1-package.sh

chmod +x /tmp/test-download-v1-package.sh
/tmp/test-download-v1-package.sh
```

O teste valida:

```text
SHA256
flags --external-inference-*
GLIBC maximo sem GLIBC_2.39
presenca de libkeryxcuda.so
presenca de libkeryxopencl.so
```

## Comando validado direto no terminal

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

## Argumentos para HiveOS / Flight Sheet

Campo extra/custom args:

```text
--high --external-inference-url http://127.0.0.1:11434/v1/chat/completions --external-inference-model tinyllama=keryx32b --external-inference-model deepseek-r1-8b=keryx32b --external-inference-model deepseek-r1-32b=keryx32b --external-inference-timeout-sec 900
```

Pool:

```text
stratum+tcp://krx.baikalmine.com:9020
```

## Ollama 32B resumido

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
```

Criar modelo:

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

Pre-carregar:

```bash
curl -sS --max-time 900 \
  http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "keryx32b",
    "prompt": "",
    "keep_alive": -1,
    "stream": false,
    "options": { "num_ctx": 32768 }
  }'

ollama ps
nvidia-smi
free -h
```

## Proximos passos recomendados

v1.2:

```text
- Separar fallback de reasoning no probe de backend e resposta real OPoI.
- Tentar forcar respostas finais em choices[0].message.content.
- Tornar fallback de reasoning opcional por flag.
- Adicionar logs que mostrem model_id interno e api_model externo na mesma linha.
- Avaliar GPU-only com keryx32b-gpu sem destruir o keryx32b misto CPU/GPU.
```
