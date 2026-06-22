# Documentacao de continuidade - Keryx HiveOS v1.1

Este diretorio existe para permitir que outra IA ou um humano continue o trabalho sem depender do historico do chat.

## Leitura recomendada

1. `HANDOFF-v1.1.md` - estado atual validado, arquitetura, comandos de producao e proximos passos.
2. `FILES-CHANGED-v1.1.md` - mapa dos arquivos alterados e o motivo de cada alteracao.
3. `HIVEOS-OLLAMA-32B-SETUP.md` - procedimento operacional para configurar o Ollama com `keryx32b` 32k e apontar todos os modelos internos para ele.
4. `TROUBLESHOOTING-v1.1.md` - erros encontrados durante a implantacao e como resolver.

## Estado resumido

A versao final validada em producao experimental e a **v1.1 reasoning-fix with-plugins**.

Ela usa:

- `keryx-miner.bin` com suporte a `--external-inference-*`.
- `libkeryxcuda.so` e `libkeryxopencl.so` recompilados junto com o binario.
- Compatibilidade HiveOS/Ubuntu 22.04 com simbolos ate `GLIBC_2.34`.
- Backend externo OpenAI-compatible apontando para Ollama local.
- Modelo Ollama `keryx32b` criado a partir de `/hive/miners/custom/models/DeepSeek-R1-32B/model.gguf`.
- Contexto 32768, `keep_alive=-1`, `OLLAMA_MAX_LOADED_MODELS=1`.

## Pacote final esperado

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/v1.1/keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz
```

SHA256:

```text
c71c0a6a3d36cbc3f84f56b8288d999222373d93f70d645671d68c8d724a349e
```

Se esse asset nao estiver anexado ao release `v1.1`, anexe antes de usar o bootstrap padrao.
