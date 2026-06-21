# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner.

## Status atual

Versao atual: v24-no-hconfig-defaults.

Mudancas principais:

- O h-config.sh nao usa mais pool, wallet nem extra args padrao.
- O comando do minerador vem somente do Flight Sheet/API do HiveOS.
- CUSTOM_URL vira -s.
- CUSTOM_TEMPLATE vira --mining-address.
- CUSTOM_USER_CONFIG vira argumentos extras.
- Se Extra config estiver vazio, o script nao adiciona --light automaticamente.
- Para usar light, coloque --light no Extra config arguments.
- Mantem o modo Docker para kernel inferior a 6.6 e o aviso ao usuario.
- Mantem h-stats no padrao HiveOS com hs_units khs.

## Versao do minerador original

O bootstrap nao baixa automaticamente a ultima release do Keryx-Labs/keryx-miner.

Por padrao, ele baixa sempre a versao original fixada no keryx-bootstrap.sh:

```text
KERYX_REPO=Keryx-Labs/keryx-miner
KERYX_TAG=v0.3.2-OPoI
```

Isso foi feito de proposito para evitar que uma release nova do minerador original quebre o Custom Miner do HiveOS sem teste.

Para trocar a versao original manualmente, use variaveis de ambiente antes do bootstrap:

```bash
export KERYX_TAG="v0.3.3-EXEMPLO"
```

Ou force uma URL exata do pacote original:

```bash
export KERYX_PACKAGE_URL="https://github.com/Keryx-Labs/keryx-miner/releases/download/ALGUMA-VERSAO/arquivo.tar.gz"
```

Se nenhuma dessas variaveis for definida, sera usada a versao v0.3.2-OPoI.

## Destaque: modo de compatibilidade HiveOS kernel 6.1.0

Este pacote tem modo de compatibilidade para rigs HiveOS antigas, principalmente rigs com kernel 6.1.0-hiveos.

Quando o kernel for inferior a 6.6, o h-run.sh muda automaticamente para execucao em container Ubuntu 22.04. Isso evita erro de biblioteca/GLIBC em imagens antigas do HiveOS sem obrigar troca imediata da imagem do sistema.

O que acontece automaticamente no modo compatibilidade:

- envia aviso ao usuario recomendando atualizar o HiveOS/kernel;
- informa que o Keryx vai rodar em container Ubuntu 22.04;
- tenta instalar wget e ca-certificates no host;
- tenta instalar e iniciar Docker se necessario;
- cria a imagem local keryx-hiveos-ubuntu22:22.04;
- monta /hive/miners/custom dentro do container como /miners;
- mantem a execucao dentro da screen padrao do HiveOS;
- mantem o log em /var/log/miner/keryx-miner.log;
- mantem o h-stats.sh alimentando a API de monitoramento do HiveOS.

Resumo:

```text
Kernel 6.6 ou superior  -> roda nativo no HiveOS
Kernel inferior a 6.6   -> roda em container Ubuntu 22.04
Kernel 6.1.0-hiveos    -> modo compatibilidade ativado automaticamente
```

Dependencias instaladas no host quando necessario:

```bash
apt-get update
apt-get install -y wget ca-certificates
```

Observacao: o modo Docker precisa que o Docker consiga acessar as GPUs com --gpus all. Se o runtime NVIDIA do Docker nao estiver disponivel, o erro aparece no log e o loop do minerador continua tentando.

## Release

URL direta esperada do asset v24:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v24-no-hconfig-defaults.tar.gz
```

## Flight Sheet

```text
Miner: Custom
Miner name: keryx-bootstrap-custom-hiveos-v24
Installation URL: https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v24-no-hconfig-defaults.tar.gz
Hash algorithm: blake3-alph
Pool URL: stratum+tcp://krx.baikalmine.com:9020
Pass: vazio
Extra config arguments: --light
```

Coloque sua wallet no campo Wallet and worker template.

## Instalacao manual de recuperacao

Use este comando quando o minerador nao iniciar, quando o HiveOS nao criar a pasta `/hive/miners/custom`, ou quando a pasta `custom` tiver sido apagada:

```bash
miner stop 2>/dev/null || true
sleep 3
screen -wipe || true

URL="https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v24-no-hconfig-defaults.tar.gz"
TMP="/tmp/keryx-custom-manual"
PKG="/tmp/keryx-custom.tar.gz"

rm -rf "$TMP"
mkdir -p "$TMP" /hive/miners/custom

wget -O "$PKG" "$URL" || exit 1
gzip -t "$PKG" || exit 1
tar -xzf "$PKG" -C "$TMP" || exit 1

if [ -f "$TMP/h-manifest.conf" ]; then
  cp -af "$TMP/." /hive/miners/custom/
elif [ -f "$TMP/custom/h-manifest.conf" ]; then
  cp -af "$TMP/custom/." /hive/miners/custom/
else
  echo "ERRO: pacote baixado, mas h-manifest.conf nao foi encontrado"
  find "$TMP" -maxdepth 3 -type f | sort
  exit 1
fi

chmod 755 /hive/miners/custom/h-run \
          /hive/miners/custom/h-run.sh \
          /hive/miners/custom/h-config.sh \
          /hive/miners/custom/h-stats.sh \
          /hive/miners/custom/keryx-bootstrap.sh \
          /hive/miners/custom/keryx-miner 2>/dev/null || true

[ -f /hive/miners/custom/keryx-miner.bin ] && chmod 755 /hive/miners/custom/keryx-miner.bin

ls -la /hive/miners/custom
miner start
```

## Hotfix rapido

```bash
miner stop 2>/dev/null || true
sleep 3
screen -wipe || true
wget -qO /hive/miners/custom/h-config.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-config.sh
chmod 755 /hive/miners/custom/h-config.sh
miner start
```

## Conferencia

```bash
cat /hive/miners/custom/config.ini
/hive/miners/custom/h-stats.sh
```
