--- Backup module for LazyManager.
-- @module lazymanager.backup
-- Handles plugin version backup creation and backup directory management.

local M = {}
local paths = require("lazymanager.paths")
local json = require("lazymanager.utils.json")

--- Generate a timestamped backup filename.
-- @return string: The full path to the backup file.
local function get_backup_filename()
	local date = os.date("%Y-%m-%d-%H%M")
	return paths.get_backup_dir() .. date .. "-lazy-plugin-backup.json"
end

--- Backup all plugins and return the backup file path.
-- @return string|nil: Path to backup file, or nil on error.
function M.backup_plugins()
	if vim.fn.isdirectory(paths.get_backup_dir()) == 0 then
		vim.fn.mkdir(paths.get_backup_dir(), "p")
	end
	local lazy = require("lazy")
	local plugin_versions = {}

	for _, plugin in pairs(lazy.plugins()) do
		local name = plugin.name
		local dir = plugin.dir

		if dir and vim.fn.isdirectory(dir) == 1 then
			local commit = vim.fn.system("cd " .. vim.fn.shellescape(dir) .. " && git rev-parse HEAD"):gsub("\n", "")
			if commit and #commit > 0 and not commit:match("fatal") then
				plugin_versions[name] = commit:sub(1, 12)
			else
				plugin_versions[name] = plugin.commit or plugin.version or "latest"
			end
		else
			plugin_versions[name] = plugin.commit or plugin.version or "latest"
		end
	end

	local backup_file = get_backup_filename()
	local json_str = json.pretty(plugin_versions, 2)
	local file = io.open(backup_file, "w")

	if file then
		file:write(json_str)
		file:close()
		print("✅ Plugins backed up to: " .. backup_file)
		return backup_file
	else
		vim.api.nvim_err_writeln("❌ Error: Could not create backup file.")
		return nil
	end
end

--- Get the backup directory path.
-- @return string: Path to backup directory.
function M.get_backup_dir()
	return paths.get_backup_dir()
end

return M
