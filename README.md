# keryx-bootstrap-custom

Bootstrap para rodar o Keryx Miner no HiveOS como Custom Miner, direto pelo Flight Sheet, sem comando manual no rig.

## Status atual

Versão recomendada do pacote HiveOS: **v10**.

O pacote HiveOS v10 instala apenas o wrapper/bootstrap do HiveOS. Depois, na primeira execução, o `keryx-bootstrap.sh` baixa o **minerador real** do release oficial:

```text
Repo real: Keryx-Labs/keryx-miner
Tag real:  v0.3.2-OPoI
Arch:      sm86
```

A tag oficial `v0.3.2-OPoI` é obrigatória porque o release informa que mineradores v0.3.1 ou anteriores produzem shares inválidos, e também informa que para RTX 30xx/40xx deve ser usado o pacote `sm86`.

## URL recomendada para colocar no HiveOS

Use a URL **versionada v10** no campo **Custom Miner Install URL / Installation URL** do Flight Sheet:

```text
https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v10.tar.gz
```

A URL `latest` também existe, mas para evitar cache do GitHub/CDN durante testes, prefira a v10:

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
https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v10.tar.gz

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

## Correção importante da v10

O pacote v9 estava certo como pacote HiveOS, mas o `keryx-bootstrap.sh` ainda tentava baixar o pacote real do minerador pelo link antigo:

```text
https://github.com/debianlima/keryx-bootstrap-custom/releases/download/bootstrap/keryx-miner-v032opoi_hiveosv5.tar.gz
```

Esse link retornava **404 Not Found**, então o HiveOS instalava o wrapper, mas não conseguia baixar o `keryx-miner.bin`.

Na v10, isso foi corrigido. O bootstrap agora:

```text
1. Consulta a API do GitHub do repo oficial Keryx-Labs/keryx-miner.
2. Usa a tag v0.3.2-OPoI.
3. Procura automaticamente asset .tar.gz/.tgz/.zip.
4. Prioriza asset com sm86, indicado para RTX 30xx/40xx.
5. Baixa, valida, extrai e procura o binário ELF keryx-miner.
6. Renomeia o binário real para keryx-miner.bin.
7. Mantém keryx-miner como wrapper do HiveOS.
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

## Validação do pacote HiveOS

Antes de aplicar no Flight Sheet, pode validar no rig com:

```bash
URL='https://raw.githubusercontent.com/debianlima/keryx-bootstrap-custom/main/dist/keryx-bootstrap-custom-hiveos-v10.tar.gz'
rm -f /tmp/keryx-v10.tar.gz
wget -O /tmp/keryx-v10.tar.gz "$URL"
gzip -t /tmp/keryx-v10.tar.gz && echo OK_GZIP
tar -tzf /tmp/keryx-v10.tar.gz | head -50
```

Resultado esperado:

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

## Teste do resolvedor do minerador real

Depois que o pacote estiver instalado em `/hive/miners/custom/keryx-miner`, você pode testar somente o resolvedor do pacote real assim:

```bash
cd /hive/miners/custom/keryx-miner
bash -x ./keryx-bootstrap.sh
```

Ele deve mostrar algo parecido com:

```text
[KERYX-BOOTSTRAP] descobrindo pacote real no GitHub
[KERYX-BOOTSTRAP] repo: Keryx-Labs/keryx-miner
[KERYX-BOOTSTRAP] tag:  v0.3.2-OPoI
[KERYX-BOOTSTRAP] arch: sm86
[KERYX-BOOTSTRAP] asset escolhido: ...sm86...
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
7. Não usa mais o asset antigo `hiveosv5`, que retornava 404.
8. Descobre o pacote real automaticamente no release oficial `Keryx-Labs/keryx-miner`.
9. Prioriza `sm86` para RTX 30xx/40xx.
10. Baixa e valida pacote `.tar.gz`, `.tgz` ou `.zip`.
11. Extrai em área temporária antes de copiar para a pasta final.
12. Preserva os scripts corrigidos do HiveOS quando extrai o pacote original.
13. Detecta se o binário real veio como ELF chamado `keryx-miner` e renomeia para `keryx-miner.bin`.
14. Recria o wrapper `keryx-miner` para chamar o binário real.
15. Ajusta permissões de execução automaticamente.
16. Cria diretórios de cache/modelos/logs.
17. Configura variáveis de ambiente do Keryx, cache, temporários e bibliotecas.
18. Opcionalmente executa o download rápido dos modelos via `--fast-models`.
19. O `h-stats.sh` retorna atividade provisória durante bootstrap/download/model/prefetch para reduzir chance do HiveOS matar o custom miner por falta de status.
20. O `h-run.sh` novo tenta manter a tela viva, imprimir diagnóstico e reiniciar se o processo cair.

## Logs no HiveOS

```text
/var/log/miner/keryx-miner.log
```

Diagnóstico extra, quando houver falha:

```text
/var/log/miner/keryx-miner.diag.log
```
