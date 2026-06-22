# Handoff - Keryx Miner HiveOS v1.1 reasoning-fix with-plugins

Este documento registra o estado funcional atual para continuidade por humano ou outra IA.

## Objetivo

Rodar Keryx Miner no HiveOS usando o PoW local nas GPUs, mas desviando a inferencia OPoI para um backend externo local compativel com OpenAI, no caso Ollama.

O objetivo pratico validado foi:

```text
Keryx Miner HiveOS
  -> 3 workers CUDA para PoW
  -> OPoI externo via http://127.0.0.1:11434/v1/chat/completions
  -> todos os modelos internos podem apontar para um unico modelo Ollama keryx32b
```

## Estado validado

Ambiente validado principal:

```text
Rig: hive9600k
GPUs: 3x NVIDIA GeForce RTX 3060 Ti 8 GB
Ollama: 0.30.10
Modelo Ollama: keryx32b
Modelo base: /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
Contexto: 32768
Carregamento: 11% CPU / 89% GPU em um teste real
Keep alive: Forever / -1
Keryx: 0.3.2 com external backend patch
Pacote final: v1.1 reasoning-fix with-plugins
```

Resultados observados em log:

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
Current hashrate perto de 995 Mhash/s em 3x RTX 3060 Ti
```

## Pacote final

Usar o pacote **with-plugins**. O pacote sem plugins validava o backend externo, mas falhava em producao com:

```text
Found plugins: []
Plugins found 0 workers
No workers specified
```

Pacote final esperado:

```text
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz
```

URL esperada:

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

Todos esses binarios/plugins devem vir da mesma build. Nao misturar `keryx-miner.bin` novo com `libkeryxcuda.so`/`libkeryxopencl.so` antigos.

## Por que os plugins precisam vir juntos

Foi observado panic ao misturar binario novo com plugins antigos:

```text
panicked at plugins/opencl/src/cli.rs:52:9
Mismatch between definition and access ... Could not downcast ...
```

Depois de remover OpenCL, o mesmo erro passou para CUDA:

```text
panicked at plugins/cuda/src/cli.rs:57:9
Mismatch between definition and access ...
```

Conclusao: plugins e binario precisam ser recompilados juntos.

## Comando de producao validado

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

No HiveOS/Flight Sheet, usar os mesmos argumentos no campo de argumentos extras/custom.

## Interpretacao dos logs `via ...`

A linha abaixo mostra o modelo interno solicitado pelo Keryx/pool:

```text
External OPoI: inference complete via 'deepseek-r1-32b'
```

Com estes mapeamentos:

```text
--external-inference-model tinyllama=keryx32b
--external-inference-model deepseek-r1-8b=keryx32b
--external-inference-model deepseek-r1-32b=keryx32b
```

A leitura correta e:

| Log | Capacidade solicitada pelo Keryx/pool | Modelo real usado no Ollama |
| --- | --- | --- |
| `via 'tinyllama'` | TinyLlama | `keryx32b` |
| `via 'deepseek-r1-8b'` | DeepSeek 8B | `keryx32b` |
| `via 'deepseek-r1-32b'` | DeepSeek 32B | `keryx32b` |

## Sobre `content` vs `reasoning`

O padrao OpenAI-compatible esperado para resposta final e:

```text
choices[0].message.content
```

O Ollama/DeepSeek-R1 retornou em alguns testes:

```text
choices[0].message.content = ""
choices[0].message.reasoning = texto
```

A v1.1 usa fallback para aceitar `reasoning` quando `content`/`text` estao vazios. Isso permitiu validar o backend e concluir OPoI.

TODO recomendado para v1.2:

```text
- No probe/health-check, aceitar reasoning para validar backend vivo.
- Na resposta real do desafio, tentar forcar content como resposta final.
- Enviar prompt/sistema e parametros para reduzir thinking quando necessario.
- Opcionalmente tornar fallback para reasoning configuravel por flag.
```

## Comandos de monitoramento

```bash
ollama ps
nvidia-smi
free -h
```

```bash
grep -iE "OPoI|inference complete|Share accepted|rejected|error|panic|hashrate|Closing miner|Client closed" \
  /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```

```bash
watch -n 5 'ollama ps; echo; nvidia-smi --query-gpu=index,name,memory.used,memory.free,utilization.gpu,power.draw --format=csv,noheader,nounits; echo; free -h'
```

## Observacoes operacionais

- `OPoI challenge in progress — PoW paused` e normal: o PoW pausa globalmente enquanto uma inferencia OPoI unica esta pendente.
- As 3 GPUs aparecem em stand by durante OPoI porque o minerador pausa todos os workers; isso nao significa 3 requisicoes OPoI separadas.
- `Closing miner` seguido de `Client closed gracefully` e `Client closed, reconnecting` indica reconexao limpa; so vira problema se repetir em loop.
- Manter `keryx32b` carregado com `keep_alive=-1` nao enche contexto entre chamadas; mantem pesos do modelo na memoria, nao historico de conversa.
