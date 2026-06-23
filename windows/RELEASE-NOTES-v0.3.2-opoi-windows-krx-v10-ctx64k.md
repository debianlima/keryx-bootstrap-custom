# Release notes - Keryx Windows KRX/Ollama v10 ctx64k

## Nome sugerido da release

```text
v0.3.2-opoi-windows-krx-v10-ctx64k
```

## Conteudo esperado do ZIP da release

```text
KeryxMiner\keryx-miner.exe
KeryxMiner\keryxcuda.dll
KeryxMiner\cudart64_12.dll
KeryxMiner\cublas64_12.dll
KeryxMiner\cublasLt64_12.dll
KeryxMiner\curand64_10.dll
miner_service_pack\MinerTray.ps1
miner_service_pack\MinerService.ps1
miner_service_pack\router\keryx_ollama_router.ps1
miner_service_pack\config.json
```

## Runtime padrao

```text
Keryx custom: C:\miners\KeryxMiner
Menu/tray:    C:\miners\miner_service_pack
Ollama local: http://127.0.0.1:11434
Router:       http://127.0.0.1:11500
Rig 32B:      http://172.16.0.110:11434
```

## Mudancas principais da v10

- Mantem o script/menu original do miner service pack.
- Coloca os argumentos OPoI diretamente no campo `KeryxArgs` existente.
- Inicia e aguarda Ollama antes do Keryx.
- Recria/pre-carrega `keryx8b-win` com `PARAMETER num_ctx 65536`.
- Ajusta o preload do Ollama para `num_ctx = 65536` e `num_gpu = 999`.
- Router local tenta contextos em ordem decrescente: `65536, 49152, 32768, 24576, 16384, 8192, 4096`.
- Router normaliza respostas R1/Ollama para `choices[0].message.content`.
- Router roteia 8B/tinyllama local e 32B remoto.
- Desativa OpenCL no Windows/NVIDIA para evitar panic.

## Motivo do ctx64k

Nos testes Windows, o modelo local com 32k de contexto estava usando aproximadamente 6,6 GB dos 12 GB da RTX 3060. A v10 aumenta o contexto para 64k para aproveitar melhor a VRAM disponivel.

## Comando Keryx usado

```text
-s stratum+tcp://krx.baikalmine.com:9020 --mining-address keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa.ESPOSA --high --external-inference-url http://127.0.0.1:11500/v1/chat/completions --external-inference-model tinyllama=keryx8b-win --external-inference-model deepseek-r1-8b=keryx8b-win --external-inference-model deepseek-r1-32b=keryx32b --external-inference-timeout-sec 900
```
