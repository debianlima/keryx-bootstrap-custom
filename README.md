# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como **Custom Miner**, direto pelo `miner start`/Flight Sheet, sem precisar digitar `h-run.sh` manualmente.

## Status atual

Versão corrigida e confirmada no rig: **v14-forçado**.

A correção principal da v14 é compatibilidade com o caminho real usado pelo HiveOS 0.6-229:

```text
miner start
  -> screen miner
  -> miner-run custom 3
  -> /hive/miners/custom/h-manifest.conf
  -> /hive/miners/custom/h-config.sh
  -> miner_ver
  -> miner_config_gen
  -> /hive/miners/custom/h-run.sh
```

Antes o Keryx funcionava manualmente porque o usuário digitava `h-run.sh`, mas o automático morria antes de chegar no `h-run.sh`, pois o `h-config.sh` não definia as funções esperadas pelo `miner-run`.

Agora o `h-config.sh` define:

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

O instalador:

1. para o miner atual;
2. faz backup dos arquivos atuais de `/hive/miners/custom`;
3. baixa os scripts corrigidos do projeto;
4. aplica permissões;
5. inicia automaticamente com `miner start`;
6. mostra processos, log e screens.

## Caminho correto no HiveOS testado

Os callbacks precisam ficar diretamente em:

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

Depois de instalar, o teste correto não é digitar `h-run.sh`; é chamar o mesmo caminho do HiveOS:

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

Fluxo normal:

```bash
miner stop
sleep 3
screen -wipe
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
h-config.sh           -> define miner_ver/miner_fork/miner_config_gen e gera config.ini
h-run.sh              -> inicia bootstrap/modelos/binário real
h-stats.sh            -> stats mínimos para o HiveOS
keryx-bootstrap.sh    -> baixa o pacote real Keryx-Labs/keryx-miner v0.3.2-OPoI
keryx-miner           -> wrapper que redireciona para h-run.sh
```
