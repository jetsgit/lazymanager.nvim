--- Path utilities for LazyManager.
-- @module lazymanager.paths
-- Handles backup directory resolution and sandbox detection.

local M = {}

-- Environment detection for sandbox
local is_sandbox = false
local getenv = vim and vim.env and function(k) return vim.env[k] end or os.getenv
if (vim and vim.env and vim.env.LAZYMANAGER_SANDBOX and tostring(getenv("LAZYMANAGER_SANDBOX")) == "1") or (os.getenv and os.getenv("LAZYMANAGER_SANDBOX") == "1") then
	is_sandbox = true
elseif vim and vim.fn and vim.fn.isdirectory and vim.fn.isdirectory(vim.fn.expand("~") .. "/nvim-lazy-manager-test") == 1 then
	is_sandbox = true
end

if is_sandbox then
	M.backup_dir = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/"
	-- Debug helpers from debug-paths.lua
	local sandbox_data = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.local/share/nvim"
	local backup_dir = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/"
	local plugin_root = sandbox_data .. "/lazy_plugins"
else
	print("LazyManager loaded in normal mode.")
	M.backup_dir = vim.fn.expand("~") .. "/.config/nvim/lazy-plugin-backups/"
end

--- Get the backup directory path.
-- @return string: Path to backup directory.
function M.get_backup_dir()
	return M.backup_dir
end
return M
