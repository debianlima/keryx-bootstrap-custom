# Release notes - Keryx Windows KRX/Ollama v9

## Nome sugerido da release

```text
v0.3.2-opoi-windows-krx-v9
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

## Mudancas principais

- Mantem o script/menu original do miner service pack.
- Coloca os argumentos OPoI diretamente no campo `KeryxArgs` existente.
- Inicia e aguarda Ollama antes do Keryx.
- Cria/pre-carrega `keryx8b-win` antes do minerador.
- Inicia e aguarda o router local antes do Keryx.
- Router normaliza respostas R1/Ollama para `choices[0].message.content`.
- Router roteia 8B/tinyllama local e 32B remoto.
- Desativa OpenCL no Windows/NVIDIA para evitar panic.

## Comando Keryx usado

```text
-s stratum+tcp://krx.baikalmine.com:9020 --mining-address keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa.ESPOSA --high --external-inference-url http://127.0.0.1:11500/v1/chat/completions --external-inference-model tinyllama=keryx8b-win --external-inference-model deepseek-r1-8b=keryx8b-win --external-inference-model deepseek-r1-32b=keryx32b --external-inference-timeout-sec 900
```
