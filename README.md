# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner, direto pelo Flight Sheet, sem comando manual no rig.

## Status atual

Versão recomendada: **v9**.

O pacote **v9** foi testado no rig com:

```bash
gzip -t /tmp/keryx-v9.tar.gz
tar -tzf /tmp/keryx-v9.tar.gz | head -50
```

Resultado esperado e confirmado:

```text
OK_GZIP
keryx-miner/
keryx-miner/h-config.sh
keryx-miner/h-manifest.conf
keryx-miner/h-run
keryx-miner/h-run.sh
keryx-miner/h-stats.sh
keryx-miner/keryx-bootstrap.sh
keryx-miner/keryx-miner
```

## URL recomendada para colocar no HiveOS

Use a URL **versionada v9** no campo **Custom Miner Install URL / Installation URL** do Flight Sheet:

```text
https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v9.tar.gz
```

A URL `latest` também existe, mas para evitar cache do GitHub/CDN durante testes, prefira a v9:

```text
https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-latest.tar.gz
```

## Configuração padrão do Flight Sheet

Print de referência:

![Configuração padrão no HiveOS](docs/hiveos-flight-sheet-keryx-default.jpg)

No Flight Sheet do HiveOS:

```text
Miner name:
keryx-miner

Installation URL:
https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v9.tar.gz

Hash algorithm:
blake3-alph

Wallet and worker template:
keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa

Pool URL:
stratum+tcp://krx.baikalmine.com:9020

Pass:
deixe vazio

Extra config arguments:
deixe vazio
```

Se você deixar **Pool URL**, **Wallet and worker template** ou **Extra config arguments** vazios, o script usa estes padrões:

```text
Pool URL padrão: stratum+tcp://krx.baikalmine.com:9020
Wallet padrão: keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa
Extra padrão: --light
```

## Extra config especial para baixar modelos mais rápido

Para habilitar o download rápido dos modelos pelo link alternativo, coloque no campo **Extra config arguments**:

```text
--fast-models
```

O wrapper baixa e executa o script alternativo de modelos do Hugging Face antes de iniciar o minerador. Para forçar novo download mesmo depois de já ter concluído uma vez:

```text
--fast-models-force
```

Para desabilitar explicitamente:

```text
--no-fast-models
```

Essas opções são consumidas pelo wrapper local e não são repassadas ao binário Keryx.

## Correção importante da v9

As versões anteriores do pacote `.tar.gz` chegaram a baixar com HTTP 200, mas falhavam no teste:

```text
gzip: invalid compressed data--crc error
gzip: invalid compressed data--length error
gzip: invalid compressed data--format violated
```

Quando isso acontece, o HiveOS não consegue extrair o pacote e a pasta abaixo não é criada:

```text
/hive/miners/custom/keryx-miner
```

Sintoma observado:

```text
No miner screens found
ls: cannot access '/hive/miners/custom/keryx-miner': No such file or directory
```

A v9 foi recriada para corrigir isso. Antes de aplicar no Flight Sheet, pode validar no rig com:

```bash
URL='https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v9.tar.gz'
rm -f /tmp/keryx-v9.tar.gz
wget -O /tmp/keryx-v9.tar.gz "$URL"
gzip -t /tmp/keryx-v9.tar.gz && echo OK_GZIP
tar -tzf /tmp/keryx-v9.tar.gz | head -50
```

## O que esta versão corrige no HiveOS

```text
Flight Sheet
   |
   v
HiveOS baixa o pacote .tar.gz
   |
   v
/hive/miners/custom/keryx-miner/
   |
   +-- h-manifest.conf       -> nome, versão, binário e log para o HiveOS
   +-- h-config.sh           -> cria config.ini com pool/wallet/defaults
   +-- h-run.sh              -> bootstrap + modelos rápidos + start real
   +-- h-stats.sh            -> mantém status vivo no HiveOS
   +-- keryx-bootstrap.sh    -> baixa e instala o pacote real do Keryx
   +-- keryx-miner           -> wrapper
   +-- keryx-miner.bin       -> binário real baixado no primeiro start
```

Correções aplicadas:

1. Mantém a pasta esperada pelo HiveOS como `keryx-miner`.
2. Evita executar pela raiz `/hive/miners/custom`.
3. Gera `config.ini` automaticamente a partir do Flight Sheet.
4. Usa defaults seguros quando os campos do HiveOS ficam vazios.
5. Usa `--light` por padrão para placas de 8 GB.
6. Executa bootstrap automático se `keryx-miner.bin` ainda não existir.
7. Baixa o pacote real do Keryx e valida o `.tar.gz` com `gzip -t`.
8. Extrai em área temporária antes de copiar para a pasta final.
9. Preserva os scripts corrigidos do HiveOS quando extrai o pacote original.
10. Detecta se o binário real veio como ELF chamado `keryx-miner` e renomeia para `keryx-miner.bin`.
11. Recria o wrapper `keryx-miner` para chamar o binário real.
12. Ajusta permissões de execução automaticamente.
13. Cria diretórios de cache/modelos/logs.
14. Configura variáveis de ambiente do Keryx, cache, temporários e bibliotecas.
15. Opcionalmente executa o download rápido dos modelos via `--fast-models`.
16. O `h-stats.sh` retorna atividade provisória durante bootstrap/download/model/prefetch para reduzir chance do HiveOS matar o custom miner por falta de status.
17. O `h-run.sh` novo tenta manter a tela viva, imprimir diagnóstico e reiniciar se o processo cair.

## Estrutura do pacote HiveOS

```text
keryx-miner/
keryx-miner/h-manifest.conf
keryx-miner/h-config.sh
keryx-miner/h-run
keryx-miner/h-run.sh
keryx-miner/h-stats.sh
keryx-miner/keryx-bootstrap.sh
keryx-miner/keryx-miner
```

## Logs no HiveOS

```text
/var/log/miner/keryx-miner.log
```

Diagnóstico extra, quando houver falha:

```text
/var/log/miner/keryx-miner.diag.log
```
