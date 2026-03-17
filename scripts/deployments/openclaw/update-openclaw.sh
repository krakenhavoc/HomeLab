#!/bin/bash
set -e

cd /opt/openclaw
git pull origin fork
pnpm install
pnpm build
pnpm ui:build
sudo systemctl restart openclaw-gateway
echo "OpenClaw updated and restarted."
