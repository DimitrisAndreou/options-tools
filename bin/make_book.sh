#!/usr/bin/env bash
set -e

# Change to the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Ensure ~/.local/bin is in PATH for mdbook
export PATH="$HOME/.local/bin:$PATH"

echo "==> 1/2: Generating programmatic book assets (Dart SVG engine)..."
dart run book/scripts/generate_book_assets.dart

echo "==> 2/2: Building book with mdBook..."
mdbook build book

echo "✅ Book built successfully in docs/book/"
