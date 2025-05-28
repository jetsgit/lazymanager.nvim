#!/bin/bash

# LazyManager Testing Sandbox Setup
# This script creates a safe testing environment for the LazyManager plugin

set -e

SANDBOX_DIR="$HOME/nvim-lazy-manager-test"
NVIM_CONFIG_DIR="$SANDBOX_DIR/.config/nvim"

echo "🧪 Setting up LazyManager testing sandbox..."

# Clean up any existing sandbox
if [ -d "$SANDBOX_DIR" ]; then
  echo "Removing existing sandbox..."
  rm -rf "$SANDBOX_DIR"
fi

# Create sandbox directory structure
mkdir -p "$NVIM_CONFIG_DIR/lua"
mkdir -p "$SANDBOX_DIR/.local/share/nvim"

# Create the complete LazyManager module with sandboxed paths
cat > "$NVIM_CONFIG_DIR/lua/lazymanager.lua" << 'EOF'
-- Define LazyManager as a module
LazyManager = {}

-- SANDBOXED: Use sandbox-specific paths
local sandbox_data = vim.fn.expand('~') .. '/nvim-lazy-manager-test/.local/share/nvim'
local backup_dir = vim.fn.expand('~') .. '/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/'
local plugin_root = sandbox_data .. '/lazy_plugins'

if vim.fn.isdirectory(backup_dir) == 0 then
  vim.fn.mkdir(backup_dir, 'p')
end

-- Generate timestamp-based backup filename
local function get_backup_filename()
  local date = os.date('%Y-%m-%d-%H%M')
  return backup_dir .. date .. '-lazy-plugin-backup.json'
end

-- Store most recent backup file path for restore function
local latest_backup_file = ''

function LazyManager.backup_plugins()
  local lazy = require('lazy')
  local plugin_versions = {}

  for _, plugin in pairs(lazy.plugins()) do
    local name = plugin.name
    -- SANDBOXED: Use sandboxed plugin directory
    local dir = plugin_root .. '/' .. name

    if dir and vim.fn.isdirectory(dir) == 1 then
      -- Use git to get the current commit hash
      local commit = vim.fn.system('cd ' .. vim.fn.shellescape(dir) .. ' && git rev-parse HEAD'):gsub('\n', '')
      if commit and #commit > 0 and not commit:match('fatal') then
        -- Truncate the commit hash to 12 digits
        plugin_versions[name] = commit:sub(1, 12)
      else
        plugin_versions[name] = plugin.commit or plugin.version or 'latest'
      end
    else
      plugin_versions[name] = plugin.commit or plugin.version or 'latest'
    end
  end

  -- Use timestamped backup file
  latest_backup_file = get_backup_filename()
  local json = vim.fn.json_encode(plugin_versions)
  local file = io.open(latest_backup_file, 'w')

  if file then
    file:write(json)
    file:close()
    print('✅ Plugins backed up to: ' .. latest_backup_file)
  else
    vim.api.nvim_err_writeln('❌ Error: Could not create backup file.')
  end
end

-- Corrected restore function
function LazyManager.restore_plugins(args, backup_path)
  local backup_to_use = backup_path

  -- If no specific backup path is provided
  if not backup_to_use then
    -- First try to use the latest backup from current session
    if latest_backup_file ~= '' then
      backup_to_use = latest_backup_file
    else
      -- Otherwise, find the most recent backup file in the backup directory
      local files = vim.fn.glob(backup_dir .. '*.json', true, true)
      table.sort(files, function(a, b)
        return a > b
      end) -- Sort descending to get newest first

      if #files > 0 then
        backup_to_use = files[1]
        print('✅ Using most recent backup: ' .. vim.fn.fnamemodify(backup_to_use, ':t'))
      else
        vim.api.nvim_err_writeln('❌ Error: No backup files found!')
        return
      end
    end
  else
    -- If backup_path was provided but doesn't start with '/', prepend backup_dir
    if not backup_path:match('^/') and not backup_path:match('^~') then
      backup_to_use = backup_dir .. backup_path
    end
  end

  local file = io.open(backup_to_use, 'r')
  if not file then
    vim.api.nvim_err_writeln('❌ Error: No backup file found at ' .. backup_to_use)
    return
  end

  local content = file:read('*a')
  file:close()
  local plugin_versions = vim.fn.json_decode(content)

  -- Use vim.ui.input for confirmation instead of io.read
  vim.ui.input({
    prompt = 'Are you sure you want to restore plugins from ' .. backup_to_use .. '? (y/n): ',
  }, function(input)
    if not input or input:lower() ~= 'y' then
      print('Restore canceled.')
      return
    end

    local lazy = require('lazy')
    local plugins_to_restore = {}

    -- Determine which plugins to restore
    if not args or #args == 0 then
      -- Restore all plugins from backup
      for name, version in pairs(plugin_versions) do
        table.insert(plugins_to_restore, { name = name, version = version })
      end
    else
      -- Restore only specified plugins
      for _, plugin_name in ipairs(args) do
        local version = plugin_versions[plugin_name]
        if version then
          table.insert(plugins_to_restore, { name = plugin_name, version = version })
        else
          vim.api.nvim_err_writeln('❌ No backup found for plugin: ' .. plugin_name)
        end
      end
    end

    -- Actually restore the plugins
    for _, plugin_info in ipairs(plugins_to_restore) do
      local plugin_name = plugin_info.name
      local target_version = plugin_info.version

      -- SANDBOXED: Use sandboxed plugin directory
      local plugin_dir = plugin_root .. '/' .. plugin_name
      
      if vim.fn.isdirectory(plugin_dir) == 1 then
        -- First check if the commit exists in the repository
        local check_cmd = string.format('cd %s && git cat-file -e %s', vim.fn.shellescape(plugin_dir), vim.fn.shellescape(target_version))
        local check_result = vim.fn.system(check_cmd)
        
        if vim.v.shell_error == 0 then
          -- Commit exists, proceed with checkout
          local git_cmd = string.format('cd %s && git checkout %s', vim.fn.shellescape(plugin_dir), vim.fn.shellescape(target_version))
          local result = vim.fn.system(git_cmd)
          if vim.v.shell_error == 0 then
            print('✅ Restored plugin: ' .. plugin_name .. ' to ' .. target_version:sub(1, 7))
          else
            vim.api.nvim_err_writeln('❌ Failed to restore ' .. plugin_name .. ': ' .. result)
          end
        else
          -- Commit doesn't exist, try to fetch and then checkout
          print('⚠️  Commit ' .. target_version:sub(1, 7) .. ' not found locally for ' .. plugin_name .. ', attempting to fetch...')
          
          local fetch_cmd = string.format('cd %s && git fetch --all', vim.fn.shellescape(plugin_dir))
          vim.fn.system(fetch_cmd)
          
          -- Try checkout again after fetch
          local git_cmd = string.format('cd %s && git checkout %s', vim.fn.shellescape(plugin_dir), vim.fn.shellescape(target_version))
          local result = vim.fn.system(git_cmd)
          if vim.v.shell_error == 0 then
            print('✅ Restored plugin: ' .. plugin_name .. ' to ' .. target_version:sub(1, 7) .. ' (after fetch)')
          else
            vim.api.nvim_err_writeln('❌ Failed to restore ' .. plugin_name .. ' even after fetch. Commit may not exist: ' .. target_version:sub(1, 7))
            print('ℹ️  This could happen with sample/fake commit hashes in test backups')
          end
        end
      else
        vim.api.nvim_err_writeln('❌ Plugin not found or not installed: ' .. plugin_name .. ' at ' .. plugin_dir)
      end
    end

    print('🔄 Restart Neovim to ensure all changes take effect.')
  end)
end

-- List available backups
function LazyManager.list_backups()
  local files = vim.fn.glob(backup_dir .. '*.json', true, true)
  if #files == 0 then
    vim.api.nvim_err_writeln('❌ No backups found in ' .. backup_dir)
    return
  end

  -- Sort files by name (which includes the timestamp) in descending order
  table.sort(files, function(a, b)
    return a > b
  end)

  print('✅ Available backups (most recent first):')
  for i, file in ipairs(files) do
    print(i .. '. ' .. vim.fn.fnamemodify(file, ':t'))
  end
end

-- Debug function to show current plugin directories
function LazyManager.debug_paths()
  local lazy = require('lazy')
  print('🔍 LazyManager Debug - Plugin Paths:')
  print('📁 Backup dir: ' .. backup_dir)
  print('🔌 Plugin root: ' .. plugin_root)
  print('')
  print('📦 Installed plugins:')
  
  for name, plugin in pairs(lazy.plugins()) do
    local sandboxed_dir = plugin_root .. '/' .. name
    local actual_dir = plugin.dir or 'N/A'
    local exists = vim.fn.isdirectory(sandboxed_dir) == 1 and '✅' or '❌'
    
    print(string.format('  %s %s', exists, name))
    print(string.format('    Lazy dir: %s', actual_dir))
    print(string.format('    Sandbox:  %s', sandboxed_dir))
  end
end

-- Getter functions to expose paths for use in init.lua
function LazyManager.get_backup_dir()
  return backup_dir
end

function LazyManager.get_plugin_root()
  return plugin_root
end

function LazyManager.setup(opts)
  -- Register commands
  vim.api.nvim_create_user_command('LazyBackup', LazyManager.backup_plugins, {})

  vim.api.nvim_create_user_command('LazyRestore', function(input)
    LazyManager.restore_plugins(vim.split(input.args, ' '))
  end, { nargs = '*' })

  vim.api.nvim_create_user_command('LazyListBackups', LazyManager.list_backups, {})

  vim.api.nvim_create_user_command('LazyRestoreFile', function(input)
    local args = vim.split(input.args, ' ')
    local file_path = table.remove(args, 1)
    LazyManager.restore_plugins(args, file_path)
  end, { 
    nargs = '+', 
    complete = function(ArgLead, CmdLine, CursorPos)
      -- Custom completion that shows backup files without full path
      local files = vim.fn.glob(backup_dir .. '*.json', true, true)
      local completions = {}
      for _, file in ipairs(files) do
        local basename = vim.fn.fnamemodify(file, ':t')
        if basename:find(ArgLead, 1, true) == 1 then
          table.insert(completions, basename)
        end
      end
      return completions
    end 
  })

  -- Debug command to check paths
  vim.api.nvim_create_user_command('LazyDebugPaths', LazyManager.debug_paths, {})

  -- Register auto-backup when Lazy sync is run
  vim.api.nvim_create_autocmd('User', {
    pattern = 'LazySync',
    callback = function()
      -- Wait for sync to complete before backing up
      vim.defer_fn(function()
        LazyManager.backup_plugins()
      end, 1000) -- Wait 1 second after sync completes
    end,
  })

  print('LazyManager setup complete!')
end

return LazyManager
EOF

# Create a minimal Neovim configuration that uses the sandboxed environment
cat > "$NVIM_CONFIG_DIR/init.lua" << 'EOF'
-- Minimal Neovim config for testing LazyManager
-- SANDBOXED: All paths use the sandbox environment

-- Set up sandbox-specific paths
local sandbox_data = vim.fn.expand('~') .. '/nvim-lazy-manager-test/.local/share/nvim'
local sandbox_config = vim.fn.expand('~') .. '/nvim-lazy-manager-test/.config/nvim'

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
local lazy_manager = require('lazymanager')
lazy_manager.setup()

-- Add helpful keymaps for testing
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
print("📁 Backup directory: " .. lazy_manager.get_backup_dir())
print("🔌 Plugin directory: " .. lazy_manager.get_plugin_root())
EOF

# Create the backup directory with sample backup files
mkdir -p "$NVIM_CONFIG_DIR/lazy-plugin-backups"

# Create sample backup files for testing
cat > "$NVIM_CONFIG_DIR/lazy-plugin-backups/2024-01-15-1430-lazy-plugin-backup.json" << 'EOF'
{
  "plenary.nvim": "4f71c0c4a196",
  "which-key.nvim": "7ccf476ebe05",
  "lualine.nvim": "2248ef48b877",
  "nvim-web-devicons": "a1e6268779ca",
  "gitsigns.nvim": "af0f583cd352",
  "nvim-autopairs": "0f04d78619cc"
}
EOF

cat > "$NVIM_CONFIG_DIR/lazy-plugin-backups/2024-01-16-0900-lazy-plugin-backup.json" << 'EOF'
{
  "plenary.nvim": "5f71c0c4a197",
  "which-key.nvim": "8ccf476ebe06", 
  "lualine.nvim": "3248ef48b878",
  "nvim-web-devicons": "b1e6268779cb",
  "gitsigns.nvim": "bf0f583cd352",
  "nvim-autopairs": "1f04d78619cc"
}
EOF

cat > "$NVIM_CONFIG_DIR/lazy-plugin-backups/2024-01-17-1200-lazy-plugin-backup.json" << 'EOF'
{
  "plenary.nvim": "6f71c0c4a198",
  "which-key.nvim": "9ccf476ebe07",
  "lualine.nvim": "4248ef48b879", 
  "nvim-web-devicons": "c1e6268779cc",
  "gitsigns.nvim": "cf0f583cd353",
  "nvim-autopairs": "2f04d78619cd"
}
EOF

# Create test script with proper environment setup
cat > "$SANDBOX_DIR/test_lazy_manager.sh" << 'EOF'
#!/bin/bash

echo "🧪 LazyManager Test Script"
echo "========================="

cd "$(dirname "$0")"

# Set environment to use sandbox
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

echo "Press Enter to launch Neovim..."
read

nvim -u "$XDG_CONFIG_HOME/nvim/init.lua"
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
echo ""
echo "🎯 Ready to test all LazyManager functionality safely!"
