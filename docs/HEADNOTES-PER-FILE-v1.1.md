# Headnotes por arquivo - Keryx v1.1 external backend

Este documento e um mapa de continuidade para humano ou IA. A ideia e permitir que alguem entenda rapidamente quais arquivos foram alterados, por que foram alterados, quais cuidados tomar e onde continuar.

## Estado validado em producao experimental

```text
Keryx Miner 0.3.2 no HiveOS
Pacote final: v1.1 reasoning-fix WITH-PLUGINS
Ollama local: http://127.0.0.1:11434/v1/chat/completions
Modelo Ollama: keryx32b
Modelo base: DeepSeek-R1-32B GGUF
Contexto: 32768
Keep alive: Forever / -1
Mapeamento: tinyllama, deepseek-r1-8b e deepseek-r1-32b -> keryx32b
PoW: 3 workers CUDA
Resultado: OPoI concluido, PoW retomado, Share accepted
```

## `README.md`

Funcao: entrada principal do repositorio.

Deve conter:

- Estado atual validado.
- Pacote final recomendado.
- Links para os documentos de handoff.
- Comando de execucao manual.
- Argumentos para HiveOS/Flight Sheet.
- Setup resumido do Ollama 32B.
- Proximos passos v1.2.

Risco se ficar desatualizado:

- Outra IA ou humano pode usar pacote antigo sem plugins e cair em `No workers specified`.
- Pode copiar plugins antigos e reintroduzir panic de TypeId.

## `keryx-bootstrap.sh`

Funcao: bootstrap do minerador custom no HiveOS.

Estado final esperado:

```text
KERYX_TAG=v1.1
KERYX_DEFAULT_PACKAGE_URL=https://github.com/debianlima/keryx-bootstrap-custom/releases/download/v1.1/keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz
KERYX_DEFAULT_PACKAGE_SHA256=c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e
```

Mudancas importantes:

- Aponta para o pacote final `with-plugins`.
- Suporta `.tar.gz` e `.zip`.
- Preserva scripts locais do HiveOS.
- Recria `keryx-miner` como wrapper para `h-run.sh`.
- Se `keryx-miner.bin` ja existir, nao baixa de novo; apenas regrava wrapper e sai.

Cuidados:

- Para forcar reinstalacao via bootstrap, remover ou renomear `/hive/miners/custom/keryx-miner.bin`.
- Nao deixar o pacote substituir `h-run.sh`, `h-config.sh`, `h-stats.sh`, `h-manifest.conf` e `config.ini` locais sem revisao.

## `scripts/test-download-v1-package.sh`

Funcao: teste de integridade do asset do release.

Estado final esperado:

```text
URL padrao: v1.1 reasoning-fix-with-plugins.tar.gz
SHA256 padrao: c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e
```

Validacoes esperadas:

- Download por curl ou wget.
- SHA256 do pacote.
- Extracao `.tar.gz` ou `.zip`.
- `keryx-miner.bin` ou `keryx-miner` encontrado.
- Flags `--external-inference-*` no help.
- Ausencia de `GLIBC_2.39`.
- Presenca de `libkeryxcuda.so`.
- Presenca de `libkeryxopencl.so`.

## `docs/HANDOFF-v1.1.md`

Funcao: estado funcional completo para continuidade.

Deve explicar:

- Arquitetura OPoI externo via Ollama.
- Ambiente validado.
- Pacote final correto.
- Interpretacao dos logs `via 'tinyllama'`, `via 'deepseek-r1-8b'`, `via 'deepseek-r1-32b'`.
- Risco `content` vs `reasoning`.
- Monitoramento.

## `docs/FILES-CHANGED-v1.1.md`

Funcao: inventario dos arquivos alterados/gerados.

Deve listar:

- Scripts do repo.
- Assets de release.
- Mudancas conceituais no fonte Keryx.
- Arquivos runtime no HiveOS.
- Commits relevantes.

## `docs/HIVEOS-OLLAMA-32B-SETUP.md`

Funcao: guia de instalacao/reproducao.

Deve cobrir:

- Instalar Ollama.
- Override systemd para contexto 32768.
- `OLLAMA_MAX_LOADED_MODELS=1`.
- `OLLAMA_KEEP_ALIVE=-1`.
- `OLLAMA_FLASH_ATTENTION=1`.
- `OLLAMA_KV_CACHE_TYPE=q4_0`.
- Criar `keryx32b`.
- Pre-carregar o modelo.
- Instalar pacote Keryx `with-plugins`.
- Rodar `--high` mapeando tudo para `keryx32b`.
- Teste opcional GPU-only com `keryx32b-gpu`.

## `docs/TROUBLESHOOTING-v1.1.md`

Funcao: erros reais e solucoes.

Deve conter no minimo:

- Panic OpenCL/CUDA por plugins antigos.
- `No workers specified`.
- Binario antigo sem `--external-inference-url`.
- Ollama `Connection refused`.
- `content` vazio e `reasoning` preenchido.
- `cudaMalloc failed`.
- `Closing miner`.
- OPoI pausa todas as GPUs.
- SSH host key changed.
- `rsync: command not found`.
- Hashrate baixo apos iniciar/reconectar.

## `docs/SECOND-RIG-REPLICATION-v1.1.md`

Funcao: replicar em outro rig.

Contexto validado:

```text
Rig destino citado: rig193C0C
GPUs: 2x RTX 3060 Ti + 1x RTX 3070 Ti
Arquitetura: sm86 / 8 GB
Pacote: mesmo v1.1 with-plugins
```

Deve incluir:

- Remover host key antiga se IP reaproveitado.
- Copiar `model.gguf` por `scp` se `rsync` nao existir no origem.
- Copiar `/tmp/Modelfile.keryx32b` se existir no rig antigo.
- Instalar Ollama.
- Criar `keryx32b`.
- Rodar o Keryx com `--high` e todos os modelos apontando para `keryx32b`.

## `docs/RUNTIME-OPERATIONS-v1.1.md`

Funcao: operacao diaria.

Deve explicar:

- Nao recarregar o modelo para limpar contexto; contexto nao acumula entre chamadas.
- Recarregar Ollama somente por estabilidade, OOM, travamento ou comportamento anormal.
- Interpretar OPoI pausando PoW.
- Interpretar `Closing miner`.
- Comandos de monitoramento.

## Fonte Keryx modificado - notas conceituais

Os arquivos de fonte patchados ficam no pacote de fonte customizado. Este repositorio e de bootstrap/assets, mas o handoff deve registrar o que foi feito.

### `src/slm.rs`

Mudancas conceituais:

- Cliente HTTP OpenAI-compatible.
- `--external-inference-url` usado como endpoint de `/v1/chat/completions`.
- `--external-inference-model internal=api_model`.
- Probe de backend antes de declarar capacidades virtuais.
- Skip de prefetch local para modelos servidos externamente.
- Parser aceita:

```text
choices[0].message.content
choices[0].text
choices[0].message.reasoning
```

Risco conhecido:

- `reasoning` e fallback de compatibilidade. O campo padrao para resposta final e `content`.
- v1.2 deve separar fallback no probe e resposta real.

### CLI / config

Flags adicionadas:

```text
--external-inference-url
--external-inference-model
--external-inference-api-key
--external-inference-timeout-sec
```

### Devfund/devwallet

Devfund observado em log:

```text
devfund enabled, mining 2.0% of the time to devfund address: keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa
```

## Arquivos runtime essenciais em `/hive/miners/custom`

```text
keryx-miner
keryx-miner.bin
libkeryxcuda.so
libkeryxopencl.so
h-run.sh
h-config.sh
h-stats.sh
h-manifest.conf
config.ini
models/DeepSeek-R1-32B/model.gguf
```

Todos os binarios/plugins do Keryx devem vir da mesma build v1.1 with-plugins.

## Logs de sucesso esperados

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
