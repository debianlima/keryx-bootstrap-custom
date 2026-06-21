# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como **Custom Miner**, direto pelo `miner start`/Flight Sheet, sem precisar digitar `h-run.sh` manualmente.

## Status atual

Versão corrigida dos scripts: **v14**.

A correção principal da v14 é compatibilidade com o `miner-run custom 3` do HiveOS 0.6-229:

```text
/hive/bin/miner-run custom 3
  -> procura arquivos em /hive/miners/custom
  -> faz source h-manifest.conf
  -> faz source h-config.sh
  -> chama miner_ver
  -> chama miner_config_gen
  -> depois faz source h-run.sh
```

Antes o `h-config.sh` apenas gerava o `config.ini` quando executado manualmente. Agora ele também define as funções obrigatórias do HiveOS:

```bash
miner_ver()        # retorna vazio para o HiveOS nao tentar instalar pacote apt hive-miners-custom-versao
miner_fork()       # retorna vazio
miner_config_gen() # gera config.ini a partir do Flight Sheet/defaults
```

## Instalação rápida no rig

Use este comando no HiveOS:

```bash
sudo -i
wget -qO /tmp/install-keryx-v14.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/install-v14-flat-raw.sh
bash /tmp/install-keryx-v14.sh
```

Esse instalador coloca os callbacks diretamente em:

```text
/hive/miners/custom/
```

porque, no rig testado, o HiveOS chama o miner como `MINER_NAME=custom` e o `miner-run` procura:

```text
/hive/miners/custom/h-manifest.conf
/hive/miners/custom/h-config.sh
/hive/miners/custom/h-run.sh
```

## Configuração do Flight Sheet

No Flight Sheet do HiveOS:

```text
Miner: Custom

Miner name:
keryx-miner

Hash algorithm:
blake3-alph

Wallet and worker template:
keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa

Pool URL:
stratum+tcp://krx.baikalmine.com:9020

Pass:
deixe vazio

Extra config arguments:
deixe vazio ou --no-fast-models
```

Mesmo se `Extra config arguments` tiver apenas `--no-fast-models`, a v14 mantém `--light` por padrão para placas de 8 GB.

## Teste direto

Depois de instalar:

```bash
miner stop
sleep 3
screen -wipe
: > /var/log/miner/keryx-miner.log
miner-run custom 3
```

Resultado esperado:

```text
Miner:   custom
[KERYX-HIVEOS] h-run.sh chamado pelo HiveOS em /hive/miners/custom
[KERYX-HIVEOS] gerando config.ini a partir do Flight Sheet/defaults
[KERYX-HIVEOS] iniciando keryx-miner.bin
```

Depois rode pelo fluxo normal:

```bash
miner stop
sleep 3
miner start
sleep 8
tail -120 /var/log/miner/keryx-miner.log
```

## Logs

```text
/var/log/miner/keryx-miner.log
/var/log/miner/keryx-miner.diag.log
```

## Arquivos principais

```text
h-manifest.conf       -> manifest dinâmico, usa a pasta onde foi instalado
h-config.sh           -> define miner_ver/miner_config_gen e gera config.ini
h-run.sh              -> inicia bootstrap/modelos/binário real
h-stats.sh            -> stats mínimos para o HiveOS
keryx-bootstrap.sh    -> baixa o pacote real Keryx-Labs/keryx-miner v0.3.2-OPoI
keryx-miner           -> wrapper que redireciona para h-run.sh
```
