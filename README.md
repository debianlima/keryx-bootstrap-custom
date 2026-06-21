# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner, direto pelo Flight Sheet, sem comando manual no rig.

## URL para colocar no HiveOS

Use esta URL no campo **Custom Miner Install URL / Custom URL** do Flight Sheet:

```text
https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-latest.tar.gz
```

Também existe a URL versionada:

```text
https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v6.tar.gz
```

SHA256 do pacote v6/latest:

```text
d2b83773190a91a27c6a3af40775ca2cafd38dd0a52d0d12adbbfdb05f89b410
```

## Configuração do Flight Sheet

No Flight Sheet do HiveOS:

- Miner: **Custom**
- Install URL / Custom URL: use a URL `...hiveos-latest.tar.gz` acima.
- Wallet / Template: endereço Keryx completo, por exemplo `keryx:...`
- Pool / URL: pool stratum, por exemplo `stratum+tcp://krx.baikalmine.com:9020`
- User Config: pode deixar vazio; vazio vira `--light` automaticamente.

Exemplo de User Config opcional:

```text
--light
```

Para teste sem OPoI/inferência, quando suportado pelo binário:

```text
--no-opoi
```

## O que esta versão faz

- Mantém a pasta esperada pelo HiveOS como `keryx-miner`.
- Gera `config.ini` a partir do Flight Sheet: `CUSTOM_URL` vira `-s` e `CUSTOM_TEMPLATE` vira `--mining-address`.
- Usa `--light` por padrão quando o campo User Config está vazio.
- Baixa o pacote real do Keryx na primeira execução, valida o `.tar.gz`, extrai em área temporária e preserva os scripts HiveOS corrigidos.
- Renomeia o binário ELF `keryx-miner` para `keryx-miner.bin` e mantém `keryx-miner` como wrapper.
- Mantém o HiveOS vivo durante bootstrap/download/model/prefetch retornando estatística provisória no `h-stats.sh`.

## URL do pacote real usado pelo bootstrap

Por padrão, o bootstrap baixa:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-miner-v032opoi_hiveosv5.tar.gz
```

Para trocar o pacote real sem alterar script, defina no ambiente, se for necessário em uma versão futura:

```bash
export KERYX_PACKAGE_URL="https://servidor/arquivo-keryx.tar.gz"
export KERYX_PACKAGE_SHA256="sha256-opcional"
```

## Estrutura do pacote HiveOS

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

## Logs no HiveOS

Depois que o HiveOS iniciar pelo Flight Sheet, o log fica em:

```text
/var/log/miner/keryx-miner.log
```
