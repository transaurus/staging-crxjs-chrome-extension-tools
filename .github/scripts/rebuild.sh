#!/usr/bin/env bash
set -euo pipefail

# rebuild.sh for crxjs/chrome-extension-tools
# Runs on an existing source tree (CWD = packages/vite-plugin-docs).
# Installs deps from monorepo root, then builds the Docusaurus site.
# Does NOT clone or run write-translations.

# ── Environment ───────────────────────────────────────────────────────────────
export PATH="/usr/local/bin:/usr/bin:/bin"
export HOME="${HOME:-/root}"
export CI=true

echo "=== Node version ==="
node --version

# ── pnpm ─────────────────────────────────────────────────────────────────────
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

echo "=== Installing pnpm@10.11.1 ==="
npm install -g pnpm@10.11.1 --quiet
echo "pnpm version: $(pnpm --version)"

# ── Install deps from monorepo root ──────────────────────────────────────────
# CWD is packages/vite-plugin-docs; monorepo root is ../../
DOCS_DIR="$(pwd)"

if [ -f "../../pnpm-workspace.yaml" ] || [ -f "../../pnpm-lock.yaml" ]; then
    echo "=== Installing root dependencies (monorepo) ==="
    cd ../..
    pnpm install --no-frozen-lockfile
    cd "$DOCS_DIR"
else
    # Staging repo may not have full monorepo structure — clone source for workspace deps
    echo "=== Monorepo root not found; cloning source for workspace dependencies ==="
    TEMP_SOURCE="/tmp/crxjs-source-deps-$$"
    git clone --depth=1 https://github.com/crxjs/chrome-extension-tools "$TEMP_SOURCE"
    cd "$TEMP_SOURCE"
    npm install -g pnpm@10.11.1 --quiet 2>/dev/null || true
    pnpm install --no-frozen-lockfile
    # Copy node_modules from source root to provide workspace resolution
    cp -r node_modules "$DOCS_DIR/../../node_modules" 2>/dev/null || true
    cd "$DOCS_DIR"
fi

# ── Build ─────────────────────────────────────────────────────────────────────
echo "=== Running docusaurus build ==="
pnpm run build

echo "=== Verifying build output ==="
if [ -d "build" ] && [ "$(ls -A build)" ]; then
    echo "SUCCESS: build/ directory exists and contains files"
    ls -la build/
else
    echo "ERROR: build/ directory missing or empty"
    exit 1
fi

echo "[DONE] Build complete."
