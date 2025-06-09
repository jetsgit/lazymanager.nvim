--- Backup module for LazyManager.
-- @module lazymanager.backup
-- Handles plugin version backup creation and backup directory management.

local M = {}
local paths = require("lazymanager.paths")

--- Generate a timestamped backup filename.
-- @return string: The full path to the backup file.
local function get_backup_filename()
	local date = os.date("%Y-%m-%d-%H%M")
	return paths.get_backup_dir() .. date .. "-lazy-plugin-backup.json"
end

--- Pretty-print a Lua table as indented JSON.
-- @param tbl table: The table to pretty-print.
-- @param indent number: Indentation level (default 2).
-- @return string: JSON string.
local function json_pretty(tbl, indent)
	indent = indent or 2
	local function quote(str)
		return '"' .. tostring(str):gsub('"', '\\"') .. '"'
	end
	local function is_array(t)
		local i = 0
		for _ in pairs(t) do
			i = i + 1
			if t[i] == nil then
				return false
			end
		end
		return true
	end
	local function dump(t, level)
		level = level or 0
		local pad = string.rep(" ", level * indent)
		if type(t) ~= "table" then
			if type(t) == "string" then
				return quote(t)
			else
				return tostring(t)
			end
		end
		local isarr = is_array(t)
		local items = {}
		for k, v in pairs(t) do
			local key = isarr and "" or (quote(k) .. ": ")
			table.insert(items, pad .. string.rep(" ", indent) .. key .. dump(v, level + 1))
		end
		if isarr then
			return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
		else
			return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
		end
	end
	return dump(tbl, 0)
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
	local json = json_pretty(plugin_versions, 2)
	local file = io.open(backup_file, "w")

	if file then
		file:write(json)
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
