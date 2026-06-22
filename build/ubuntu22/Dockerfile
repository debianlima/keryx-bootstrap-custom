# Keryx Miner v1.0 builder for HiveOS-compatible glibc.
# Ubuntu 22.04 uses glibc 2.35, avoiding binaries that require GLIBC_2.39.
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

ARG RUST_TOOLCHAIN=1.88.0
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/root/.cargo/bin:${PATH}
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    protobuf-compiler \
    clang \
    cmake \
    llvm-dev \
    libclang-dev \
    python3 \
    perl \
    unzip \
    zip \
    xz-utils \
    file \
    patchelf \
    lld \
    binutils \
 && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --default-toolchain ${RUST_TOOLCHAIN} \
 && rustup component add rustfmt clippy || true

COPY container-build.sh /usr/local/bin/keryx-container-build
RUN chmod 755 /usr/local/bin/keryx-container-build \
 && rustc --version \
 && cargo --version \
 && nvcc --version

WORKDIR /work
ENTRYPOINT ["/usr/local/bin/keryx-container-build"]
