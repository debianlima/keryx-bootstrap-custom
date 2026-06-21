# Configuração do Flight Sheet no HiveOS

Use esta página para configurar o Keryx como **Custom Miner** sem executar comandos manuais no rig.

## URL da Release

Página visual da release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta do pacote `.tar.gz` para o HiveOS:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v14-forcado.tar.gz
```

## Campos do Custom Miner

```text
Miner: Custom

Miner name:
keryx-miner

Installation URL:
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v14-forcado.tar.gz

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

## Observação importante

O campo **Installation URL** precisa receber a URL direta do arquivo:

```text
/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v14-forcado.tar.gz
```

Não use a URL da página da release:

```text
/releases/tag/bootstrap
```

## Depois de aplicar o Flight Sheet

```bash
miner stop
sleep 3
screen -wipe
miner start
```

A inicialização deve ocorrer pelo caminho real do HiveOS:

```text
miner start -> miner-run custom 3 -> h-config.sh -> miner_config_gen -> h-run.sh
```
