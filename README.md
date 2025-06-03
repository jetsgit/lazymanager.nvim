# LazyManager

A Neovim plugin for backing up and restoring Lazy.nvim plugin versions. LazyManager creates timestamped backups of your plugin commit hashes and allows you to restore specific plugins or your entire plugin set to previous versions.

## Features

- **Automatic Backups**: Automatically backs up plugin versions after every `:Lazy sync`
- **Manual Backups**: Create backups on demand with `:LazyBackup`
- **Selective Restore**: Restore specific plugins or all plugins from any backup
- **Smart Restore Logic**: Automatically fetches commits if not available locally
- **Timestamped Backups**: Each backup is named with a timestamp for easy identification
- **Tab Completion**: Full tab completion for plugin names and backup files
- **Confirmation Prompts**: Safe restore operations with user confirmation

## Installation

### Using Lazy.nvim

Add LazyManager to your Lazy.nvim configuration

```lua
{
  "jetsgit/lazymanager.nvim",
  config = function()
    require("lazymanager").setup()
  end,
}
```

### Manual Installation

1. Clone or download the LazyManager code
2. Save it as `lazymanager.lua` in your Neovim Lua directory
3. Add to your `init.lua`:

```lua
require("lazymanager").setup()
```

## Configuration

Recommended LazyManager configuration.
This will give you fuzzy finding capabilities with Telescope and FZF for plugin management.
```lua
require("lazy").setup({
  {
    'jetsgit/lazymanager.nvim',
    dependencies = {
      {
        'nvim-telescope/telescope.nvim',
        dependencies = {
          'nvim-lua/plenary.nvim',
          {
            'nvim-telescope/telescope-fzf-native.nvim',
            build = 'make', -- Compiles the C code for optimal fuzzy matching performance
          },
        },
        config = function()
          require('telescope').setup {}
          require('telescope').load_extension 'fzf'
        end,
      },
    },
    config = function()
      require('lazymanager').setup()
    end,
  },
})
```
## Suggested Key Bindings
```lua
vim.keymap.set('n', '<leader>lb', '<cmd>LazyBackup<cr>', { desc = 'Backup plugins' })
vim.keymap.set('n', '<leader>lr', '<cmd>LazyRestore<cr>', { desc = 'Restore plugins' })
vim.keymap.set('n', '<leader>ll', '<cmd>LazyListBackups<cr>', { desc = 'List backups' })
vim.keymap.set('n', '<leader>la', '<cmd>LazyRestoreFile<cr>', { desc = 'Restore entire backup file' })
```
...more, better, faster, stronger, and powerful than ever before!

### Backup Directory

Backups are stored in `~/.config/nvim/lazy-plugin-backups/` by default. The directory will be created automatically if it doesn't exist.

You can access the backup directory path programmatically:

```lua
local backup_dir = require("lazymanager").get_backup_dir()
```

## Commands

### `:LazyBackup`

Creates a timestamped backup of all currently installed plugin versions.

```vim
:LazyBackup
```

**Output**: `✅ Plugins backed up to: ~/.config/nvim/lazy-plugin-backups/2024-01-15-1430-lazy-plugin-backup.json`

### `:LazyRestore`

Restores plugins from backups with flexible syntax options:

```vim
" Restore all plugins from the most recent backup
:LazyRestore

" Restore specific plugins from the most recent backup
:LazyRestore telescope.nvim nvim-treesitter

" Restore all plugins from a specific backup file
:LazyRestore 2024-01-15-1430-lazy-plugin-backup.json

" Restore specific plugins from a specific backup file
:LazyRestore telescope.nvim 2024-01-15-1430-lazy-plugin-backup.json
```

**Features**:
- Tab completion for plugin names and backup files
- User confirmation prompt before restoration
- Automatic git fetch if commits aren't available locally
- Clear progress messages during restoration

### `:LazyListBackups`

Lists all available backup files, sorted by date (most recent first):
```vim
:LazyListBackups
```
**Output**:
```
✅ Available backups (most recent first):
1. 2024-01-15-1430-lazy-plugin-backup.json
2. 2024-01-15-1200-lazy-plugin-backup.json
3. 2024-01-14-0900-lazy-plugin-backup.json
```
### `:LazyRestoreFile`

Alternative restore command:
```vim
" Restore all plugins from specified backup
:LazyRestoreFile 2024-01-15-1430-lazy-plugin-backup.json
```

## How It Works

### Backup Process

1. **Plugin Detection**: Scans all installed Lazy.nvim plugins
2. **Version Capture**: For each plugin, captures the current git commit hash (truncated to 12 characters)
3. **Fallback Handling**: If git commit isn't available, uses the plugin's configured commit, version, or "latest"
4. **JSON Storage**: Saves all plugin versions to a timestamped JSON file

### Restore Process

1. **Backup Selection**: Uses most recent backup unless a specific file is specified
2. **Plugin Filtering**: Restores all plugins or only specified ones
3. **User Confirmation**: Prompts for confirmation before making changes
4. **Git Operations**: 
   - Checks if target commit exists locally
   - Fetches from remote if commit is missing
   - Checks out the specific commit hash
5. **Error Handling**: Provides clear error messages for failed operations

### Automatic Backups

LazyManager automatically creates backups whenever you run `:Lazy sync`. This happens through a Neovim autocmd that triggers 1 second after the sync completes, ensuring all changes are captured.

## Backup File Format

Backup files are JSON objects mapping plugin names to commit hashes:

```json
{
  "telescope.nvim": "abc123def456",
  "nvim-treesitter": "def456ghi789",
  "lazy.nvim": "ghi789jkl012"
}
```

## Use Cases

### Plugin Update Recovery

If a plugin update breaks your setup:

1. Check what backups are available: `:LazyListBackups`
2. Restore the problematic plugin: `:LazyRestore plugin-name`
3. Restart Neovim

### Full Environment Rollback

To revert your entire plugin environment:

1. Find the backup from before the issues: `:LazyListBackups`
2. Restore all plugins: `:LazyRestore backup-filename.json`
3. Restart Neovim

### Selective Plugin Management

To test different versions of specific plugins:

1. Create a backup before experimenting: `:LazyBackup`
2. Update or modify plugins as needed
3. Restore specific plugins if needed: `:LazyRestore plugin1 plugin2`

## Troubleshooting

### "Plugin not installed" Error

This means the plugin exists in the backup but isn't currently installed via Lazy.nvim. Install the plugin first, then restore its version.

### "Commit may not exist" Error

This can happen if:
- The backup contains invalid commit hashes (e.g., from test data)
- The plugin's git repository has been force-pushed or rebased
- The plugin has been moved to a different repository

**Solution**: Check the plugin's git history or install the latest version.

### Permission Errors

Ensure Neovim has write access to `~/.config/nvim/lazy-plugin-backups/`.

## Requirements

- Neovim with Lua support
- Lazy.nvim plugin manager
- Git (for plugin version detection and restoration)
- Unix-like system (Linux, macOS) for shell commands

## Sandbox

The sandbox allows you to explore features like plugin installation, listing installed plugins, and restoring plugins—all within an isolated environment that won’t interfere with your main Neovim configuration.

### Setup

1. In the `test/` directory, run:
    ```sh
    ./generate-sandbox-test.sh
    ```
2. Change to the sandbox directory:
    ```sh
    cd ~/nvim-lazy-manager-test
    ```
3. Install test plugins by running:
    ```sh
    ./test_lazy_manager.sh
    ```
4. In Neovim, verify you are using isolated paths by running:
    ```lua
    :LazyDebugPaths
    ```

### Usage

- Try out all LazyManager features safely.
- To check for existing and newly created backups, run:
    ```sh
    ./status.sh
    ```
    in `~/nvim-lazy-manager-test`.
- List all backups and their contents with:
    ```sh
    ./verify_backups.sh
    ```
- When finished, remove the sandbox with:
    ```sh
    ./cleanup.sh
    ```


## License

MIT License

Copyright (c) 2025 Jerry Thompson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

