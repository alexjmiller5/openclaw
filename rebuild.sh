#!/usr/bin/env bash
# rebuild.sh — Rebuild OpenClaw from source and restart the gateway
#
# Usage:
#   ./rebuild.sh              # Build + restart gateway
#   ./rebuild.sh --no-restart # Build only, don't restart
#   ./rebuild.sh --full       # Clean install + build + UI build + restart
#
# Run from the repo root: ~/repos/openclaw/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

# Pi memory limits — prevents OOM kills
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=2048}"
export COREPACK_ENABLE_STRICT=0

NO_RESTART=false
FULL=false

for arg in "$@"; do
  case "$arg" in
    --no-restart) NO_RESTART=true ;;
    --full) FULL=true ;;
    --help|-h)
      echo "Usage: ./rebuild.sh [--no-restart] [--full]"
      echo "  --no-restart  Build only, don't restart the gateway"
      echo "  --full        Clean install deps + build + UI build + restart"
      exit 0
      ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

echo "==> OpenClaw source rebuild ($(git rev-parse --short HEAD) on $(git branch --show-current))"
echo "    NODE_OPTIONS=$NODE_OPTIONS"
echo ""

if [ "$FULL" = true ]; then
  echo "==> [1/4] Installing dependencies..."
  pnpm install --network-concurrency=1
  echo ""

  echo "==> [2/4] Building..."
  pnpm build
  echo ""

  echo "==> [3/4] Building Control UI..."
  pnpm ui:build
  echo ""
else
  echo "==> [1/2] Building..."
  pnpm build
  echo ""
fi

# Verify the build produced output
if [ ! -f "$REPO_DIR/dist/entry.js" ]; then
  echo "ERROR: dist/entry.js not found — build may have failed"
  exit 1
fi

echo "==> Build complete: dist/entry.js exists"
echo "    Version: $(node -e "console.log(require('./package.json').version)")"
echo ""

if [ "$NO_RESTART" = true ]; then
  echo "==> Skipping gateway restart (--no-restart)"
  echo "    Run 'systemctl --user restart openclaw-gateway' when ready"
else
  if [ "$FULL" = true ]; then
    STEP="[4/4]"
  else
    STEP="[2/2]"
  fi
  echo "==> $STEP Restarting gateway..."
  systemctl --user daemon-reload
  systemctl --user restart openclaw-gateway
  sleep 2

  # Quick health check
  if systemctl --user is-active openclaw-gateway >/dev/null 2>&1; then
    echo "==> Gateway is running ✓"
  else
    echo "WARNING: Gateway may not have started correctly"
    echo "    Check: systemctl --user status openclaw-gateway"
    echo "    Logs:  journalctl --user -u openclaw-gateway --since '30 sec ago' --no-pager"
    exit 1
  fi
fi

echo ""
echo "Done."
