# Caddy with the Cloudflare DNS provider compiled in.
#
# caddy-dns/cloudflare is not in the standard Caddy distribution -- it has to
# be built in with xcaddy -- and the DNS-01 ACME challenge it provides is the
# whole reason this image exists. DNS-01 proves control of a name by writing a
# TXT record rather than by answering an inbound request, which is what lets
# the lab hold genuine Let's Encrypt certificates for labxp.io names while
# accepting no inbound connection from the internet at all. The alternative is
# an internal CA whose root has to be installed on every device you browse
# from, which is the specific pain the gateway exists to avoid.
#
# Built here rather than pulled from one of the third-party prebuilt
# caddy-with-cloudflare images on GHCR: this keeps the supply chain for the
# binary that terminates TLS for every internal service down to Caddy upstream
# plus this repository, and it costs ten lines to do.
#
# See docs/gateway.md.

# Pinned deliberately, and NOT :latest. This binary is the only thing standing
# between a browser and every service in the lab, so an unattended upstream
# change here is an unattended change to that. Bump it on purpose, in a PR
# where the build gets exercised.
ARG CADDY_VERSION=2.11.4

FROM caddy:${CADDY_VERSION}-builder AS builder

# No version pin on the plugin, deliberately. caddy-dns/cloudflare tracks the
# Caddy release it is built against; pinning it independently is a reliable
# way to produce a build that fails on the next Caddy bump for reasons that
# have nothing to do with the bump.
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

FROM caddy:${CADDY_VERSION}

# Overlay the custom binary onto the stock runtime image rather than shipping
# the builder: the Go toolchain and module cache are an order of magnitude
# larger than the runtime image they would be riding along in.
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
