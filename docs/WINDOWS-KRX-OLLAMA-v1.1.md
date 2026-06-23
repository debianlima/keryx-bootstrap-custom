# Windows KRX + Ollama local/remoto

## Objetivo

Rodar o Keryx Miner custom no Windows usando uma RTX 3060 12 GB para responder as capacidades menores de OPoI com um modelo local 8B e encaminhar a capacidade 32B para um rig remoto com `keryx32b`.

## Topologia validada

```text
Keryx Miner Windows
  --external-inference-url http://127.0.0.1:11500/v1/chat/completions
      |
      v
Keryx Ollama Router PowerShell v11
      |-- tinyllama       -> Ollama Windows 127.0.0.1:11434 / keryx8b-win / ctx 65536
      |-- deepseek-r1-8b  -> Ollama Windows 127.0.0.1:11434 / keryx8b-win / ctx 65536
      `-- deepseek-r1-32b -> Ollama remoto 172.16.0.110:11434 / keryx32b
```

## Pastas padrao

```text
C:\miners\KeryxMiner
C:\miners\miner_service_pack
```

`C:\miners\KeryxMiner` deve conter o minerador compilado e os modelos:

```text
keryx-miner.exe
keryxcuda.dll
escrow.key
models\DeepSeek-R1-8B\model.gguf
```

`C:\miners\miner_service_pack` contem o menu/tray original, `MinerService.ps1`, `config.json` e o router.

## Modelo Ollama local 64k

O service pack cria/recria automaticamente `keryx8b-win` quando encontra:

```text
C:\miners\KeryxMiner\models\DeepSeek-R1-8B\model.gguf
```

Na versao v11, o modelo local e recriado com:

```text
PARAMETER num_ctx 65536
PARAMETER num_gpu 999
```

Motivo: nos testes Windows, o `keryx8b-win` com 32k usava aproximadamente 6,6 GB de VRAM em uma RTX 3060 12 GB. O contexto 64k aproveita melhor a VRAM disponivel.

A v11 nao sobrescreve `C:\miners\KeryxMiner\Modelfile.keryx8b-win` diretamente. Ela cria um Modelfile temporario em `%TEMP%` e passa esse arquivo para `ollama create`. Isso evita erro de arquivo bloqueado quando o Modelfile fixo fica preso por editor, antivirus ou processo anterior.

O modelo e carregado antes do minerador para evitar que o Keryx falhe no probe do backend externo.

## Router v11

O router v11 resolve os problemas encontrados durante os testes Windows:

- HTTP 400 no `/v1/chat/completions` para alguns modelos GGUF custom;
- resposta do modelo R1 com `reasoning` ou formato sem `content`;
- Keryx recusando backend quando nao encontra `choices[0].message.content` ou `choices[0].text`;
- necessidade de fallback para 32B remoto quando o 8B local falha;
- tentativa de contexto local ate `65536`, com fallback decrescente;
- erro de arquivo bloqueado ao recriar `Modelfile.keryx8b-win`.

Sequencia de contexto no router:

```text
65536 -> 49152 -> 32768 -> 24576 -> 16384 -> 8192 -> 4096
```

O router sempre devolve uma resposta normalizada para o Keryx.

## OpenCL desativado no Windows/NVIDIA

Durante testes, o plugin OpenCL causou panic no Windows:

```text
thread panicked at plugins\opencl\src\cli.rs
Rust cannot catch foreign exceptions
```

Por isso o service pack renomeia automaticamente `*opencl*.dll` para `.disabled` dentro de `C:\miners\KeryxMiner` antes de iniciar o Keryx custom. Para RTX NVIDIA, o caminho pretendido e CUDA via `keryxcuda.dll`.

## Checklist de teste

```powershell
cd C:\miners\miner_service_pack
powershell -ExecutionPolicy Bypass -File .\MinerTray.ps1
```

Depois:

```text
Icone do tray > Iniciar Mineracao com Telas
```

Logs esperados no Keryx:

```text
External OPoI backend configured at http://127.0.0.1:11500/v1/chat/completions
External OPoI backend verified
virtual capabilities enabled
Share accepted
```

Logs esperados no router/service:

```text
Keryx Ollama Router PowerShell v11
Modo robusto: normaliza resposta e tenta contexto local ate 65536
Modelfile temporario 64k criado em %TEMP%
Modelo pedido: keryx8b-win -> LOCAL Windows / keryx8b-win
Modelo pedido: keryx32b -> REMOTE .110 / keryx32b
```

## Recriar manualmente o modelo local com 64k sem tocar no Modelfile fixo

```powershell
cd C:\miners\KeryxMiner
ollama stop keryx8b-win 2>$null
ollama rm keryx8b-win 2>$null

$tmp = Join-Path $env:TEMP "Modelfile.keryx8b-win.ctx65536.manual.tmp"
@'
FROM C:\miners\KeryxMiner\models\DeepSeek-R1-8B\model.gguf
PARAMETER num_ctx 65536
PARAMETER num_gpu 999
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
PARAMETER repeat_last_n -1
'@ | Set-Content -Encoding ASCII $tmp

ollama create keryx8b-win -f $tmp
Remove-Item $tmp -Force
```

Preload:

```powershell
$body = @{
  model = "keryx8b-win"
  prompt = ""
  keep_alive = -1
  stream = $false
  options = @{ num_ctx = 65536; num_gpu = 999 }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:11434/api/generate" -ContentType "application/json" -Body $body -TimeoutSec 900
ollama ps
nvidia-smi
```

## Release Windows

Use o script abaixo no Windows para empacotar uma release local:

```powershell
cd <repo>\windows
powershell -ExecutionPolicy Bypass -File .\package-windows-release.ps1 -Version v0.3.2-opoi-windows-krx-v11-ctx64k-tempmodelfile
```

O ZIP final inclui:

```text
keryx-miner.exe
keryxcuda.dll
DLLs CUDA necessarias
miner_service_pack
README da release
```

A release compilada nao deve ser recriada no Linux/HiveOS; ela depende do build Windows MSVC/CUDA ja validado na maquina Windows.
