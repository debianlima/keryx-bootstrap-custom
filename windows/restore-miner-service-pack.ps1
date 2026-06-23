param(
  [string]$Base64File = ".\miner_service_pack_original_krx_ollama_wait_v9.zip.b64",
  [string]$OutZip = ".\miner_service_pack_original_krx_ollama_wait_v9.zip",
  [string]$InstallRoot = "C:\miners"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $Base64File)) {
  throw "Arquivo base64 nao encontrado: $Base64File"
}

$b64 = (Get-Content $Base64File -Raw) -replace "\s", ""
[IO.File]::WriteAllBytes((Resolve-Path .).Path + "\" + $OutZip, [Convert]::FromBase64String($b64))

Write-Host "ZIP restaurado: $OutZip" -ForegroundColor Green

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
Expand-Archive $OutZip -DestinationPath $InstallRoot -Force

Write-Host "Instalado em: $InstallRoot\miner_service_pack" -ForegroundColor Green
Write-Host "Inicie com:" -ForegroundColor Cyan
Write-Host "cd $InstallRoot\miner_service_pack"
Write-Host "powershell -ExecutionPolicy Bypass -File .\MinerTray.ps1"
