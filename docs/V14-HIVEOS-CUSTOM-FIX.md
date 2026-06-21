# Keryx HiveOS Custom Miner - v14 corrigido

Esta versao documenta a correcao confirmada no rig `rig193C0C`.

## URL correta para o HiveOS

Página da release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta do asset para colocar no campo **Custom Miner Install URL / Installation URL**:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v14-forcado.tar.gz
```

No HiveOS, use a URL `/releases/download/...tar.gz`. A URL `/releases/tag/bootstrap` é apenas a página da release no navegador.

## Problema confirmado

O minerador funcionava manualmente quando o usuario digitava `h-run.sh`, mas nao iniciava automaticamente via `miner start`.

O motivo era que o HiveOS chama o caminho real:

```text
miner start -> miner-run custom 3
```

Nesse fluxo, o HiveOS faz `source h-config.sh` e espera encontrar estas funcoes:

```bash
miner_ver
miner_fork
miner_config_gen
```

Sem essas funcoes, o automatico falha antes de chegar no `h-run.sh`.

## Correção aplicada

O `h-config.sh` agora:

- define `miner_ver()` retornando vazio;
- define `miner_fork()` retornando vazio;
- define `miner_config_gen()` gerando `config.ini`;
- mantém `--light` mesmo quando `CUSTOM_USER_CONFIG` tem apenas `--no-fast-models`;
- funciona tanto via `source` pelo HiveOS quanto executado manualmente para debug.

## Caminho de instalação correto

Para esta versao do HiveOS, os arquivos precisam ficar diretamente em:

```text
/hive/miners/custom/
```

Arquivos esperados:

```text
/hive/miners/custom/h-manifest.conf
/hive/miners/custom/h-config.sh
/hive/miners/custom/h-run.sh
/hive/miners/custom/h-run
/hive/miners/custom/h-stats.sh
/hive/miners/custom/keryx-bootstrap.sh
/hive/miners/custom/keryx-miner
```

## Configuração do Flight Sheet

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

## Teste direto

```bash
miner-run custom 3
```

## Fluxo normal

```bash
miner stop
sleep 3
screen -wipe
miner start
```
