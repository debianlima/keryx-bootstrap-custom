# Arquivos alterados / headnotes - v1.1

Este arquivo lista os arquivos alterados ou artefatos gerados, com a finalidade de funcionar como um cabecalho de continuidade para humano ou IA.

## `keryx-bootstrap.sh`

Tipo: script HiveOS Custom Miner.

Estado final:

```text
Padrao v1.1 final: reasoning-fix WITH-PLUGINS
Pacote padrao: keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz
SHA256: c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e
```

Por que foi alterado:

- O pacote sem plugins validava o Ollama, mas falhava em producao com `No workers specified`.
- Plugins antigos copiados de outra build causavam panic `Mismatch between definition and access` em OpenCL/CUDA.
- O pacote final precisa baixar binario e plugins recompilados juntos.

Detalhes importantes:

- O script preserva scripts locais do HiveOS: `h-manifest.conf`, `h-run.sh`, `h-run`, `h-config.sh`, `h-stats.sh`, `keryx-bootstrap.sh`, `config.ini`.
- Se `keryx-miner.bin` ja existe, o bootstrap nao baixa novamente; ele apenas regrava o wrapper `keryx-miner` e sai.
- Para forcar novo download, remova/renomeie `/hive/miners/custom/keryx-miner.bin` ou use instalacao manual.

## `scripts/test-download-v1-package.sh`

Tipo: teste de integridade do asset do release.

Estado final:

```text
URL padrao: v1.1 reasoning-fix-with-plugins.tar.gz
SHA256: c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e
```

Validacoes feitas:

- Download via `curl` ou `wget`.
- SHA256 do pacote.
- Extracao `.tar.gz` ou `.zip`.
- Presenca de `keryx-miner.bin` ou `keryx-miner`.
- Presenca de `libkeryxcuda.so`.
- Presenca de `libkeryxopencl.so`.
- Flags `--external-inference-*` no `--help`.
- Ausencia de `GLIBC_2.39` no binario e plugins.

## Release asset: `reasoning-fix.zip`

Tipo: pacote diagnostico sem plugins.

Nome:

```text
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix.zip
```

SHA256:

```text
7232c21a65334c7c04dd42250e87acfd821b2daec3fe53403ca71c88da83b02f
```

Uso:

- Serve para validar que o binario aceita flags externas, GLIBC maximo 2.34 e fallback de `reasoning`.
- Nao serve para producao sozinho, pois sem plugins o minerador cai em `No workers specified`.

## Release asset: `reasoning-fix-with-plugins.tar.gz`

Tipo: pacote final recomendado.

Nome:

```text
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz
```

SHA256:

```text
c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e
```

Conteudo:

```text
keryx-miner
keryx-miner.bin
libkeryxcuda.so
libkeryxopencl.so
```

Uso:

- Producao experimental validada.
- Evita o erro `No workers specified`.
- Evita panic de TypeId por mistura de plugins antigos.

## Release asset: `reasoning-fix-with-plugins.zip`

Tipo: pacote alternativo final.

Nome:

```text
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.zip
```

SHA256:

```text
e06b68a0b6dfa7ede39098b590ff40f0db0a9b81f42beecfee9ccf1a2c812fae
```

Uso:

- Alternativa ao `.tar.gz`.
- O bootstrap e o script de teste suportam ZIP, mas o padrao final foi definido como `.tar.gz`.

## Fonte Keryx modificado - resumo conceitual

Os arquivos exatos ficam dentro do pacote de fonte customizado, nao necessariamente neste repositorio bootstrap. Mudancas conceituais aplicadas:

### `src/slm.rs`

Mudancas:

- Adicionado cliente HTTP externo OpenAI-compatible.
- Adicionado probe de backend externo antes de declarar capacidade virtual.
- Adicionado skip de prefetch local quando o modelo e servido externamente.
- Adicionado fallback para ler resposta em:

```text
choices[0].message.content
choices[0].text
choices[0].message.reasoning
```

Motivo:

- Ollama/DeepSeek-R1 retornou `content` vazio e `reasoning` preenchido em testes.
- Sem fallback, o Keryx rejeitava backend funcional com:

```text
external inference response ... did not contain choices[0].message.content or choices[0].text
```

Risco/TODO:

- Para v1.2, separar `reasoning` usado no probe de `content` esperado como resposta final do desafio real.

### CLI / argumentos externos

Flags adicionadas:

```text
--external-inference-url
--external-inference-model
--external-inference-api-key
--external-inference-timeout-sec
```

### Devwallet

Devfund configurado para:

```text
keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa
```

Logs observados:

```text
devfund enabled, mining 2.0% of the time to devfund address: keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa
```

## Arquivos runtime no HiveOS

Na pasta `/hive/miners/custom`, o estado funcional inclui:

```text
keryx-miner
keryx-miner.bin
libkeryxcuda.so
libkeryxopencl.so
h-config.sh
h-run.sh
h-run
h-stats.sh
h-manifest.conf
config.ini
models/DeepSeek-R1-32B/model.gguf
```

Nao misturar plugins antigos. Se houver suspeita:

```bash
find /hive/miners/custom -maxdepth 1 -type f -name 'libkeryx*.so*' -ls
```

## Commits relevantes desta etapa

```text
2eec53ffcb6e14750c2fcfa8339856f7485cac2e - keryx-bootstrap.sh aponta para pacote final with-plugins.
5ef6b932f7a128c72d8795198c8f1017bcbc9ca1 - script de teste valida pacote with-plugins.
```
