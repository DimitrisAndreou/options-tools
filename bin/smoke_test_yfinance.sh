#!/usr/bin/env bash
set -e

# Change to the repository root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

dart run bin/smoke_test_yfinance.dart "$@"

