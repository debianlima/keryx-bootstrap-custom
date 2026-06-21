# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner.

## Status atual

Versão atual: **v19-flightsheet-ghs**.

A v19 corrige dois pontos:

1. `h-run.sh` e `h-config.sh` leem diretamente o Flight Sheet local do HiveOS:

```text
/hive-config/rig.conf
/hive-config/wallet.conf
```

Com isso, mesmo quando o wrapper é chamado fora do `miner-run`, ele lê `CUSTOM_URL`, `CUSTOM_TEMPLATE`, `CUSTOM_USER_CONFIG`, `CUSTOM_ALGO`, `CUSTOM_PASS`, `CUSTOM_TLS` e `CUSTOM_INSTALL_URL` direto do HiveOS.

2. `h-stats.sh` agora tenta reportar o hashrate real em **GH/s** quando o log do minerador mostrar unidades como `GH/s`, `GHash/s`, `MH/s` ou `TH/s`. O fallback de `1 kH` fica apenas como sinal de atividade durante bootstrap/download/prefetch.

## Release

Página visual:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta esperada do asset v19:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v19-flightsheet-ghs.tar.gz
```

SHA256 do pacote v19:

```text
d217f59608367bf467c72f714772f94a4791530767fe56746bcf2a4644dfb423
```

## Flight Sheet

```text
Miner: Custom
Miner name: keryx-bootstrap-custom-hiveos-v19
Installation URL: https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v19-flightsheet-ghs.tar.gz
Hash algorithm: blake3-alph
Pool URL: stratum+tcp://krx.baikalmine.com:9020
Pass: vazio
Extra config arguments: vazio ou --no-fast-models
```

Coloque sua wallet no campo **Wallet and worker template** do HiveOS.

## Patch de auto-instalação

Use uma vez no rig quando o HiveOS não recriar `/hive/miners/custom` sozinho:

```bash
wget -qO /tmp/patch-keryx-auto-install.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/patch-hiveos-miner-run-auto-install.sh
bash /tmp/patch-keryx-auto-install.sh
```

## Hotfix rápido no rig já instalado

```bash
miner stop 2>/dev/null || true
sleep 3
screen -wipe || true

wget -qO /hive/miners/custom/h-config.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-config.sh
wget -qO /hive/miners/custom/h-run.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-run.sh
wget -qO /hive/miners/custom/h-stats.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-stats.sh
wget -qO /hive/miners/custom/h-manifest.conf https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/h-manifest.conf
chmod 755 /hive/miners/custom/h-config.sh /hive/miners/custom/h-run.sh /hive/miners/custom/h-stats.sh /hive/miners/custom/h-manifest.conf

miner start
```

## Conferência

```bash
cat /hive/miners/custom/config.ini
grep -i "config:" /var/log/miner/keryx-miner.log | tail -5
/hive/miners/custom/h-stats.sh
```
