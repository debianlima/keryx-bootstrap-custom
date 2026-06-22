# Build Ubuntu 22.04 / HiveOS

Este builder recompila o Keryx Miner em Ubuntu 22.04 com CUDA 12.4 e Rust 1.88.

O objetivo e gerar um binario com baseline de glibc 2.35, evitando erro como:

```text
GLIBC_2.39 not found
```

## Arquivos

```text
build-ubuntu22-hiveos.sh
build/ubuntu22/Dockerfile
build/ubuntu22/container-build.sh
```

## Requisitos

Na maquina de build:

```text
Docker
Internet para baixar a imagem nvidia/cuda e crates Rust
Espaco livre recomendado: 20 GB ou mais
```

Nao e obrigatorio ter GPU para compilar. A imagem usada ja possui CUDA toolkit/nvcc.

## Uso

Com o fonte final em ZIP:

```bash
git clone https://github.com/debianlima/keryx-bootstrap-custom.git
cd keryx-bootstrap-custom

chmod +x build-ubuntu22-hiveos.sh

./build-ubuntu22-hiveos.sh \
  /caminho/keryx-miner-0.3.2-OPoI-external-backend-devwallet-final-src.zip \
  /tmp/keryx-v1-hiveos-build
```

Com o fonte ja extraido:

```bash
./build-ubuntu22-hiveos.sh \
  /caminho/keryx_ext_patch_src \
  /tmp/keryx-v1-hiveos-build
```

Para RTX 30xx/40xx, o padrao e:

```text
CUDA_COMPUTE_CAP=86
```

Para alterar:

```bash
CUDA_COMPUTE_CAP=89 ./build-ubuntu22-hiveos.sh /fonte /saida
```

## Saida esperada

O script gera arquivos como:

```text
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-ubuntu22.tar.gz
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-ubuntu22.zip
keryx-miner-0.3.2-OPoI-external-backend-devwallet-sm86-hiveos-ubuntu22.SHA256SUMS.txt
```

Dentro do pacote tambem sao gerados:

```text
keryx-miner
keryx-miner.bin
HELP.txt
VERSION.txt
LDD.txt
GLIBC_SYMBOLS.txt
README-BUILD.txt
build.log
```

## Validacoes automaticas

O builder falha se:

```text
o binario ainda exigir GLIBC_2.39
o --help nao mostrar --external-inference-url
a carteira de devwallet customizada nao aparecer no binario
```

A carteira esperada e:

```text
keryx:qzppqqpg3f4yrp93g9fx0t65akrtzqpfaxrdjlyljjp59gdxh549u5s9pnesa
```
