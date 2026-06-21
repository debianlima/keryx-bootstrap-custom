# Status v16 auto-install

A correção confirmada no rig foi aplicada nos scripts principais do projeto e agora existe também um patch opcional para corrigir a auto-instalação do Custom Miner no HiveOS.

## Release correta

Página da release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta para usar no campo **Custom Miner Install URL / Installation URL** do HiveOS:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz
```

Use a URL `/releases/download/...tar.gz` no HiveOS. A URL `/releases/tag/bootstrap` é apenas a página visual da release.

## Correção confirmada do minerador

O ponto crítico é o `h-config.sh`: ele define `miner_ver`, `miner_fork` e `miner_config_gen`, que são chamadas pelo `miner-run custom` antes do `h-run.sh`.

## Correção confirmada da auto-instalação

Em alguns rigs o HiveOS não recria `/hive/miners/custom` automaticamente, mesmo com `CUSTOM_INSTALL_URL` correto. Para corrigir isso, aplique uma vez:

```bash
wget -qO /tmp/patch-keryx-auto-install.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/patch-hiveos-miner-run-auto-install.sh
bash /tmp/patch-keryx-auto-install.sh
```

Esse patch cria backup do original em:

```text
/hive/bin/miner-run.hiveos-original
```

e grava log em:

```text
/var/log/miner/keryx-auto-install.log
```

## Flight Sheet

```text
Miner: Custom
Miner name: keryx-bootstrap-custom-hiveos-v16
Installation URL: https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz
Hash algorithm: blake3-alph
Wallet and worker template: keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa
Pool URL: stratum+tcp://krx.baikalmine.com:9020
Pass: vazio
Extra config arguments: vazio ou --no-fast-models
```

## Instalador alternativo para debug

```bash
wget -qO /tmp/install-keryx-v14.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/install-v14-flat-raw.sh
bash /tmp/install-keryx-v14.sh
```
