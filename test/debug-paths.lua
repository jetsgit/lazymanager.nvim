local sandbox_data = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.local/share/nvim"
local backup_dir = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/"
local plugin_root = sandbox_data .. "/lazy_plugins"
local backup_dir = vim.fn.expand("~") .. "/nvim-lazy-manager-test/.config/nvim/lazy-plugin-backups/"

-- Debug function to show current plugin directories
function LazyManager.debug_paths()
	local lazy = require("lazy")
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

-- Getter functions to expose paths for use in init.lua
function LazyManager.get_backup_dir()
	return backup_dir
end

function LazyManager.get_plugin_root()
	return plugin_root
end

-- Debug command to check paths
vim.api.nvim_create_user_command("LazyDebugPaths", LazyManager.debug_paths, {})
