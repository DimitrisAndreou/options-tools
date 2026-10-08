#!/usr/bin/env bash
set -e

# Change to the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Compiling web app for production into docs/..."
dart run build_runner build --release -o web:docs --delete-conflicting-outputs

echo "✅ App compiled successfully into docs/"
