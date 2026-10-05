# --- Cloudflare: zone custom rules (prd only) --------------------------------
# cmd_and_ctrl's uptime watcher (ADR 0123 §8, cmd_and_ctrl#2283) curls
# /healthz on both hosts from GitHub-hosted runners every 10 minutes.
# Cloudflare answered every try with 403 and `cf-mitigated: challenge`: a
# datacenter address running curl looks like a bot. This rule lets exactly
# that request through and nothing else.
#
# A zone has ONE entrypoint ruleset per phase, and these are the zone's
# custom rules as a whole (Security > WAF > Custom rules): `rules` is the full
# list, so a rule added in the dashboard is deleted by the next apply. Add
# zone custom rules here, not there. Only one workspace may own it, so it is
# gated on manage_zone_waf, which only env/prd sets.
#
# If the zone already has an entrypoint (any custom rule ever made in the
# dashboard leaves one), the create fails. Import it into prd's state first
# and copy any rule worth keeping into `rules`:
#   terraform import 'cloudflare_ruleset.zone_custom_firewall[0]' \
#     'zones/<zone_id>/<ruleset_id>'
#
# Not skippable by any rule: Bot Fight Mode on a Free zone. If the challenge
# comes from there (Security > Events), turn Bot Fight Mode off instead.

locals {
  healthz_hosts = concat([var.cmd_and_ctrl.fqdn], var.cmd_and_ctrl.healthz_peer_fqdns)
}

resource "cloudflare_ruleset" "zone_custom_firewall" {
  count = var.cmd_and_ctrl.manage_zone_waf ? 1 : 0

  zone_id     = var.cloudflare_zone_id
  name        = "default"
  description = "Zone custom rules. Managed by HomeLab terraform/deployments/cmd-and-ctrl (prd); dashboard edits are overwritten."
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules = [
    {
      ref         = "cmdctrl_healthz_skip"
      description = "cmd_and_ctrl uptime watcher: let GET /healthz past challenges (cmd_and_ctrl#2283)"
      enabled     = true
      # Path, method and host, all exact: /healthz is a static 200 "ok" and
      # nothing else on these hosts is exempted.
      expression = format(
        "(http.request.uri.path eq \"/healthz\" and http.request.method in {\"GET\" \"HEAD\"} and http.host in {%s})",
        join(" ", [for h in local.healthz_hosts : "\"${h}\""]),
      )
      action = "skip"
      action_parameters = {
        # The custom rules after this one.
        ruleset = "current"
        # Rate limiting rules, managed rules and (Pro and up) Super Bot Fight
        # Mode, which run in their own phases after this one.
        phases = concat(
          ["http_ratelimit", "http_request_firewall_managed"],
          var.cmd_and_ctrl.waf_skip_sbfm ? ["http_request_sbfm"] : [],
        )
        # The legacy products, Security Level and Browser Integrity Check
        # among them: the usual sources of a managed challenge for curl.
        products = ["bic", "hot", "rateLimit", "securityLevel", "uaBlock", "waf", "zoneLockdown"]
      }
      # Matches show up in Security > Events, so a skip is never silent.
      logging = {
        enabled = true
      }
    },
  ]
}
