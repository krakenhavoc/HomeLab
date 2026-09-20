#!/bin/bash
set -e

# openclaw-2 is an npm install, so none of update-openclaw.sh applies here:
# there is no /opt checkout to pull and nothing to build. `openclaw update` is
# upstream's recommended path -- it installs the new package and refreshes the
# gateway service metadata, so no separate systemctl restart is needed.
openclaw update

# Catches config/service drift after the version bump (stale model refs, a
# gateway unit still pointing at an old port or binary).
openclaw doctor

echo "openclaw-2 updated. Run 'openclaw gateway status' to confirm."
