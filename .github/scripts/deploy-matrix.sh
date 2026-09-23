#!/usr/bin/env bash
# Prints matrix=[{app, env, workspace}] for deploy.yaml.
# Dispatch: APP + ENV. Otherwise: apps changed between BASE and HEAD.
set -euo pipefail

root=terraform/deployments
# Not tiered; they have their own workflows.
platform=" shared gh-runner tfc "

targets() {
  local app=$1 want=${2:-} env ws
  case "$platform" in *" $app "*) return 0 ;; esac
  [ -d "$root/$app/env" ] || return 0
  for dir in "$root/$app"/env/*/; do
    env=$(basename "$dir")
    [ -z "$want" ] || [ "$env" = "$want" ] || continue
    if [ "$app" = "$env" ]; then ws=$app; else ws=$app-$env; fi
    jq -cn --arg app "$app" --arg env "$env" --arg ws "$ws" \
      '{app: $app, env: $env, workspace: $ws}'
  done
}

if [ "$EVENT" = workflow_dispatch ]; then
  items=$(targets "$APP" "$ENV")
  [ -n "$items" ] || { echo "::error::no $root/$APP/env/$ENV" >&2; exit 1; }
else
  changed=$(git diff --name-only "$BASE...$HEAD")
  # Pipeline changes replan everything.
  if grep -qE '^\.github/(workflows/(deploy|terraform-ci|terraform-cd)\.yaml|scripts/(deploy-matrix|bws-secrets)\.sh)$' <<<"$changed"; then
    apps=$(ls "$root")
  else
    apps=$(sed -nE "s|^$root/([^/]+)/.*|\1|p" <<<"$changed" | sort -u)
  fi
  items=$(for app in $apps; do targets "$app"; done)
fi

echo "matrix=$(jq -cs . <<<"$items")"
