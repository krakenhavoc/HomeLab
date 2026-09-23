#!/usr/bin/env bash
# Usage: BWS_ACCESS_TOKEN=... bws-map.sh <app> <env> NAME [NAME...]
# Finds each NAME by key in Bitwarden and writes NAME=<id> to
# terraform/deployments/<app>/env/<env>/secrets.env. Never prints values.
# BWS_PROJECT_ID narrows the lookup to one project.
set -euo pipefail

[ $# -ge 3 ] || { echo "usage: $0 <app> <env> NAME [NAME...]" >&2; exit 2; }
[ -n "${BWS_ACCESS_TOKEN:-}" ] || { echo "BWS_ACCESS_TOKEN is not set" >&2; exit 2; }
command -v bws >/dev/null || { echo "bws not found" >&2; exit 2; }

app=$1 env=$2
shift 2
dir="$(cd "$(dirname "$0")/../.." && pwd)/terraform/deployments/$app/env/$env"
[ -d "$dir" ] || { echo "no $dir" >&2; exit 1; }
file=$dir/secrets.env

# Keys and ids only; values never leave this pipe.
index=$(bws secret list ${BWS_PROJECT_ID:+"$BWS_PROJECT_ID"} --output json | jq -c 'map({key, id})')

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
[ -f "$file" ] && cat "$file" >"$tmp"

rc=0
for name in "$@"; do
  if [[ ! "$name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "bad name: $name" >&2; rc=1; continue
  fi
  ids=$(jq -r --arg k "$name" '.[] | select(.key == $k) | .id' <<<"$index")
  count=$(grep -c . <<<"$ids" || true)
  if [ "$count" -ne 1 ]; then
    echo "$name: $count secrets with that key" >&2; rc=1; continue
  fi
  if grep -qE "^[[:space:]]*${name}[[:space:]]*=" "$tmp"; then
    sed -i -E "s|^[[:space:]]*${name}[[:space:]]*=.*|$name=$ids|" "$tmp"
  else
    printf '%s=%s\n' "$name" "$ids" >>"$tmp"
  fi
  echo "$name=$ids"
done

[ "$rc" -eq 0 ] || { echo "not writing $file" >&2; exit "$rc"; }
cp "$tmp" "$file"
echo "wrote $file"
