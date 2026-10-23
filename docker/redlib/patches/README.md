# Redlib patches

Applied in order on top of the pinned upstream commit (`REDLIB_REF` in the Dockerfile) with `git apply`. If a patch stops applying, the image build fails.

| Patch | Why | Drop when |
| --- | --- | --- |
| `0001-scrape-comments-when-the-api-is-blocked.patch` | Since 2026-10-22 Reddit 403s the `/comments/` JSON API even with upstream's encoded-slash workaround (redlib-org/redlib#591), so every thread page errors. This falls back to the HTML fragments reddit.com loads comments from, for an hour at a time after a 403. Based on `src/shreddit.rs` from polak14/redlib@4055fda; adds the `scraper` crate. Ours also follows Reddit's same-page `rdt=` redirect, which some IPs get first (the runners' egress does). Scraped pages show 10 or 25 top-level comments with a "More comments" link. | Upstream works on its own. `redlib-candidate.yaml` checks that every night and opens a PR that removes it. |

To rebuild a patch: download the pinned upstream tarball, make the change, run `cargo build` (without `--locked`, so `Cargo.lock` picks up new crates) and `cargo test`, then `diff -ruN` against a clean copy. New files need a `new file mode 100644` line and `--- /dev/null`.
