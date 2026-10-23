#!/usr/bin/env bash
# Checks that Redlib can still read Reddit: /r/popular, then a thread from it
# with comments. /settings is local and says nothing about Reddit.
#
# Bash only (/dev/tcp), since the image has no curl. Used by the compose
# healthcheck and redlib-candidate.yaml.
# Usage: probe.sh [host] [port]
set -uo pipefail
host=${1:-127.0.0.1}
port=${2:-8080}

get() {
  exec 3<>"/dev/tcp/${host}/${port}" || return 1
  printf 'GET %s HTTP/1.0\r\nHost: %s\r\n\r\n' "$1" "${host}" >&3
  cat <&3
  exec 3<&-
}

fail() {
  echo "probe: $*" >&2
  exit 1
}

listing=$(get /r/popular) || fail "can't connect to ${host}:${port}"
[[ ${listing} == "HTTP/1."?" 200"* ]] || fail "/r/popular: $(head -1 <<<"${listing}")"

threads=$(grep -oE 'href="/r/[^/"]+/comments/[a-z0-9]+/[^"]*"' <<<"${listing}" | cut -d'"' -f2 | head -3)
[[ -n ${threads} ]] || fail "/r/popular lists no threads"

# Any one of three, so a single NSFW-gated or empty thread isn't a failure.
for t in ${threads}; do
  body=$(get "${t}") || fail "can't connect to ${host}:${port}"
  if [[ ${body} == "HTTP/1."?" 200"* ]] && grep -q 'class="comment"' <<<"${body}"; then
    echo "probe: ok (${t})"
    exit 0
  fi
  last="${t}: $(head -1 <<<"${body}")"
done
fail "no thread rendered comments; last ${last}"
