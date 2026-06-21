# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner.

## Status atual

Versao atual: v23-old-kernel-docker-notice.

Mudancas principais:

1. Kernel inferior a 6.6 agora ativa o modo Docker. Kernel 6.6 ou superior roda nativo.

2. Quando detectar kernel antigo, o script tenta enviar uma mensagem ao usuario avisando para atualizar o HiveOS/kernel e informando que o Keryx vai rodar em container Ubuntu 22.04.

3. Antes do modo Docker, o script tenta instalar as dependencias base no host:

```bash
apt-get update
apt-get install -y wget ca-certificates
```

4. Se Docker nao existir, ele tenta instalar docker.io. A imagem local do container tambem instala wget e ca-certificates no Ubuntu 22.04.

5. O container roda na mesma screen padrao do HiveOS, usa a pasta /hive/miners/custom montada em /miners, grava no mesmo log e o h-stats.sh continua alimentando a API do HiveOS.

## Release

URL direta esperada do asset v23:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v23-old-kernel-docker-notice.tar.gz
```

## Flight Sheet

```text
Miner: Custom
Miner name: keryx-bootstrap-custom-hiveos-v23
Installation URL: https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v23-old-kernel-docker-notice.tar.gz
Hash algorithm: blake3-alph
Pool URL: stratum+tcp://krx.baikalmine.com:9020
Pass: vazio
Extra config arguments: vazio ou --no-fast-models
```

Coloque sua wallet no campo Wallet and worker template do HiveOS.

## Hotfix rapido no rig ja instalado

```bash
miner stop 2>/dev/null || true
sleep 3
screen -wipe || true

wget -qO /hive/miners/custom/h-run.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-run.sh
wget -qO /hive/miners/custom/h-stats.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-stats.sh
chmod 755 /hive/miners/custom/h-run.sh /hive/miners/custom/h-stats.sh

miner start
```

## Conferencia

```bash
cat /hive/miners/custom/config.ini
grep -Ei "AVISO|Kernel|Docker|apt-get|Current hashrate|Device #|config:" /var/log/miner/keryx-miner.log | tail -120
/hive/miners/custom/h-stats.sh
```
