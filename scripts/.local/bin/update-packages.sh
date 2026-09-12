#!/usr/bin/env bash
# Regenerate the explicit package list for the repo.

set -euo pipefail

REPO="${HOME}/nightcity"
OUT="${REPO}/docs/packages.txt"

pacman -Qqe > "${OUT}"
echo "Wrote $(wc -l < "${OUT}") packages to ${OUT}"
