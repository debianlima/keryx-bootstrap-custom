# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como **Custom Miner**, direto pelo `miner start`/Flight Sheet, sem precisar digitar `h-run.sh` manualmente.

## Status atual

Versão atual documentada: **v19-flightsheet-ghs**.

A v19 faz duas correções:

1. `h-run.sh` e `h-config.sh` agora leem diretamente o Flight Sheet local do HiveOS:

```text
/hive-config/rig.conf
/hive-config/wallet.conf
```

Assim o wrapper não depende apenas das variáveis que o `miner-run` exporta. Mesmo chamado diretamente, ele lê `CUSTOM_URL`, `CUSTOM_TEMPLATE`, `CUSTOM_USER_CONFIG`, `CUSTOM_ALGO`, `CUSTOM_PASS`, `CUSTOM_TLS` e `CUSTOM_INSTALL_URL` do HiveOS.

2. `h-stats.sh` foi ajustado para reportar hashrate em **GH/s** quando o minerador imprimir `GH/s`, `GHash/s`, `MH/s`, `TH/s`, etc. O falso fallback de `1.000 kH` fica apenas como sinal de atividade durante bootstrap/download/prefetch, não como hashrate real.

## Release correta

Página visual da Release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta esperada do novo asset v19 para colocar no **Custom Miner Install URL / Installation URL** do HiveOS:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v19-flightsheet-ghs.tar.gz
```

SHA256 do pacote v19:

```text
7e9f76150c76d8665b24dfece630837f709b1c813b9fd9c4419761d9236fc85d
```

Importante: no HiveOS, use a URL `/releases/download/...tar.gz`, não a página `/releases/tag/...`.

## Parâmetros lidos do Flight Sheet

O comando final do binário real é montado assim:

```text
CUSTOM_URL       -> -s <pool>
CUSTOM_TEMPLATE  -> --mining-address <wallet>
CUSTOM_USER_CONFIG -> argumentos extras, mantendo --light por padrão se vazio
CUSTOM_ALGO      -> usado no h-stats.sh para reportar o algoritmo
```

Exemplo:

```bash
/hive/miners/custom/keryx-miner.bin \
  -s stratum+tcp://krx.baikalmine.com:9020 \
  --mining-address keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa \
  --light
```

## Configuração do Flight Sheet

No Flight Sheet do HiveOS:

```text
Miner: Custom

Miner name:
keryx-bootstrap-custom-hiveos-v19

Installation URL:
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v19-flightsheet-ghs.tar.gz

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

Se o rig já está com os arquivos instalados e você quer aplicar só a leitura direta do Flight Sheet e o ajuste GH/s:

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

Para conferir o comando final:

```bash
cat /hive/miners/custom/config.ini
grep -i "config:" /var/log/miner/keryx-miner.log | tail -5
```

Para conferir o stats:

```bash
/hive/miners/custom/h-stats.sh
```

## Arquivos principais

```text
h-manifest.conf       -> manifest dinâmico, usa a pasta onde foi instalado
h-config.sh           -> lê Flight Sheet e gera config.ini
h-run.sh              -> lê Flight Sheet, inicia bootstrap/modelos/binário real
h-stats.sh            -> lê Flight Sheet e reporta GH/s quando o log tiver GH/s/GHash/s
keryx-bootstrap.sh    -> baixa o pacote real Keryx-Labs/keryx-miner v0.3.2-OPoI
keryx-miner           -> wrapper que redireciona para h-run.sh
scripts/patch-hiveos-miner-run-auto-install.sh -> corrige auto-instalação quando /hive/miners/custom some
```
