# Redlib, built from upstream source on a glibc (Ubuntu) runtime.
#
# Built here rather than pulled from quay.io/redlib/redlib: the official image
# (musl/Alpine) fails Reddit's OAuth bootstrap -- the logs show 401 from the
# token endpoint, then 403 on every listing, and every page renders "Failed to
# parse page JSON data". The same upstream commit built on glibc works from the
# same public IP. Upstream issue: redlib-org/redlib#551. The official image is
# not going to get fixed on its own -- upstream has been quiet since April.
#
# See docs/gateway.md.

# Pinned to a commit, NOT a branch. Reddit breaks Redlib every few months and
# the fix is usually a newer upstream commit, so bump this on purpose, in a PR
# where the build gets exercised.
ARG REDLIB_REF=a4d36e954cf1bd64f209cd8868c5a29edc81b374

FROM rust:slim-bookworm AS builder
ARG REDLIB_REF

RUN apt-get update \
    && apt-get -y install --no-install-recommends git ca-certificates build-essential cmake libclang-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /redlib
RUN git init -q . \
    && git remote add origin https://github.com/redlib-org/redlib.git \
    && git fetch -q --depth 1 origin "${REDLIB_REF}" \
    && git checkout -q FETCH_HEAD

RUN cargo build --release --locked --bin redlib

FROM ubuntu:noble

COPY --from=builder /redlib/target/release/redlib /usr/local/bin/redlib

USER nobody
EXPOSE 8080

# No HEALTHCHECK here: noble has no wget or curl, so the compose file checks
# /settings with bash's /dev/tcp instead.

CMD ["redlib"]
