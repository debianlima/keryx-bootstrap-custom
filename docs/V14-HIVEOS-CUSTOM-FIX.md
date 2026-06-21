# Keryx HiveOS Custom Miner - v14 corrigido

Esta versao documenta a correcao confirmada no rig `rig193C0C`.

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

## Instalador direto

```bash
sudo -i
wget -qO /tmp/install-keryx-v14.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/install-v14-flat-raw.sh
bash /tmp/install-keryx-v14.sh
```

Depois testar:

```bash
miner-run custom 3
```

Depois subir normal:

```bash
miner stop
sleep 3
screen -wipe
miner start
```
