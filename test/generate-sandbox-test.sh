#!/bin/bash
# generate-sandbox-test.sh
# Generates lazymanager-sandbox-test.sh using the latest lazymanager modules as the embedded modules.
echo "🧪 Setting up LazyManager testing sandbox..."

SANDBOX_DIR="$HOME/nvim-lazy-manager-test"
NVIM_CONFIG_DIR="$SANDBOX_DIR/.config/nvim"
MODULE_DIR="$NVIM_CONFIG_DIR/lua/lazymanager"

# Clean up any existing sandbox
if [ -d "$SANDBOX_DIR" ]; then
  echo "Removing existing sandbox..."
  rm -rf "$SANDBOX_DIR"
fi

set -e

PROD_LUA="${1:-$HOME/Documents/Neovim/LuaProjects/lazymanager.nvim/lua/lazymanager}"

# Create directories with checks
if mkdir -p "$NVIM_CONFIG_DIR/lua"; then
    echo -e "\033[1;32m✅ SUCCESS: Created $NVIM_CONFIG_DIR\033[0m"
else
    echo -e "\033[1;31m❌ ERROR: Failed to create $NVIM_CONFIG_DIR\033[0m"
fi

if mkdir -p "$MODULE_DIR"; then
    echo -e "\033[1;32m✅ SUCCESS: Created $MODULE_DIR\033[0m"
else
    echo -e "\033[1;31m❌ ERROR: Failed to create $MODULE_DIR\033[0m"
fi

if mkdir -p "$MODULE_DIR/utils"; then
    echo -e "\033[1;32m✅ SUCCESS: Created $MODULE_DIR\033[0m"
else
    echo -e "\033[1;31m❌ ERROR: Failed to create $MODULE_DIR\033[0m"
fi


if mkdir -p "$SANDBOX_DIR/.local/share/nvim"; then
    echo -e "\033[1;32m✅ SUCCESS: Created $SANDBOX_DIR/.local/share/nvim\033[0m"
else
    echo -e "\033[1;31m❌ ERROR: Failed to create $SANDBOX_DIR/.local/share/nvim\033[0m"
fi

set -e

# Copy all needed files to the sandbox
cp "$PROD_LUA/lazymanager.lua" "$MODULE_DIR/lazymanager.lua"
cp "$PROD_LUA/backup.lua" "$MODULE_DIR/backup.lua"
cp "$PROD_LUA/paths.lua" "$MODULE_DIR/paths.lua"
cp "$PROD_LUA/ui.lua" "$MODULE_DIR/ui.lua"
cp "$PROD_LUA/git.lua" "$MODULE_DIR/git.lua"
cp "$PROD_LUA/utils/json.lua" "$MODULE_DIR/utils/json.lua"


echo "Copied lazymanager modules to sandbox."

# Patch paths.lua for sandbox
# SANDBOX_PATHS="$MODULE_DIR/paths.lua"
# TEMP_PATHS=$(mktemp)

# awk '
# /-- Lazymanager-path/ {
#     print $0
#     getline
#     print "-- SANDBOXED: Use sandbox-specific paths"
#     print "local M = {}"
#     print "M.backup_dir = vim.fn.expand(\"~\") .. \"/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/\""
#     while ((getline line < "test/debug-paths.lua") > 0) {
#         print line
#     }
#     close("test/debug-paths.lua")
#     next
# }
# { print $0 }
# ' "$SANDBOX_PATHS" > "$TEMP_PATHS" && mv "$TEMP_PATHS" "$SANDBOX_PATHS"

# echo "Patched paths.lua for sandboxed backup_dir and injected debug helpers."
# Create basic init.lua for Neovim
cat > "$NVIM_CONFIG_DIR/init.lua" << 'EOF'
-- Minimal Neovim config for testing LazyManager
-- SANDBOXED: All paths use the sandbox environment

-- Set up sandbox-specific paths
local sandbox_data = vim.fn.expand('~') .. '/nvim-lazy-manager-test/.local/share/nvim'
local sandbox_config = vim.fn.expand('~') .. '/nvim-lazy-manager-test/.config/nvim'
local backup_dir = sandbox_config .. '/lazy-plugin-backups'

-- Override stdpath to use sandbox
local original_stdpath = vim.fn.stdpath
vim.fn.stdpath = function(what)
  if what == "data" then
    return sandbox_data
  elseif what == "config" then
    return sandbox_config
  else
    return original_stdpath(what)
  end
end

-- Bootstrap lazy.nvim in sandbox
local lazypath = sandbox_data .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  print("📦 Installing lazy.nvim to sandbox...")
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy with test plugins (all installed to sandbox)
require("lazy").setup({
  -- Test plugins (lightweight and safe)
  "nvim-lua/plenary.nvim",
  "folke/which-key.nvim",
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" }
  },
  "lewis6991/gitsigns.nvim",
  "windwp/nvim-autopairs",
  {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
        {
          "nvim-telescope/telescope-fzf-native.nvim",
          build = "make", -- Compiles the C code for optimal fuzzy matching performance
        },
      },
      config = function()
        require("telescope").setup({})
        require("telescope").load_extension("fzf")
      end,
    },
  }, {
  -- Lazy configuration - all sandboxed
  root = sandbox_data .. "/lazy_plugins",
  lockfile = sandbox_config .. "/lazy-lock.json",
  performance = {
    cache = {
      enabled = true,
      path = sandbox_data .. "/lazy/cache",
    },
  },
})

-- Load LazyManager after lazy.nvim is set up
local lazy_manager = require('lazymanager.lazymanager')
lazy_manager.setup()

--LazyDebugPaths
vim.api.nvim_create_user_command("LazyDebugPaths", function()
  local lazy = require("lazy")
  local paths = require("lazymanager.paths")
  print("🔍 LazyManager Debug - Plugin Paths:")
  print("📁 Backup dir: " .. paths.get_backup_dir())
  print("🔌 Plugin root: " .. (vim.fn.stdpath("data") .. "/lazy_plugins"))
  print("")
  print("📦 Installed plugins:")
  for _, plugin in pairs(lazy.plugins()) do
    local name = plugin.name
    local sandboxed_dir = vim.fn.stdpath("data") .. "/lazy_plugins/" .. name
    local actual_dir = plugin.dir or "N/A"
    local exists = vim.fn.isdirectory(sandboxed_dir) == 1 and "✅" or "❌"
    print(string.format("  %s %s", exists, name))
    print(string.format("    Lazy dir: %s", actual_dir))
    print(string.format("    Sandbox:  %s", sandboxed_dir))
  end
end, {})

-- Add helpful keymaps for testing
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set('n', '<leader>lb', '<cmd>LazyBackup<cr>', { desc = 'Backup plugins' })
vim.keymap.set('n', '<leader>lr', '<cmd>LazyRestore<cr>', { desc = 'Restore plugins' })
vim.keymap.set('n', '<leader>ll', '<cmd>LazyListBackups<cr>', { desc = 'List backups' })

print("🧪 LazyManager test environment loaded!")
print("Available commands:")
print("  :LazyBackup - Create backup of current plugin versions")
print("  :LazyRestore - Restore from most recent backup")
print("  :LazyRestore plugin1 plugin2 - Restore specific plugins")
print("  :LazyListBackups - List available backup files")
print("  :LazyRestoreFile <file> [plugin1 plugin2] - Restore from specific file")
print("")
print("Keymaps:")
print("  <leader>lb - :LazyBackup")
print("  <leader>lr - :LazyRestore") 
print("  <leader>ll - :LazyListBackups")
print("")

EOF

# Create the backup directory with sample backup files
mkdir -p "$NVIM_CONFIG_DIR/lazy-plugin-backups"

# Create sample backup files for testing
cat > "$NVIM_CONFIG_DIR/lazy-plugin-backups/2024-01-15-1430-lazy-plugin-backup.json" << 'EOF'
{
  "plenary.nvim": "e6dcd5666d968ca3b7035f8fcaaf2e01f5e61180",
  "which-key.nvim": "bcfe1e4596dc0c6cc25a5b14b32f60a81d18c08d",
  "lualine.nvim": "1bd420d89c4b3b7a88afd0802fcd4dd494274341",
  "nvim-web-devicons": "d360317f8f509b99229bb31d42269987696df6ff",
  "gitsigns.nvim": "07d426364c476e8a091ff7ee40b862f97e2cfb3c",
  "nvim-autopairs": "84a81a7d1f28b381b32acf1e8fe5ff5bef4f7968"
}
EOF

cat > "$NVIM_CONFIG_DIR/lazy-plugin-backups/2024-01-16-0900-lazy-plugin-backup.json" << 'EOF'
{
  "plenary.nvim": "f031bef84630f556c2fb81215826ea419d81f4e9",
  "which-key.nvim": "5bf7a73fe851896d5ac26d313db849bf00f45b78", 
  "lualine.nvim": "5a7cabf8e4a174c22351cbbdbe50310ee2172243",
  "nvim-web-devicons": "94ceacadcc9b53a4e2120a4cd54e96f88e61119e",
  "gitsigns.nvim": "425cb3942716554035ee56b0e36528355c238e3d",
  "nvim-autopairs": "e698fdf175f629c0df845e0979c4c0dd2bac393c"
}
EOF

cat > "$NVIM_CONFIG_DIR/lazy-plugin-backups/2024-01-17-1200-lazy-plugin-backup.json" << 'EOF'
{
  "plenary.nvim": "d3bc3841be168a99659e6008916ef5e6db1637bd",
  "which-key.nvim": "fcbf4eea17cb299c02557d576f0d568878e354a4",
  "lualine.nvim": "d3ff69639e78f2732e86ae2130496bd2b66e25c9", 
  "nvim-web-devicons": "fb83cbdca391d093f846a6ad4312c47d66045231",
  "gitsigns.nvim": "a3f64d4289f818bc5de66295a9696e2819bfb270",
  "nvim-autopairs": "2a406cdd8c373ae7fe378a9e062a5424472bd8d8"
}
EOF

# Create test script with proper environment setup
cat > "$SANDBOX_DIR/test_lazy_manager.sh" << "EOF"
#!/bin/bash

echo "🧪 LazyManager Test Script"
echo "========================="

cd "$(dirname "$0")"

# Set environment to use sandbox
export XDG_HOME="$(pwd)"
export XDG_CONFIG_HOME="$(pwd)/.config"
export XDG_DATA_HOME="$(pwd)/.local/share"

echo "🏠 Sandbox Environment:"
echo "  Config: $XDG_CONFIG_HOME"
echo "  Data: $XDG_DATA_HOME"
echo ""

echo "📋 Available LazyManager Commands:"
echo "  :LazyBackup                    - Create backup of current plugins"
echo "  :LazyRestore                   - Restore all plugins from latest backup"
echo "  :LazyRestore plugin1 plugin2   - Restore specific plugins"
echo "  :LazyListBackups               - List all available backups"
echo "  :LazyRestoreFile <file>        - Restore from specific backup file"
echo "  :LazyDebugPaths                - Show plugin directory paths (for debugging)"
echo ""

echo "🧪 Testing Scenarios:"
echo "1. First, let plugins install: Wait for Lazy to finish installing"
echo "2. Run :LazyDebugPaths to verify sandbox paths are being used"
echo "3. Run :LazyBackup to create your first backup"
echo "4. Run :LazyListBackups to see all backups (includes sample ones)"
echo "5. Try :LazyRestore to test restoration (will prompt for confirmation)"
echo "6. Test :LazyRestore plenary.nvim to restore just one plugin"
echo "7. Test :LazyRestoreFile with tab completion for specific files"
echo ""

echo "📁 Backup files are stored in:"
echo "   $XDG_CONFIG_HOME/nvim/lazy-plugin-backups/"
echo ""

echo "⚠️  Note: All operations are sandboxed and won't affect your main nvim config"
echo ""

# echo 'export LAZYMANAGER_SANDBOX=1' > "$(dirname "$0")/.env"
# source "$(dirname "$0")/.env"

echo "Press Enter to launch Neovim..."

LAZYMANAGER_SANDBOX=1 nvim -u "$XDG_CONFIG_HOME/nvim/init.lua"
EOF

chmod +x "$SANDBOX_DIR/test_lazy_manager.sh"

# Create a comprehensive test verification script
cat > "$SANDBOX_DIR/verify_backups.sh" << 'EOF'
#!/bin/bash

echo "🔍 LazyManager Backup Verification"
echo "=================================="

cd "$(dirname "$0")"

BACKUP_DIR=".config/nvim/lazy-plugin-backups"

echo "📁 Checking backup directory: $BACKUP_DIR"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "❌ Backup directory not found!"
  exit 1
fi

echo "📄 Found backup files:"
ls -la "$BACKUP_DIR"/*.json 2>/dev/null | while read line; do
  echo "  $line"
done

echo ""
echo "🔍 Sample backup contents:"
for file in "$BACKUP_DIR"/*.json; do
  if [ -f "$file" ]; then
    echo "📄 $(basename "$file"):"
    cat "$file" | jq . 2>/dev/null || cat "$file"
    echo ""
  fi
done
EOF

chmod +x "$SANDBOX_DIR/verify_backups.sh"

# Create cleanup script
cat > "$SANDBOX_DIR/cleanup.sh" << 'EOF'
#!/bin/bash
echo "🧹 Cleaning up LazyManager test environment..."
cd "$(dirname "$0")"
cd ..
rm -rf "nvim-lazy-manager-test"
echo "✅ Cleanup complete!"
EOF

chmod +x "$SANDBOX_DIR/cleanup.sh"

# Create a quick status script
cat > "$SANDBOX_DIR/status.sh" << 'EOF'
#!/bin/bash

echo "📊 LazyManager Sandbox Status"
echo "============================="

cd "$(dirname "$0")"

echo "📁 Sandbox structure:"
find . -type d | head -10

echo ""
echo "📦 Lazy plugins directory:"
if [ -d ".local/share/nvim/lazy_plugins" ]; then
  echo "  Plugins installed: $(ls .local/share/nvim/lazy_plugins | wc -l)"
  ls .local/share/nvim/lazy_plugins
else
  echo "  No plugins installed yet"
fi

echo ""
echo "💾 Backup files:"
if [ -d ".config/nvim/lazy-plugin-backups" ]; then
  ls -la .config/nvim/lazy-plugin-backups/
else
  echo "  No backup directory found"
fi
EOF

chmod +x "$SANDBOX_DIR/status.sh"
# FOOTER

echo "✅ LazyManager testing sandbox created at: $SANDBOX_DIR"
echo ""
echo "🚀 To start testing:"
echo "   cd $SANDBOX_DIR"
echo "   ./test_lazy_manager.sh"
echo ""
echo "🔧 Additional utilities:"
echo "   ./status.sh           - Check sandbox status"
echo "   ./verify_backups.sh   - Verify backup files"
echo "   ./cleanup.sh          - Remove entire sandbox"
echo ""
echo "📋 The sandbox includes:"
echo "   ✓ Complete LazyManager module with all functions"
echo "   ✓ All 4 commands: LazyBackup, LazyRestore, LazyListBackups, LazyRestoreFile"
echo "   ✓ Sandboxed paths (won't affect your real nvim config)"
echo "   ✓ Sample backup files for testing"
echo "   ✓ Safe test plugins (plenary, which-key, lualine, etc.)"
echo "   ✓ Verification and status utilities"

