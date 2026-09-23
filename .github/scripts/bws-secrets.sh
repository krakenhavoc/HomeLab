#!/usr/bin/env bash
# Usage: bws-secrets.sh <path/to/secrets.env>
# Prints a $GITHUB_OUTPUT `secrets` value for bitwarden/sm-action:
# one "<id> > TF_VAR_<lowercased NAME>" line per NAME=<id>.
# Missing file: prints nothing. HAS_TOKEN must be "true" when the file exists.
set -euo pipefail

file=$1
[ -f "$file" ] || exit 0

h='[0-9a-fA-F]'
re="^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*($h{8}-$h{4}-$h{4}-$h{4}-$h{12})[[:space:]]*$"
lines=()
seen=" "
n=0
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  line=${line%$'\r'}
  [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
  if [[ ! "$line" =~ $re ]]; then
    echo "::error file=$file,line=$n::expected NAME=<bitwarden secret id>" >&2
    exit 1
  fi
  name=${BASH_REMATCH[1]}
  id=${BASH_REMATCH[2]}
  case "$seen" in *" ${name,,} "*)
    echo "::error file=$file,line=$n::duplicate $name" >&2
    exit 1 ;;
  esac
  seen+="${name,,} "
  lines+=("$id > TF_VAR_${name,,}")
done <"$file"

[ ${#lines[@]} -gt 0 ] || exit 0
if [ "${HAS_TOKEN:-}" != true ]; then
  echo "::error file=$file::$file lists Bitwarden secrets but BWS_ACCESS_TOKEN is not set in this environment" >&2
  exit 1
fi

delim="EOF_$(openssl rand -hex 8)"
printf 'secrets<<%s\n' "$delim"
printf '%s\n' "${lines[@]}"
printf '%s\n' "$delim"
