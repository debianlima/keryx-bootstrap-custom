# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner.

## Status atual

Versão atual: **v22-docker-kernel-fallback**.

Mudanças principais:

1. `h-run.sh` agora detecta kernel inferior a `6.6.0-hiveos #60`. Quando detectar kernel antigo, ele tenta rodar o minerador dentro de container Ubuntu 22.04 usando Docker, mantendo a execução dentro da screen padrão do HiveOS.

2. O modo Docker usa a mesma pasta `/hive/miners/custom` montada em `/miners`, então o log continua saindo em `/var/log/miner/keryx-miner.log` e o `h-stats.sh` continua enviando dados para a API de monitoramento do HiveOS.

3. `h-stats.sh` foi alinhado ao formato padrão do HiveOS: lê `Current hashrate is`, lê `Device #N`, converte para `khs` e monta `hs` por GPU ativa.

## Release

Página visual:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta esperada do asset v22:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v22-docker-kernel-fallback.tar.gz
```

## Flight Sheet

```text
Miner: Custom
Miner name: keryx-bootstrap-custom-hiveos-v22
Installation URL: https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v22-docker-kernel-fallback.tar.gz
Hash algorithm: blake3-alph
Pool URL: stratum+tcp://krx.baikalmine.com:9020
Pass: vazio
Extra config arguments: vazio ou --no-fast-models
```

Coloque sua wallet no campo **Wallet and worker template** do HiveOS.

## Observação sobre Docker

O fallback Docker precisa que o Docker consiga usar GPU com `--gpus all`. Se o rig não tiver runtime NVIDIA para Docker, o log vai mostrar o erro e o minerador vai tentar de novo no loop padrão.

Para forçar Docker mesmo em kernel novo, coloque no ambiente:

```bash
export KERYX_FORCE_DOCKER=1
```

## Hotfix rápido no rig já instalado

```bash
miner stop 2>/dev/null || true
sleep 3
screen -wipe || true

wget -qO /hive/miners/custom/h-run.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-run.sh
wget -qO /hive/miners/custom/h-stats.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-stats.sh
chmod 755 /hive/miners/custom/h-run.sh /hive/miners/custom/h-stats.sh

miner start
```

## Conferência

```bash
cat /hive/miners/custom/config.ini
grep -Ei "Kernel|Docker|Current hashrate|Device #|config:" /var/log/miner/keryx-miner.log | tail -80
/hive/miners/custom/h-stats.sh
```
