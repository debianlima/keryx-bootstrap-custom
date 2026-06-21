# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como **Custom Miner**, direto pelo `miner start`/Flight Sheet, sem precisar digitar `h-run.sh` manualmente.

## Status atual

Versão atual documentada: **v16-auto-install**.

O pacote do Custom Miner continua sendo usado no campo **Installation URL** do HiveOS. A correção nova da v16 adiciona também um patch opcional para o `/hive/bin/miner-run`, porque em alguns rigs o HiveOS não baixa a Release automaticamente quando a pasta `/hive/miners/custom` foi apagada.

## Release correta

Página visual da Release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta esperada do novo asset v16 para colocar no **Custom Miner Install URL / Installation URL** do HiveOS:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz
```

Importante: no HiveOS, use a URL `/releases/download/...tar.gz`, não a página `/releases/tag/...`.

## Problema confirmado no HiveOS

O `CUSTOM_INSTALL_URL` estava correto e a Release respondia `HTTP/1.1 200 OK`, mas o HiveOS não recriava `/hive/miners/custom` automaticamente depois da pasta ser removida.

O fluxo real observado foi:

```text
miner start
  -> screen miner
  -> miner-run custom 2
  -> espera existir /hive/miners/custom/h-manifest.conf
  -> espera existir /hive/miners/custom/h-config.sh
  -> espera existir /hive/miners/custom/h-run.sh
```

Ou seja: quando a pasta `custom` já existe, funciona. Quando ela foi apagada, alguns rigs não disparam o download do `CUSTOM_INSTALL_URL` sozinhos.

## Correção v16

A v16 mantém os scripts funcionais do minerador e adiciona:

```text
scripts/patch-hiveos-miner-run-auto-install.sh
```

Esse patch cria um wrapper em `/hive/bin/miner-run`. Quando o HiveOS chamar `miner-run custom`, o wrapper verifica se `/hive/miners/custom` está ausente/incompleto. Se estiver, ele baixa o pacote definido em `CUSTOM_INSTALL_URL`, extrai em `/hive/miners/custom` e depois chama o `miner-run` original.

Backup criado pelo patch:

```text
/hive/bin/miner-run.hiveos-original
```

Log do auto-install:

```text
/var/log/miner/keryx-auto-install.log
```

## Configuração do Flight Sheet

No Flight Sheet do HiveOS:

```text
Miner: Custom

Miner name:
keryx-bootstrap-custom-hiveos-v16

Installation URL:
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz

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

## Aplicar o patch de auto-instalação uma vez no rig

Este passo corrige o comportamento do HiveOS quando ele não recria `/hive/miners/custom` sozinho:

```bash
wget -qO /tmp/patch-keryx-auto-install.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/patch-hiveos-miner-run-auto-install.sh
bash /tmp/patch-keryx-auto-install.sh
```

Depois disso, mesmo se `/hive/miners/custom` for removida, o próximo `miner start` deve baixar a Release definida em `CUSTOM_INSTALL_URL` e recriar a pasta.

## Teste do zero

```bash
miner stop 2>/dev/null || true
sleep 3
screen -wipe || true

rm -rf /hive/miners/custom

miner start
sleep 10

ls -la /hive/miners/custom
cat /var/log/miner/keryx-auto-install.log 2>/dev/null || true
tail -120 /var/log/miner/keryx-miner.log 2>/dev/null || true
```

## Instalador alternativo para debug

Use apenas se quiser reinstalar manualmente os arquivos sem depender do pacote `.tar.gz`:

```bash
wget -qO /tmp/install-keryx-v14.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/install-v14-flat-raw.sh
bash /tmp/install-keryx-v14.sh
```

## Arquivos principais

```text
h-manifest.conf       -> manifest dinâmico, usa a pasta onde foi instalado
h-config.sh           -> define miner_ver/miner_fork/miner_config_gen e gera config.ini
h-run.sh              -> inicia bootstrap/modelos/binário real
h-stats.sh            -> stats mínimos para o HiveOS
keryx-bootstrap.sh    -> baixa o pacote real Keryx-Labs/keryx-miner v0.3.2-OPoI
keryx-miner           -> wrapper que redireciona para h-run.sh
scripts/patch-hiveos-miner-run-auto-install.sh -> corrige auto-instalação quando /hive/miners/custom some
```
