#!/usr/bin/env bash
set -e

# Change to the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Deploying Yahoo Proxy Worker (wrangler.toml)..."
npx wrangler deploy

echo "==> Deploying IBKR Proxy Worker (wrangler.ibkr.toml)..."
npx wrangler deploy -c wrangler.ibkr.toml

echo "✅ All Cloudflare Workers deployed successfully!"
