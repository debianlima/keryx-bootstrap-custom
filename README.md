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
