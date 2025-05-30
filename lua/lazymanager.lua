-- Define LazyManager as a module
LazyManager = {}

-- Production paths
local backup_dir = vim.fn.expand("~") .. "/.config/nvim/lazy-plugin-backups/"

if vim.fn.isdirectory(backup_dir) == 0 then
	vim.fn.mkdir(backup_dir, "p")
end

-- Generate timestamp-based backup filename
local function get_backup_filename()
	local date = os.date("%Y-%m-%d-%H%M")
	return backup_dir .. date .. "-lazy-plugin-backup.json"
end

-- Store most recent backup file path for restore function
local latest_backup_file = ""

-- Helper function to pretty-print a Lua table as indented JSON
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

function LazyManager.backup_plugins()
	local lazy = require("lazy")
	local plugin_versions = {}

	for _, plugin in pairs(lazy.plugins()) do
		local name = plugin.name
		local dir = plugin.dir

		if dir and vim.fn.isdirectory(dir) == 1 then
			-- Use git to get the current commit hash
			local commit = vim.fn.system("cd " .. vim.fn.shellescape(dir) .. " && git rev-parse HEAD"):gsub("\n", "")
			if commit and #commit > 0 and not commit:match("fatal") then
				-- Truncate the commit hash to 12 digits
				plugin_versions[name] = commit:sub(1, 12)
			else
				plugin_versions[name] = plugin.commit or plugin.version or "latest"
			end
		else
			plugin_versions[name] = plugin.commit or plugin.version or "latest"
		end
	end

	-- Use timestamped backup file
	latest_backup_file = get_backup_filename()
	local json = json_pretty(plugin_versions, 2)
	local file = io.open(latest_backup_file, "w")

	if file then
		file:write(json)
		file:close()
		print("✅ Plugins backed up to: " .. latest_backup_file)
	else
		vim.api.nvim_err_writeln("❌ Error: Could not create backup file.")
	end
end

function LazyManager.restore_plugins(args, backup_path)
	local backup_to_use = backup_path

	-- If no specific backup path is provided
	if not backup_to_use then
		-- First try to use the latest backup from current session
		if latest_backup_file ~= "" then
			backup_to_use = latest_backup_file
		else
			-- Otherwise, find the most recent backup file in the backup directory
			local files = vim.fn.glob(backup_dir .. "*.json", true, true)
			table.sort(files, function(a, b)
				return a > b
			end) -- Sort descending to get newest first

			if #files > 0 then
				backup_to_use = files[1]
				print("✅ Using most recent backup: " .. vim.fn.fnamemodify(backup_to_use, ":t"))
			else
				vim.api.nvim_err_writeln("❌ Error: No backup files found!")
				return
			end
		end
	else
		-- If backup_path was provided but doesn't start with '/', prepend backup_dir
		if not backup_path:match("^/") and not backup_path:match("^~") then
			backup_to_use = backup_dir .. backup_path
		end
	end

	local file = io.open(backup_to_use, "r")
	if not file then
		vim.api.nvim_err_writeln("❌ Error: No backup file found at " .. backup_to_use)
		return
	end

	local content = file:read("*a")
	file:close()

	-- Add error handling for JSON decode
	local ok, plugin_versions = pcall(vim.fn.json_decode, content)
	if not ok then
		vim.api.nvim_err_writeln("❌ Error: Invalid JSON in backup file")
		return
	end

	-- Create the confirmation prompt message
	local backup_filename = vim.fn.fnamemodify(backup_to_use, ":t")
	local prompt_msg = "Are you sure you want to restore plugins from " .. backup_filename .. "? (y/n): "

	-- Use vim.ui.input for confirmation
	vim.ui.input({
		prompt = prompt_msg,
	}, function(input)
		-- Handle case where user cancels (input is nil) or says no
		if not input or input:lower() ~= "y" then
			print("Restore canceled.")
			return
		end

		local lazy = require("lazy")
		local plugins_to_restore = {}

		-- Determine which plugins to restore properly
		if not args or #args == 0 or (args and #args == 1 and args[1] == "") then
			-- Restore all plugins from backup
			for name, version in pairs(plugin_versions) do
				table.insert(plugins_to_restore, { name = name, version = version })
			end
			print("🔄 Restoring all " .. #plugins_to_restore .. " plugins from backup...")
		else
			-- Restore only specified plugins
			for _, plugin_name in ipairs(args) do
				if plugin_name and plugin_name ~= "" then -- Skip empty strings
					local version = plugin_versions[plugin_name]
					if version then
						table.insert(plugins_to_restore, { name = plugin_name, version = version })
					else
						vim.api.nvim_err_writeln("❌ No backup found for plugin: " .. plugin_name)
					end
				end
			end
			print("🔄 Restoring " .. #plugins_to_restore .. " specified plugins...")
		end

		-- Actually restore the plugins
		for _, plugin_info in ipairs(plugins_to_restore) do
			local plugin_name = plugin_info.name
			local target_version = plugin_info.version

			-- Find the plugin directory
			local plugin_data = lazy.plugins()[plugin_name]
			if not plugin_data then
				vim.api.nvim_err_writeln("❌ Plugin not installed: " .. plugin_name)
				goto continue
			end

			local plugin_dir = plugin_data.dir

			if vim.fn.isdirectory(plugin_dir) == 1 then
				-- First check if the commit exists in the repository
				local check_cmd = string.format(
					"cd %s && git cat-file -e %s",
					vim.fn.shellescape(plugin_dir),
					vim.fn.shellescape(target_version)
				)
				local check_result = vim.fn.system(check_cmd)

				if vim.v.shell_error == 0 then
					-- Commit exists, proceed with checkout
					local git_cmd = string.format(
						"cd %s && git checkout %s",
						vim.fn.shellescape(plugin_dir),
						vim.fn.shellescape(target_version)
					)
					local result = vim.fn.system(git_cmd)
					if vim.v.shell_error == 0 then
						print("✅ Restored plugin: " .. plugin_name .. " to " .. target_version:sub(1, 7))
					else
						vim.api.nvim_err_writeln("❌ Failed to restore " .. plugin_name .. ": " .. result)
					end
				else
					-- Commit doesn't exist, try to fetch and then checkout
					print(
						"⚠️  Commit "
							.. target_version:sub(1, 7)
							.. " not found locally for "
							.. plugin_name
							.. ", attempting to fetch..."
					)

					local fetch_cmd = string.format("cd %s && git fetch --all", vim.fn.shellescape(plugin_dir))
					vim.fn.system(fetch_cmd)

					-- Try checkout again after fetch
					local git_cmd = string.format(
						"cd %s && git checkout %s",
						vim.fn.shellescape(plugin_dir),
						vim.fn.shellescape(target_version)
					)
					local result = vim.fn.system(git_cmd)
					if vim.v.shell_error == 0 then
						print(
							"✅ Restored plugin: "
								.. plugin_name
								.. " to "
								.. target_version:sub(1, 7)
								.. " (after fetch)"
						)
					else
						vim.api.nvim_err_writeln(
							"❌ Failed to restore "
								.. plugin_name
								.. " even after fetch. Commit may not exist: "
								.. target_version:sub(1, 7)
						)
					end
				end
			else
				vim.api.nvim_err_writeln("❌ Plugin directory not found: " .. plugin_name .. " at " .. plugin_dir)
			end

			::continue::
		end

		print("🔄 Restart Neovim to ensure all changes take effect.")
	end)
end

-- List available backups
function LazyManager.list_backups()
	local files = vim.fn.glob(backup_dir .. "*.json", true, true)
	if #files == 0 then
		vim.api.nvim_err_writeln("❌ No backups found in " .. backup_dir)
		return
	end

	-- Sort files by name (which includes the timestamp) in descending order
	table.sort(files, function(a, b)
		return a > b
	end)

	print("✅ Available backups (most recent first):")
	for i, file in ipairs(files) do
		print(i .. ". " .. vim.fn.fnamemodify(file, ":t"))
	end
end

-- Getter function to expose backup directory path for use in init.lua
function LazyManager.get_backup_dir()
	return backup_dir
end

function LazyManager.telescope_restore(callback)
	local ok, telescope = pcall(require, "telescope.builtin")
	if not ok then
		vim.api.nvim_err_writeln("❌ Telescope is not installed!")
		return
	end
	local files = vim.fn.glob(backup_dir .. "*.json", true, true)
	if #files == 0 then
		vim.api.nvim_err_writeln("❌ No backups found in " .. backup_dir)
		return
	end
	table.sort(files, function(a, b)
		return a > b
	end)
	telescope.find_files({
		prompt_title = "Select Lazy.nvim Backup to Restore",
		cwd = backup_dir,
		find_command = { "ls" },
		attach_mappings = function(_, _)
			local actions = require("telescope.actions")
			local action_state = require("telescope.actions.state")
			actions.select_default:replace(function(prompt_bufnr)
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection and selection[1] then
					if callback then
						callback(selection[1])
					else
						LazyManager.restore_plugins({}, selection[1])
					end
				end
			end)
			return true
		end,
		sorter = require("telescope.sorters").get_fuzzy_file(),
	})
end

function LazyManager.setup(opts)
	-- Register commands
	vim.api.nvim_create_user_command("LazyBackup", LazyManager.backup_plugins, {})

	vim.api.nvim_create_user_command("LazyRestore", function(input)
		local args = {}
		local backup_file = nil

		if input.args and input.args ~= "" then
			args = vim.split(input.args, " ")
			if #args > 0 and args[#args]:match("%.json$") then
				backup_file = table.remove(args)
			end
			if #args == 0 and backup_file then
				LazyManager.restore_plugins({}, backup_file)
			else
				LazyManager.restore_plugins(args, backup_file)
			end
		else
			-- No arguments: use Telescope for interactive selection if available
			local ok, _ = pcall(require, "telescope.builtin")
			if ok then
				LazyManager.telescope_restore(function(selected_backup)
					LazyManager.restore_plugins({}, selected_backup)
				end)
			else
				LazyManager.restore_plugins({})
			end
		end
	end, {
		nargs = "*",
		complete = function(ArgLead, CmdLine, CursorPos)
			local lazy = require("lazy")
			local completions = {}

			-- Fix: lazy.plugins() returns an array of plugin objects, not a hash table
			for _, plugin in pairs(lazy.plugins()) do
				local name = plugin.name -- Get the actual plugin name from the plugin object
				if name and name:find(ArgLead, 1, true) == 1 then
					table.insert(completions, name)
				end
			end

			local files = vim.fn.glob(backup_dir .. "*.json", true, true)
			for _, file in ipairs(files) do
				local basename = vim.fn.fnamemodify(file, ":t")
				if basename:find(ArgLead, 1, true) == 1 then
					table.insert(completions, basename)
				end
			end

			return completions
		end,
	})

	vim.api.nvim_create_user_command("LazyListBackups", LazyManager.list_backups, {})

	-- Keep LazyRestoreFile as legacy command for backwards compatibility
	vim.api.nvim_create_user_command("LazyRestoreFile", function(input)
		local args = vim.split(input.args, " ")
		local file_path = table.remove(args, 1)
		LazyManager.restore_plugins(args, file_path)
	end, {
		nargs = "+",
		complete = function(ArgLead, CmdLine, CursorPos)
			-- Custom completion that shows backup files without full path
			local files = vim.fn.glob(backup_dir .. "*.json", true, true)
			local completions = {}
			for _, file in ipairs(files) do
				local basename = vim.fn.fnamemodify(file, ":t")
				if basename:find(ArgLead, 1, true) == 1 then
					table.insert(completions, basename)
				end
			end
			return completions
		end,
	})

	-- Register auto-backup when Lazy sync is run
	vim.api.nvim_create_autocmd("User", {
		pattern = "LazySync",
		callback = function()
			-- Wait for sync to complete before backing up
			vim.defer_fn(function()
				LazyManager.backup_plugins()
			end, 1000) -- Wait 1 second after sync completes
		end,
	})

	print("LazyManager setup complete!")
end

return LazyManager
