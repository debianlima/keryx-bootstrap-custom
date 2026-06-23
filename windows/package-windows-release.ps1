param(
  [string]$KeryxDir = "C:\miners\KeryxMiner",
  [string]$ServicePackDir = "C:\miners\miner_service_pack",
  [string]$CudaPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6",
  [string]$Version = "v0.3.2-opoi-windows-krx-v10-ctx64k",
  [string]$OutDir = ".\dist"
)

$ErrorActionPreference = "Stop"

function Require-File($Path) {
  if (!(Test-Path $Path)) {
    throw "Arquivo obrigatorio nao encontrado: $Path"
  }
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$stage = Join-Path $OutDir "keryx-windows-$Version"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path "$stage\KeryxMiner" -Force | Out-Null
New-Item -ItemType Directory -Path "$stage\miner_service_pack" -Force | Out-Null

$required = @(
  "$KeryxDir\keryx-miner.exe",
  "$KeryxDir\keryxcuda.dll",
  "$KeryxDir\escrow.key",
  "$CudaPath\bin\cudart64_12.dll",
  "$CudaPath\bin\cublas64_12.dll",
  "$CudaPath\bin\cublasLt64_12.dll",
  "$CudaPath\bin\curand64_10.dll"
)

foreach ($f in $required) { Require-File $f }

Copy-Item "$KeryxDir\keryx-miner.exe" "$stage\KeryxMiner\" -Force
Copy-Item "$KeryxDir\keryxcuda.dll" "$stage\KeryxMiner\" -Force
Copy-Item "$KeryxDir\escrow.key" "$stage\KeryxMiner\" -Force
Copy-Item "$CudaPath\bin\cudart64_12.dll" "$stage\KeryxMiner\" -Force
Copy-Item "$CudaPath\bin\cublas64_12.dll" "$stage\KeryxMiner\" -Force
Copy-Item "$CudaPath\bin\cublasLt64_12.dll" "$stage\KeryxMiner\" -Force
Copy-Item "$CudaPath\bin\curand64_10.dll" "$stage\KeryxMiner\" -Force

if (Test-Path "$KeryxDir\models") {
  New-Item -ItemType Directory -Path "$stage\KeryxMiner\models" -Force | Out-Null
  Copy-Item "$KeryxDir\models\*" "$stage\KeryxMiner\models\" -Recurse -Force
}

Copy-Item "$ServicePackDir\*" "$stage\miner_service_pack\" -Recurse -Force

@"
Keryx Windows KRX/Ollama $Version

Instalacao esperada:
1. Copie KeryxMiner para C:\miners\KeryxMiner
2. Copie miner_service_pack para C:\miners\miner_service_pack
3. Abra: C:\miners\miner_service_pack\MinerTray.ps1
4. Use: Iniciar Mineracao com Telas

Roteamento:
- tinyllama/deepseek-r1-8b -> keryx8b-win local com contexto 65536
- deepseek-r1-32b -> keryx32b remoto 172.16.0.110:11434

Observacao:
O service pack v10 recria o keryx8b-win com PARAMETER num_ctx 65536 para aproveitar melhor a RTX 3060 12 GB.
"@ | Set-Content -Encoding UTF8 "$stage\README-WINDOWS-RELEASE.txt"

$zip = Join-Path $OutDir "keryx-windows-$Version.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$stage\*" -DestinationPath $zip -Force

Write-Host "Release Windows criada:" -ForegroundColor Green
Write-Host $zip
