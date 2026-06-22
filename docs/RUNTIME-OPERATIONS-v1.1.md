# Operacao runtime - Keryx v1.1 + Ollama 32B

Este documento registra como operar e interpretar o sistema depois que ele ja esta instalado e minerando.

## Estado operacional desejado

```text
Keryx --high ativo
OPoI externo via Ollama local
Todos os modelos internos apontando para keryx32b
Ollama mantendo keryx32b carregado com keep_alive=-1
Contexto 32768
3 workers CUDA para PoW
Shares aceitas
```

Comando de referencia:

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

## `miner start` pelo HiveOS

O sistema foi validado tambem via:

```bash
miner start
miner
```

Logs esperados no screen do minerador:

```text
External OPoI backend verified — virtual capabilities enabled.
OPoI Phase-3 active — 3 local model(s) selected.
Plugins found 3 workers
OPoI: declaring 3 model(s) to pool bridge
```

## Interpretacao: OPoI pausa todas as placas

Durante um desafio OPoI, o log pode mostrar:

```text
OPoI challenge in progress — PoW paused, stand by
Device #0 ... stand by
Device #1 ... stand by
Device #2 ... stand by
```

Isso e normal.

Leitura correta:

```text
- OPoI e uma tarefa unica/global.
- O Keryx pausa todos os workers PoW enquanto a inferencia OPoI esta pendente.
- Nao sao tres requisicoes OPoI separadas.
- O Ollama responde uma vez.
- Depois de `OPoI challenge: done`, PoW retoma nas GPUs.
```

## Interpretacao: `via 'tinyllama'`, `via '8b'`, `via '32b'`

O log mostra o modelo interno solicitado pelo Keryx/pool:

```text
External OPoI: inference complete via 'tinyllama'
External OPoI: inference complete via 'deepseek-r1-8b'
External OPoI: inference complete via 'deepseek-r1-32b'
```

Com o mapeamento atual:

```text
--external-inference-model tinyllama=keryx32b
--external-inference-model deepseek-r1-8b=keryx32b
--external-inference-model deepseek-r1-32b=keryx32b
```

A interpretacao e:

| Log | Capacidade pedida pelo Keryx/pool | Modelo real no Ollama |
| --- | --- | --- |
| `via 'tinyllama'` | TinyLlama | `keryx32b` |
| `via 'deepseek-r1-8b'` | DeepSeek 8B | `keryx32b` |
| `via 'deepseek-r1-32b'` | DeepSeek 32B | `keryx32b` |

## `Closing miner`

Exemplo real:

```text
Closing miner
Client closed gracefully
Client closed, reconnecting
Connecting to krx.baikalmine.com:9020
```

Interpretacao:

```text
- Nao e necessariamente erro.
- Indica fechamento limpo da sessao e reconexao.
- Se reconecta e volta a minerar, esta normal.
- Investigar apenas se ocorrer em loop.
```

Comandos:

```bash
grep -iE "Closing miner|Client closed|reconnecting|Connecting to|error|panic" \
  /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```

```bash
grep -c "Closing miner" /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log
```

## Sobre recarregar o modelo

Nao e necessario recarregar o modelo para limpar contexto.

Motivo:

```text
keep_alive=-1 mantem pesos/modelo carregados na memoria.
Nao mantem uma conversa antiga crescendo indefinidamente.
Cada chamada /v1/chat/completions do Keryx e uma requisicao nova.
```

Recarregar so faz sentido por estabilidade:

```text
cudaMalloc failed
llama-server process has terminated
connection refused
ollama ps vazio
VRAM presa apos parada
OPoI demorando demais
muitos rejected
```

Reload manual seguro:

```bash
miner stop 2>/dev/null || true

ollama stop keryx32b
sleep 3

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

## Monitoramento rapido

```bash
ollama ps
nvidia-smi
free -h
```

Monitoramento continuo:

```bash
watch -n 5 'ollama ps; echo; nvidia-smi --query-gpu=index,name,memory.used,memory.free,utilization.gpu,power.draw --format=csv,noheader,nounits; echo; free -h'
```

Logs principais:

```bash
grep -iE "OPoI|inference complete|Share accepted|rejected|error|panic|hashrate|Closing miner|Client closed" \
  /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```

## Teste opcional: modelo GPU-only

Para testar sem destruir o modelo atual misto CPU/GPU, criar um segundo nome:

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

Rodar Keryx apontando para `keryx32b-gpu`:

```bash
cd /hive/miners/custom

./keryx-miner.bin \
  -s stratum+tcp://krx.baikalmine.com:9020 \
  --mining-address keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa.ESPOSA \
  --high \
  --external-inference-url http://127.0.0.1:11434/v1/chat/completions \
  --external-inference-model tinyllama=keryx32b-gpu \
  --external-inference-model deepseek-r1-8b=keryx32b-gpu \
  --external-inference-model deepseek-r1-32b=keryx32b-gpu \
  --external-inference-timeout-sec 900 \
  2>&1 | tee /var/log/miner/keryx-v11-high-all-to-32b-gpu-ctx32k.log
```

Se ocorrer OOM ou instabilidade, voltar para o modelo misto `keryx32b`.

## Sinais de sucesso

```text
External OPoI backend verified — virtual capabilities enabled.
OPoI: declaring 3 model(s) to pool bridge
External OPoI: inference complete via 'deepseek-r1-32b'
OPoI challenge: done ... — PoW resumes on next notify
Share accepted
Current hashrate perto de 900 Mhash/s a 1 Ghash/s em 3x 3060 Ti
```
