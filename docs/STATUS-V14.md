# Status v14

A correção confirmada no rig foi aplicada nos scripts principais do projeto.

## Release correta

Página da release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta para usar no campo **Custom Miner Install URL / Installation URL** do HiveOS:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v14-forcado.tar.gz
```

Use a URL `/releases/download/...tar.gz` no HiveOS. A URL `/releases/tag/bootstrap` é apenas a página visual da release.

## Correção confirmada

O ponto crítico é o `h-config.sh`: ele agora define `miner_ver`, `miner_fork` e `miner_config_gen`, que são chamadas pelo `miner-run custom 3` antes do `h-run.sh`.

## Flight Sheet

```text
Miner: Custom
Miner name: keryx-miner
Installation URL: https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v14-forcado.tar.gz
Hash algorithm: blake3-alph
Wallet and worker template: keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa
Pool URL: stratum+tcp://krx.baikalmine.com:9020
Pass: vazio
Extra config arguments: vazio ou --no-fast-models
```

## Instalador alternativo para debug

No HiveOS normalmente você já está como `root`, então não use `sudo -i` dentro do bloco. O `sudo -i` abre outro shell interativo e pode impedir que as próximas linhas sejam executadas.

```bash
wget -qO /tmp/install-keryx-v14.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/install-v14-flat-raw.sh
bash /tmp/install-keryx-v14.sh
```
