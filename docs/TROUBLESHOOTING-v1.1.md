# Troubleshooting - Keryx v1.1 external backend / Ollama

Este documento registra erros reais encontrados durante a implantacao e a solucao aplicada.

## 1. Panic `plugins/opencl/src/cli.rs` ou `plugins/cuda/src/cli.rs`

Sintoma:

```text
panicked at plugins/opencl/src/cli.rs:52:9:
Mismatch between definition and access ... Could not downcast ...
```

Ou depois de remover OpenCL:

```text
panicked at plugins/cuda/src/cli.rs:57:9:
Mismatch between definition and access ...
```

Causa:

```text
keryx-miner.bin novo + libkeryxcuda.so/libkeryxopencl.so antigos
```

Solucao:

- Usar pacote final `reasoning-fix-with-plugins`.
- Garantir que os plugins vieram da mesma build do binario.
- Nao copiar `.so` antigos de outra pasta/rig.

Comando para identificar:

```bash
find /hive/miners/custom -maxdepth 1 -type f -name 'libkeryx*.so*' -ls
```

## 2. `No workers specified`

Sintoma:

```text
Found plugins: []
Plugins found 0 workers
No workers specified
```

Causa:

- O binario sem plugins foi instalado.
- Os plugins foram movidos para fora da pasta para diagnostico.

Solucao:

Instalar pacote `with-plugins`:

```text
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-glibc234-reasoning-fix-with-plugins.tar.gz
```

## 3. `--external-inference-url wasn't expected`

Sintoma:

```text
error: Found argument '--external-inference-url' which wasn't expected
USAGE: keryx-miner.bin --keryxd-address <KERYXD_ADDRESS> --mining-address <MINING_ADDRESS>
```

Causa:

- `keryx-miner.bin` antigo/original foi executado.
- O binario patchado foi sobrescrito por uma copia antiga.

Solucao:

Conferir:

```bash
/hive/miners/custom/keryx-miner.bin --help | grep external-inference
```

Se nao aparecer, reinstalar o pacote final.

## 4. `Connection refused` no Ollama

Sintoma:

```text
external inference HTTP request failed ... Connection refused (os error 111)
```

E:

```bash
ollama list
Error: could not connect to ollama server, run 'ollama serve' to start it
```

Causa:

- Servico Ollama parado.
- Porta 11434 nao esta escutando.

Solucao:

```bash
systemctl daemon-reload
systemctl reset-failed ollama
systemctl restart ollama
sleep 5

systemctl status ollama --no-pager -l
ss -lntp | grep 11434
curl -s http://127.0.0.1:11434/api/version
ollama list
```

## 5. `content` vazio e `reasoning` preenchido

Sintoma em `curl`:

```json
"message": {
  "role": "assistant",
  "content": "",
  "reasoning": "..."
}
```

Sintoma antigo no Keryx:

```text
external inference response ... did not contain choices[0].message.content or choices[0].text
```

Causa:

- Ollama/DeepSeek-R1 pode retornar raciocinio em `message.reasoning` antes de resposta final em `content`.

Solucao atual v1.1:

- Parser aceita fallback em `choices[0].message.reasoning` quando `content` e `text` estao vazios.

Risco/TODO:

- `content` e o campo padrao de resposta final.
- Para v1.2, separar probe de resposta real e tentar forcar `content` nos desafios reais.

## 6. `cudaMalloc failed: out of memory` ao carregar 32B

Sintoma:

```text
cudaMalloc failed: out of memory
alloc_tensor_range: failed to allocate CUDA0 buffer
```

Causa:

- Contexto muito alto ou tentativa de colocar tudo na GPU.
- GPU0 sem VRAM livre suficiente.

Solucoes testadas:

- Reduzir contexto temporariamente para 4096/8192.
- Usar `OLLAMA_KV_CACHE_TYPE=q4_0`.
- Usar `OLLAMA_FLASH_ATTENTION=1`.
- Permitir CPU/RAM removendo `PARAMETER num_gpu 999`.
- Usar `OLLAMA_MAX_LOADED_MODELS=1` e `OLLAMA_NUM_PARALLEL=1`.

Estado validado:

```text
keryx32b 32k carregado como 11%/89% CPU/GPU em 3x 3060 Ti 8 GB
```

## 7. `Closing miner`

Sintoma:

```text
Closing miner
Client closed gracefully
Client closed, reconnecting
Connecting to krx.baikalmine.com:9020
```

Interpretacao:

- Nao e necessariamente erro fatal.
- Indica fechamento limpo da sessao e reconexao.
- Se reconecta e volta a minerar, esta ok.

Investigar se ocorrer em loop:

```bash
grep -iE "Closing miner|Client closed|reconnecting|Connecting to|error|panic" /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```

Contar ocorrencias:

```bash
grep -c "Closing miner" /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log
```

## 8. OPoI pausa todas as GPUs

Sintoma:

```text
OPoI challenge in progress — PoW paused, stand by
Device #0 ... stand by
Device #1 ... stand by
Device #2 ... stand by
```

Interpretacao:

- Normal.
- O desafio OPoI e uma tarefa unica/global.
- O minerador pausa todos os workers PoW enquanto aguarda uma unica inferencia OPoI.
- Depois de `OPoI challenge: done`, PoW retoma nas GPUs.

## 9. Host key SSH mudou ao copiar modelo

Sintoma:

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
Offending ECDSA key in /root/.ssh/known_hosts
Host key verification failed.
```

Solucao se o IP e confiavel e esta na rede local:

```bash
ssh-keygen -f "/root/.ssh/known_hosts" -R "172.16.0.110"
ssh-keygen -f "/root/.ssh/known_hosts" -R "[172.16.0.110]:22"
```

Depois testar:

```bash
ssh root@172.16.0.110 'hostname; nvidia-smi -L; ls -lh /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf'
```

## 10. `rsync: command not found` no host remoto

Sintoma:

```text
bash: line 1: rsync: command not found
rsync error: error in rsync protocol data stream
```

Causa:

- O rig de origem nao tem `rsync` instalado.

Solucoes:

```bash
ssh root@IP_ORIGEM 'apt update && apt install -y rsync'
```

Ou usar `scp` para o modelo grande:

```bash
mkdir -p /hive/miners/custom/models/DeepSeek-R1-32B

scp root@IP_ORIGEM:/hive/miners/custom/models/DeepSeek-R1-32B/model.gguf \
  /hive/miners/custom/models/DeepSeek-R1-32B/model.gguf
```

## 11. Hashrate baixo logo apos iniciar/reconectar

Sintoma:

```text
Current hashrate is 14.94 Mhash/s
```

Interpretacao:

- Pode ser normal logo apos start/reconnect ou durante OPoI.
- Aguardar ate `OPoI challenge: done` e novos notifies.
- No teste validado, depois voltou para perto de 995 Mhash/s.

## 12. Comandos gerais de diagnostico

```bash
ollama ps
nvidia-smi
free -h
```

```bash
grep -iE "External OPoI|OPoI challenge|inference complete|Share accepted|rejected|error|panic|hashrate|Closing miner" \
  /var/log/miner/keryx-v11-high-all-to-32b-ctx32k.log | tail -200
```
