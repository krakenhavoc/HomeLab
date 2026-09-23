#!/usr/bin/env bash
# Markdown summary of a plan: counts plus every affected resource.
# Usage: plan-summary.sh <plan.json> <workspace> <environment> <path>
set -euo pipefail

plan=$1 ws=$2 env=$3 path=$4

# One line per affected resource: "<kind>\t<address>"
rows=$(jq -r '
  .resource_changes[]?
  | .change.actions as $a
  | (.change.importing != null) as $imp
  | (if ($a | index("create")) and ($a | index("delete")) then "replace"
     elif $a == ["create"] then "create"
     elif $a == ["delete"] then "destroy"
     elif $a == ["update"] then "update"
     elif $a == ["forget"] then "forget"
     elif $imp then "import"
     else empty end) as $kind
  | "\($kind)\(if $imp and $kind != "import" then "+import" else "" end)\t\(.address)"
' "$plan")

echo "### Terraform Plan Summary (\`$ws\`)"
echo
if [ -z "$rows" ]; then
  echo "✅ **No changes.** Infrastructure matches configuration."
else
  echo "| Action | Count |"
  echo "|--------|-------|"
  for kind in create update replace destroy import forget; do
    n=$(grep -cE "^$kind|\+$kind" <<<"$rows" || true)
    [ "$n" -gt 0 ] || continue
    case $kind in
      create) label="➕ Create" ;; update) label="🔁 Update" ;; replace) label="♻️ Replace" ;;
      destroy) label="❌ Destroy" ;; import) label="📥 Import" ;; forget) label="👋 Forget" ;;
    esac
    echo "| $label | $n |"
  done
  echo
  total=$(wc -l <<<"$rows")
  [ "$total" -le 15 ] && open=" open" || open=""
  echo "<details$open><summary>Resources ($total)</summary>"
  echo
  sort <<<"$rows" | while IFS=$'\t' read -r kind addr; do
    echo "- \`$kind\` \`$addr\`"
  done
  echo
  echo "</details>"
fi
echo
echo "_Environment: \`$env\` | Path: \`$path\`_"
