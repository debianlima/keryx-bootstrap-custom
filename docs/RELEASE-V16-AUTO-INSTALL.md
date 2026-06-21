# Release v16-auto-install

Esta release consolida duas correções:

1. Scripts do Custom Miner funcionando no fluxo real do HiveOS:

```text
miner start -> miner-run custom -> h-config.sh -> miner_config_gen -> h-run.sh
```

2. Patch opcional para rigs onde o HiveOS não recria `/hive/miners/custom` automaticamente mesmo com `CUSTOM_INSTALL_URL` correto.

## Asset da release

Nome do arquivo:

```text
keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz
```

SHA256 do pacote gerado:

```text
6563de494f3cf7d899db40c9d0496c3e82d8d2d7cc32257687173bd6375130ff
```

URL esperada após anexar o asset na release `bootstrap`:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz
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

## Patch de auto-instalação

Aplicar uma vez no rig, caso o HiveOS não baixe a Release automaticamente quando `/hive/miners/custom` não existe:

```bash
wget -qO /tmp/patch-keryx-auto-install.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/patch-hiveos-miner-run-auto-install.sh
bash /tmp/patch-keryx-auto-install.sh
```

O patch cria backup em:

```text
/hive/bin/miner-run.hiveos-original
```

Log:

```text
/var/log/miner/keryx-auto-install.log
```
