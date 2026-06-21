# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner.

## O que esta versão faz

- Mantém a pasta esperada pelo HiveOS como `keryx-miner`.
- Gera `config.ini` a partir do Flight Sheet: `CUSTOM_URL` vira `-s` e `CUSTOM_TEMPLATE` vira `--mining-address`.
- Usa `--light` por padrão quando o campo User Config está vazio.
- Baixa o pacote real do Keryx na primeira execução, valida o `.tar.gz`, extrai em área temporária e preserva os scripts HiveOS corrigidos.
- Renomeia o binário ELF `keryx-miner` para `keryx-miner.bin` e mantém `keryx-miner` como wrapper.
- Mantém o HiveOS vivo durante bootstrap/download/model/prefetch retornando estatística provisória no `h-stats.sh`.

## URL do pacote real usado pelo bootstrap

Por padrão, o bootstrap baixa:

```bash
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-miner-v032opoi_hiveosv5.tar.gz
```

Para trocar o pacote real sem alterar script, defina no ambiente:

```bash
export KERYX_PACKAGE_URL="https://servidor/arquivo-keryx.tar.gz"
export KERYX_PACKAGE_SHA256="sha256-opcional"
```

## Como testar no HiveOS depois de instalado

```bash
cd /hive/miners/custom/keryx-miner
bash -n h-run.sh h-config.sh h-stats.sh keryx-bootstrap.sh
./h-config.sh
cat config.ini
./h-run.sh
```

Logs:

```bash
tail -f /var/log/miner/keryx-miner.log
```

## Observação importante

Para usar direto no campo **Install URL / Custom URL** do HiveOS, o arquivo precisa ser um `.tar.gz` com a pasta `keryx-miner/` no topo. O pacote gerado para esta versão se chama:

```bash
keryx-bootstrap-custom-hiveos-v6.tar.gz
```

Estrutura esperada:

```text
keryx-miner/
keryx-miner/h-manifest.conf
keryx-miner/h-config.sh
keryx-miner/h-run.sh
keryx-miner/h-run
keryx-miner/h-stats.sh
keryx-miner/keryx-bootstrap.sh
keryx-miner/keryx-miner
```
