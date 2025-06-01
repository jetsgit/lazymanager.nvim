#!/bin/bash
# extract-sandbox-lazymanager.sh
# Extracts lazymanager.lua, patches production paths for sandbox, and outputs to a target file.

set -e

PROD_FILE="${1:-/workspaces/lazymanager.nvim/lua/lazymanager.lua}"
SANDBOX_FILE="${2:-$HOME/nvim-lazy-manager-test/.config/nvim/lua/lazymanager.lua}"

# Define sandbox paths
SANDBOX_DATA="$HOME/nvim-lazy-manager-test/.local/share/nvim"
SANDBOX_BACKUP="$HOME/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/"

# Patch production paths to sandbox paths
mkdir -p "$(dirname "$SANDBOX_FILE")"
sed \
  -e "s|os\.expand(\"~\") .. '/.config/nvim/lazy-plugin-backups/'|os.expand(\"~\") .. '/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/'|g" \
  -e "s|os\.expand(\"~\") .. '/.local/share/nvim'|os.expand(\"~\") .. '/nvim-lazy-manager-test/.local/share/nvim'|g" \
  "$PROD_FILE" > "$SANDBOX_FILE"

echo "Patched lazymanager.lua for sandbox at $SANDBOX_FILE"
