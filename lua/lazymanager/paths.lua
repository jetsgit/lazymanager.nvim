-- Lazymanager-path
local M = {}

-- Environment detection for sandbox
local is_sandbox = vim.env.LAZYMANAGER_SANDBOX == "1"
	or vim.fn.isdirectory(vim.fn.expand("~") .. "/nvim-lazy-manager-test") == 1

if is_sandbox then
	M.backup_dir = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/"
	-- Debug helpers from debug-paths.lua
	local sandbox_data = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.local/share/nvim"
	local backup_dir = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/"
	local plugin_root = sandbox_data .. "/lazy_plugins"
	function LazyManager_debug_paths()
		local lazy = require("lazy")
		print("Sandbox mode is active!")
		print("🔍 LazyManager Debug - Plugin Paths:")
		print("📁 Backup dir: " .. backup_dir)
		print("🔌 Plugin root: " .. plugin_root)
		print("")
		print("📦 Installed plugins:")
		for _, plugin in pairs(lazy.plugins()) do
			local name = plugin.name
			local sandboxed_dir = plugin_root .. "/" .. name
			local actual_dir = plugin.dir or "N/A"
			local exists = vim.fn.isdirectory(sandboxed_dir) == 1 and "✅" or "❌"
			print(string.format("  %s %s", exists, name))
			print(string.format("    Lazy dir: %s", actual_dir))
			print(string.format("    Sandbox:  %s", sandboxed_dir))
		end
	end
else
	print("LazyManager loaded in normal mode.")
	M.backup_dir = vim.fn.expand("~") .. "/.config/nvim/lazy-plugin-backups/"
end

function M.get_backup_dir()
	return M.backup_dir
end
return M
