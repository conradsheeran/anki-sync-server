# syntax=docker/dockerfile:1.7

ARG RUST_VERSION=1.85.0
ARG RUST_IMAGE=rust:${RUST_VERSION}-slim-bookworm@sha256:1829c432be4a592f3021501334d3fcca24f238432b13306a4e62669dec538e52
ARG DEBIAN_IMAGE=debian:bookworm-slim@sha256:74d56e3931e0d5a1dd51f8c8a2466d21de84a271cd3b5a733b803aa91abf4421

FROM ${RUST_IMAGE} AS base
ARG ANKI_VERSION=25.09.2
ARG CARGO_CHEF_VERSION=0.1.67
RUN apt-get update && apt-get install -y --no-install-recommends \
    protobuf-compiler \
    cmake \
    clang \
    pkg-config \
    libssl-dev \
    git \
    && cargo install --locked --version ${CARGO_CHEF_VERSION} cargo-chef \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM base AS planner
WORKDIR /src
RUN git clone --depth 1 --branch ${ANKI_VERSION} https://github.com/ankitects/anki.git .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    cargo chef prepare --recipe-path recipe.json --bin anki-sync-server

FROM base AS builder
WORKDIR /src
COPY --from=planner /src /src
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    cargo chef cook --recipe-path recipe.json --release --bin anki-sync-server
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/src/target \
    cargo build --release --bin anki-sync-server \
    && strip target/release/anki-sync-server \
    && cp target/release/anki-sync-server /usr/local/bin/anki-sync-server

FROM ${DEBIAN_IMAGE} AS runtime
ARG SOURCE_REPO
ARG VCS_REF
ARG BUILD_DATE
LABEL org.opencontainers.image.source="https://github.com/${SOURCE_REPO}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.title="anki-sync-server"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
RUN useradd -m -u 10001 anki
COPY --from=builder /usr/local/bin/anki-sync-server /usr/local/bin/anki-sync-server
RUN mkdir -p /data && chown anki:anki /data
USER anki
ENV SYNC_HOST=0.0.0.0
ENV SYNC_PORT=8080
ENV SYNC_BASE=/data
EXPOSE 8080
CMD ["anki-sync-server"]
