#!/usr/bin/env bash
# Prints $GITHUB_ENV lines: TF_VAR_<lowercased name> for every var in $VARS
# (JSON) and every non-empty TFSECRET_<NAME> the calling step sets.
set -euo pipefail

delim="EOF_$(openssl rand -hex 8)"
emit() { printf 'TF_VAR_%s<<%s\n%s\n%s\n' "${1,,}" "$delim" "$2" "$delim"; }

vars=${VARS:-"{}"}
while IFS= read -r name; do
  emit "$name" "$(jq -r --arg k "$name" '.[$k]' <<<"$vars")"
done < <(jq -r 'keys[] | select(test("^[A-Za-z_][A-Za-z0-9_]*$"))' <<<"$vars")

for env_name in $(compgen -e | grep '^TFSECRET_' || true); do
  [ -n "${!env_name}" ] && emit "${env_name#TFSECRET_}" "${!env_name}"
done
exit 0
