# Windows KRX + Ollama local/remoto

## Objetivo

Rodar o Keryx Miner custom no Windows usando uma RTX 3060 12 GB para responder as capacidades menores de OPoI com um modelo local 8B e encaminhar a capacidade 32B para um rig remoto com `keryx32b`.

## Topologia validada

```text
Keryx Miner Windows
  --external-inference-url http://127.0.0.1:11500/v1/chat/completions
      |
      v
Keryx Ollama Router PowerShell v9
      |-- tinyllama       -> Ollama Windows 127.0.0.1:11434 / keryx8b-win
      |-- deepseek-r1-8b  -> Ollama Windows 127.0.0.1:11434 / keryx8b-win
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

## Modelo Ollama local

O service pack cria automaticamente `keryx8b-win` quando encontra:

```text
C:\miners\KeryxMiner\models\DeepSeek-R1-8B\model.gguf
```

O modelo e carregado antes do minerador para evitar que o Keryx falhe no probe do backend externo.

## Router v9

O router v9 resolve os problemas encontrados durante os testes Windows:

- HTTP 400 no `/v1/chat/completions` para alguns modelos GGUF custom;
- resposta do modelo R1 com `reasoning` ou formato sem `content`;
- Keryx recusando backend quando nao encontra `choices[0].message.content` ou `choices[0].text`;
- necessidade de fallback para 32B remoto quando o 8B local falha.

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

Logs esperados no router:

```text
Keryx Ollama Router PowerShell v9
Modo robusto: normaliza toda resposta para choices[0].message.content
Modelo pedido: keryx8b-win -> LOCAL Windows / keryx8b-win
Modelo pedido: keryx32b -> REMOTE .110 / keryx32b
```

## Release Windows

Use o script abaixo no Windows para empacotar uma release local:

```powershell
cd <repo>\windows
powershell -ExecutionPolicy Bypass -File .\package-windows-release.ps1
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
