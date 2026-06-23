# Windows runtime - Keryx OPoI external backend

Este diretorio guarda o runtime Windows para usar o Keryx Miner custom compilado para Windows com roteamento OPoI via Ollama.

## Estrutura esperada na maquina Windows

```text
C:\miners\KeryxMiner\
  keryx-miner.exe
  keryxcuda.dll
  escrow.key
  cudart64_12.dll
  cublas64_12.dll
  cublasLt64_12.dll
  curand64_10.dll
  models\DeepSeek-R1-8B\model.gguf

C:\miners\miner_service_pack\
  MinerTray.ps1
  MinerService.ps1
  config.json
  router\keryx_ollama_router.ps1
```

## Ideia do runtime

O Keryx custom aceita apenas um endpoint `--external-inference-url`. Para permitir inferencia local e remota no mesmo minerador, o Windows sobe um router local em `127.0.0.1:11500`.

Roteamento usado:

```text
tinyllama       -> keryx8b-win local no Windows / Ollama 127.0.0.1:11434
deepseek-r1-8b  -> keryx8b-win local no Windows / Ollama 127.0.0.1:11434
deepseek-r1-32b -> keryx32b remoto em http://172.16.0.110:11434
```

O router normaliza a resposta para o formato OpenAI-compatible aceito pelo Keryx:

```json
{
  "choices": [
    {
      "message": {
        "content": "..."
      }
    }
  ]
}
```

Isso evita falha no probe quando o Ollama/R1 devolve `reasoning` ou outro formato sem `choices[0].message.content`.

## Como iniciar

Abra o tray original:

```powershell
cd C:\miners\miner_service_pack
powershell -ExecutionPolicy Bypass -File .\MinerTray.ps1
```

Depois use:

```text
Icone do tray > Iniciar Mineracao com Telas
```

O `MinerService.ps1` faz a ordem correta:

1. inicia/aguarda Ollama local em `127.0.0.1:11434`;
2. cria `keryx8b-win` se nao existir;
3. pre-carrega o modelo local;
4. inicia/aguarda router em `127.0.0.1:11500`;
5. desativa `*opencl*.dll` para evitar panic do plugin OpenCL no Windows/NVIDIA;
6. inicia `keryx-miner.exe`.

## Testes rapidos

```powershell
curl.exe -sS http://127.0.0.1:11434/api/version
curl.exe -sS http://127.0.0.1:11500/v1/models
```

Teste de chat real no router:

```powershell
$body = @{
  model = "keryx8b-win"
  messages = @(@{ role = "user"; content = "responda apenas ok" })
  stream = $false
  max_tokens = 16
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:11500/v1/chat/completions" `
  -ContentType "application/json" `
  -Body $body
```

## Argumentos do Keryx usados no config original

```text
-s stratum+tcp://krx.baikalmine.com:9020 --mining-address keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa.ESPOSA --high --external-inference-url http://127.0.0.1:11500/v1/chat/completions --external-inference-model tinyllama=keryx8b-win --external-inference-model deepseek-r1-8b=keryx8b-win --external-inference-model deepseek-r1-32b=keryx32b --external-inference-timeout-sec 900
```

## Restaurar o menu/tray do repo

O arquivo `miner_service_pack_original_krx_ollama_wait_v9.zip.b64` guarda o pacote do menu/tray em base64. Para restaurar:

```powershell
cd windows
powershell -ExecutionPolicy Bypass -File .\restore-miner-service-pack.ps1
```

## Release Windows

Este diretorio nao armazena os binarios compilados grandes por padrao. Use `windows/package-windows-release.ps1` na maquina Windows para gerar o ZIP da release contendo `keryx-miner.exe`, `keryxcuda.dll`, DLLs CUDA e o service pack.
