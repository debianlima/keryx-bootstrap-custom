# Capacidades virtuais e encaminhamento de modelos - Keryx v1.1

Este documento explica o que foi chamado durante os testes de "placa virtual", "GPU virtual" ou "capacidade virtual" no Keryx.

## Definicao curta

Nao foi criada uma GPU virtual no sistema operacional.

O que foi criado no Keryx foi uma camada de **capacidades virtuais de OPoI**:

```text
Keryx declara ao pool que possui as capacidades TinyLlama, DeepSeek-R1-8B e DeepSeek-R1-32B.
Mas, em vez de carregar esses modelos localmente pelo motor interno, ele encaminha a inferencia para um backend externo OpenAI-compatible.
No setup validado, esse backend externo e o Ollama local.
```

Linha de log que confirma isso:

```text
External OPoI backend verified — virtual capabilities enabled.
```

## Arquitetura validada

```text
Pool / bridge Keryx
  -> envia desafio OPoI para um model_id interno
     -> Keryx identifica se o model_id esta em --external-inference-model
        -> se estiver, pula prefetch/carga local do modelo
        -> chama Ollama em http://127.0.0.1:11434/v1/chat/completions
        -> recebe resposta
        -> conclui desafio OPoI
        -> PoW volta nas GPUs CUDA
```

## Comando validado

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

## Encaminhamento configurado

| Capacidade interna declarada ao pool/Keryx | Modelo real chamado no Ollama | Observacao |
| --- | --- | --- |
| `tinyllama` | `keryx32b` | O pool pode pedir TinyLlama, mas a resposta vem do 32B externo. |
| `deepseek-r1-8b` | `keryx32b` | O pool pode pedir 8B, mas a resposta vem do 32B externo. |
| `deepseek-r1-32b` | `keryx32b` | O pool pede 32B e a resposta vem do 32B externo. |

## Interpretacao dos logs `via ...`

A linha abaixo mostra o **modelo interno solicitado pelo Keryx/pool**, nao necessariamente o nome real usado no Ollama:

```text
External OPoI: inference complete via 'tinyllama'
```

Com o mapeamento atual, isso significa:

```text
Capacidade solicitada: tinyllama
Modelo real usado: keryx32b
```

Tabela de leitura:

| Log | Capacidade solicitada | Modelo real usado |
| --- | --- | --- |
| `External OPoI: inference complete via 'tinyllama'` | TinyLlama | `keryx32b` |
| `External OPoI: inference complete via 'deepseek-r1-8b'` | DeepSeek 8B | `keryx32b` |
| `External OPoI: inference complete via 'deepseek-r1-32b'` | DeepSeek 32B | `keryx32b` |

## Teste validado de probe externo

Logs esperados no inicio:

```text
--high mode: loading TinyLlama + DeepSeek-R1-8B + DeepSeek-R1-32B.
External OPoI backend configured at http://127.0.0.1:11434/v1/chat/completions for ["tinyllama=keryx32b", "deepseek-r1-8b=keryx32b", "deepseek-r1-32b=keryx32b"]
External OPoI: probing model 'tinyllama' via http://127.0.0.1:11434/v1/chat/completions
External OPoI: model 'tinyllama' ready
External OPoI: probing model 'deepseek-r1-8b' via http://127.0.0.1:11434/v1/chat/completions
External OPoI: model 'deepseek-r1-8b' ready
External OPoI: probing model 'deepseek-r1-32b' via http://127.0.0.1:11434/v1/chat/completions
External OPoI: model 'deepseek-r1-32b' ready
External OPoI backend verified — virtual capabilities enabled.
```

Se esses logs aparecerem, significa que o Keryx aceitou declarar as capacidades virtuais ao pool.

## Teste validado de skip do modelo local

Logs esperados:

```text
OPoI Phase-3 active — 3 local model(s) selected.
Prefetching model files before mining starts…
SlmEngine: 'tinyllama' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-8b' served by external backend — skipping local model prefetch.
SlmEngine: 'deepseek-r1-32b' served by external backend — skipping local model prefetch.
Model files ready — starting mining.
```

Isso confirma que o Keryx nao tentou baixar/carregar localmente TinyLlama/8B/32B quando eles estavam mapeados para o backend externo.

## Teste validado de workers reais

A capacidade virtual OPoI nao substitui os workers PoW. O Keryx ainda precisa dos plugins CUDA/OpenCL compilados junto com o binario.

Logs esperados:

```text
Found plugins: ["/hive/miners/custom/libkeryxopencl.so", "/hive/miners/custom/libkeryxcuda.so"]
Plugins found 3 workers
Starting a CUDA worker
Device #0 compute version is 8.6
Starting a CUDA worker
Device #1 compute version is 8.6
Starting a CUDA worker
Device #2 compute version is 8.6
```

Se aparecer:

```text
Found plugins: []
Plugins found 0 workers
No workers specified
```

foi instalado o pacote sem plugins ou os `.so` foram removidos.

## Teste validado de OPoI real

Logs reais esperados:

```text
OPoI: declaring 3 model(s) to pool bridge
OPoI challenge: PoW suspended — model=bed9b0f5 nonce=...
External OPoI: inference complete via 'deepseek-r1-32b'
OPoI challenge: done for model bed9b0f5 (...) — PoW resumes on next notify
Share accepted
```

Observacao sobre `model=bed9b0f5`:

```text
Esse prefixo bate com o sha256 do modelo DeepSeek-R1-32B GGUF usado no Ollama.
Ele indica desafio ligado a capacidade/modelo 32B.
```

## Teste validado de shares e hashrate

Foi observado:

```text
Share accepted
Current hashrate is 995.15 Mhash/s
Device #0 ... 331.72 Mhash/s
Device #1 ... 331.72 Mhash/s
Device #2 ... 331.72 Mhash/s
```

Em outro momento:

```text
Shares: Accepted: 69 Pending: 0
OPoI challenge: done ...
Share accepted
```

## Comandos de validacao rapida

### 1. Verificar se Ollama esta vivo

```bash
ss -lntp | grep 11434
curl -s http://127.0.0.1:11434/api/version
ollama list
```

### 2. Verificar o modelo carregado

```bash
ollama ps
nvidia-smi
free -h
```

Resultado validado para 3x RTX 3060 Ti 8 GB:

```text
keryx32b:latest    23 GB    11%/89% CPU/GPU    32768    Forever
```

### 3. Testar API OpenAI-compatible diretamente

```bash
curl -sS --max-time 900 \
  http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "keryx32b",
    "messages": [
      {"role": "user", "content": "Responda em uma frase curta: pronto para OPoI Keryx"}
    ],
    "stream": false,
    "max_tokens": 128
  }'
```

### 4. Filtrar log do Keryx

```bash
grep -iE "External OPoI|OPoI challenge|inference complete|virtual capabilities|skipping local model|Plugins found|Share accepted|rejected|error|panic|hashrate" \
  /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```

## Erros que indicam problema no encaminhamento

### Ollama parado

```text
Connection refused (os error 111)
```

Corrigir:

```bash
systemctl restart ollama
ss -lntp | grep 11434
```

### Binario antigo sem flags externas

```text
error: Found argument '--external-inference-url' which wasn't expected
```

Corrigir reinstalando o pacote v1.1 with-plugins e conferir:

```bash
/hive/miners/custom/keryx-miner.bin --help | grep external-inference
```

### Plugins antigos misturados

```text
panicked at plugins/opencl/src/cli.rs
Mismatch between definition and access
```

Corrigir reinstalando o pacote v1.1 with-plugins inteiro, sem reaproveitar `.so` antigos.

## Resumo operacional

```text
A "placa virtual" neste projeto e a declaracao de capacidades virtuais de OPoI.
O PoW continua usando GPUs reais via plugins CUDA/OpenCL.
O OPoI e encaminhado para Ollama via HTTP.
Todos os modelos internos podem ser roteados para o mesmo keryx32b.
O teste completo deve provar: backend verified, skipping local prefetch, plugins found 3 workers, OPoI challenge done, Share accepted.
```
