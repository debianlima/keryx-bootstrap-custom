# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como **Custom Miner**, direto pelo `miner start`/Flight Sheet, sem precisar digitar `h-run.sh` manualmente.

## Status atual

Versão atual documentada: **v18-bootstrapfix**.

A v18 corrige o erro do bootstrap ao baixar o pacote real do Keryx. O pacote oficial baixado é `.tar.gz`, mas o script antigo usava `file ... | grep zip`; como a palavra `gzip` contém `zip`, ele tentava abrir `.tar.gz` com `unzip`, causando:

```text
End-of-central-directory signature not found
unzip: cannot find zipfile directory
```

Agora o `keryx-bootstrap.sh` testa `gzip -t` primeiro, extrai com `tar -xzf`, e só depois tenta ZIP.

## Release correta

Página visual da Release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta esperada do novo asset v18 para colocar no **Custom Miner Install URL / Installation URL** do HiveOS:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v18-bootstrapfix.tar.gz
```

SHA256 do pacote v18:

```text
124a91e30ea7bc4dcac6421ba90cb6030edb1a1a42aea8a862f4aa2812362258
```

Importante: no HiveOS, use a URL `/releases/download/...tar.gz`, não a página `/releases/tag/...`.

## Correções mantidas

A v18 mantém as correções anteriores:

- `h-config.sh` define `miner_ver`, `miner_fork` e `miner_config_gen`;
- `h-run.sh` gera a config e inicia `keryx-miner.bin`;
- `keryx-miner` é wrapper para `h-run.sh`;
- `scripts/patch-hiveos-miner-run-auto-install.sh` corrige rigs onde o HiveOS não recria `/hive/miners/custom` automaticamente.

## Configuração do Flight Sheet

No Flight Sheet do HiveOS:

```text
Miner: Custom

Miner name:
keryx-bootstrap-custom-hiveos-v18

Installation URL:
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v18-bootstrapfix.tar.gz

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

## Hotfix rápido sem trocar Release

Se o rig já está com os arquivos instalados mas falha no bootstrap com erro de `unzip`, atualize só o `keryx-bootstrap.sh`:

```bash
miner stop 2>/dev/null || true
sleep 3
wget -qO /hive/miners/custom/keryx-bootstrap.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/keryx-bootstrap.sh
chmod 755 /hive/miners/custom/keryx-bootstrap.sh
miner start
```

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
