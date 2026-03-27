#!/usr/bin/env bash
set -euo pipefail

# prepare.sh for crxjs/chrome-extension-tools
# Docusaurus 2.2.0, pnpm@10.11.1, Node 20
# Docs at: packages/vite-plugin-docs (pnpm monorepo)
# Does NOT run write-translations or build.

REPO_URL="https://github.com/crxjs/chrome-extension-tools"
BRANCH="main"
REPO_DIR="source-repo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# ── Clone (skip if already exists) ───────────────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    echo "=== Cloning $REPO_URL ==="
    git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
else
    echo "=== Skipping clone ($REPO_DIR already exists) ==="
fi

cd "$REPO_DIR"

# ── Install deps from root (workspace-aware) ──────────────────────────────────
echo "=== Installing root dependencies ==="
pnpm install --no-frozen-lockfile

# ── Apply fixes.json if present ───────────────────────────────────────────────
FIXES_JSON="$SCRIPT_DIR/fixes.json"
if [ -f "$FIXES_JSON" ]; then
    echo "[INFO] Applying content fixes..."
    node -e "
    const fs = require('fs');
    const path = require('path');
    const fixes = JSON.parse(fs.readFileSync('$FIXES_JSON', 'utf8'));
    for (const [file, ops] of Object.entries(fixes.fixes || {})) {
        if (!fs.existsSync(file)) { console.log('  skip (not found):', file); continue; }
        let content = fs.readFileSync(file, 'utf8');
        for (const op of ops) {
            if (op.type === 'replace' && content.includes(op.find)) {
                content = content.split(op.find).join(op.replace || '');
                console.log('  fixed:', file, '-', op.comment || '');
            }
        }
        fs.writeFileSync(file, content);
    }
    for (const [file, cfg] of Object.entries(fixes.newFiles || {})) {
        const c = typeof cfg === 'string' ? cfg : cfg.content;
        fs.mkdirSync(path.dirname(file), {recursive: true});
        fs.writeFileSync(file, c);
        console.log('  created:', file);
    }
    "
fi

echo "[DONE] Repository is ready for docusaurus commands."
