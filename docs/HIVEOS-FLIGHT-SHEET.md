# Configuração do Flight Sheet no HiveOS

Use esta página para configurar o Keryx como **Custom Miner**.

## URL da Release

Página visual da release:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/tag/bootstrap
```

URL direta do pacote `.tar.gz` para o HiveOS:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz
```

## Campos do Custom Miner

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

## Observação importante

O campo **Installation URL** precisa receber a URL direta do arquivo:

```text
/releases/download/bootstrap/keryx-bootstrap-custom-hiveos-v16-autoinstall.tar.gz
```

Não use a URL da página da release:

```text
/releases/tag/bootstrap
```

## Patch de auto-instalação

Em alguns rigs, o HiveOS não recria `/hive/miners/custom` sozinho depois que a pasta é apagada. Para corrigir isso, aplique uma vez:

```bash
wget -qO /tmp/patch-keryx-auto-install.sh https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/scripts/patch-hiveos-miner-run-auto-install.sh
bash /tmp/patch-keryx-auto-install.sh
```

Depois disso, ao rodar `miner start`, o wrapper verifica se o custom está ausente e baixa a Release automaticamente usando `CUSTOM_INSTALL_URL`.

## Depois de aplicar o Flight Sheet

```bash
miner stop
sleep 3
screen -wipe
miner start
```

A inicialização deve ocorrer pelo caminho real do HiveOS:

```text
miner start -> miner-run custom -> h-config.sh -> miner_config_gen -> h-run.sh
```
