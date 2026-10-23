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
# where the build gets exercised. redlib-candidate.yaml opens that PR when
# upstream main passes probe.sh.
ARG REDLIB_REF=654e6e3ac2db6fcd964b73525580c658d9523ba5

# patches/*.patch apply on top, in order; see patches/README.md. off builds
# plain upstream (the candidate workflow uses it to see if they're still needed).
ARG REDLIB_PATCHES=on

FROM rust:slim-bookworm AS builder
ARG REDLIB_REF
ARG REDLIB_PATCHES

RUN apt-get update \
    && apt-get -y install --no-install-recommends git ca-certificates build-essential cmake libclang-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /redlib
RUN git init -q . \
    && git remote add origin https://github.com/redlib-org/redlib.git \
    && git fetch -q --depth 1 origin "${REDLIB_REF}" \
    && git checkout -q FETCH_HEAD

COPY patches/ /patches/
RUN if [ "${REDLIB_PATCHES}" = on ]; then \
      for p in /patches/*.patch; do echo "applying ${p##*/}"; git apply "$p"; done; \
    fi

RUN cargo build --release --locked --bin redlib

FROM ubuntu:noble

COPY --from=builder /redlib/target/release/redlib /usr/local/bin/redlib
COPY probe.sh /usr/local/bin/redlib-probe

USER nobody
EXPOSE 8080

# No HEALTHCHECK here: the compose file runs redlib-probe, which needs Reddit,
# and CI's runners can't reach it.

CMD ["redlib"]
