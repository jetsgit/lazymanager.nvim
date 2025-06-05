local Backup = require("lazymanager.backup")
local UI = require("lazymanager.ui")
-- Define LazyManager as a module

local LazyManager = {}
-- Delegate backup functions to the backup module
LazyManager.backup_plugins = Backup.backup_plugins
LazyManager.get_backup_dir = Backup.get_backup_dir

-- Lazymanager-path
-- local backup_dir = vim.fn.expand("~") .. "/.config/nvim/lazy-plugin-backups/"
local backup_dir = LazyManager.get_backup_dir()
-- Generate timestamp-based backup filename
local function get_backup_filename()
	local date = os.date("%Y-%m-%d-%H%M")
	return backup_dir .. date .. "-lazy-plugin-backup.json"
end

-- Store most recent backup file path for restore function
LazyManager.latest_backup_file = ""

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

-- function LazyManager.backup_plugins()
-- 	-- Ensure backup directory exists
-- 	if vim.fn.isdirectory(backup_dir) == 0 then
-- 		vim.fn.mkdir(backup_dir, "p")
-- 	end
-- 	local lazy = require("lazy")
-- 	local plugin_versions = {}

-- 	for _, plugin in pairs(lazy.plugins()) do
-- 		local name = plugin.name
-- 		local dir = plugin.dir

-- 		if dir and vim.fn.isdirectory(dir) == 1 then
-- 			-- Use git to get the current commit hash
-- 			local commit = vim.fn.system("cd " .. vim.fn.shellescape(dir) .. " && git rev-parse HEAD"):gsub("\n", "")
-- 			if commit and #commit > 0 and not commit:match("fatal") then
-- 				-- Truncate the commit hash to 12 digits
-- 				plugin_versions[name] = commit:sub(1, 12)
-- 			else
-- 				plugin_versions[name] = plugin.commit or plugin.version or "latest"
-- 			end
-- 		else
-- 			plugin_versions[name] = plugin.commit or plugin.version or "latest"
-- 		end
-- 	end

-- Use timestamped backup file
-- LazyManager.latest_backup_file = get_backup_filename()
-- local json = json_pretty(plugin_versions, 2)
-- local file = io.open(LazyManager.latest_backup_file, "w")

-- if file then
-- 	file:write(json)
-- 	file:close()
-- 	print("✅ Plugins backed up to: " .. LazyManager.latest_backup_file)
-- else
-- 	vim.api.nvim_err_writeln("❌ Error: Could not create backup file.")
-- end

function LazyManager.restore_plugins(args, backup_path)
	-- Ensure backup directory exists
	if vim.fn.isdirectory(backup_dir) == 0 then
		vim.fn.mkdir(backup_dir, "p")
	end
	local backup_to_use = backup_path

	-- If no specific backup path is provided
	if not backup_to_use then
		-- First try to use the latest backup from current session
		if LazyManager.latest_backup_file ~= "" then
			backup_to_use = LazyManager.latest_backup_file
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
	UI.input({ prompt = prompt_msg }, function(input)
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
			do
				local plugin_name = plugin_info.name
				local target_version = plugin_info.version

				-- Use Lazy.nvim's plugin metadata to get the actual directory (array search for sandbox compatibility)
				local plugin_data = nil
				for _, p in pairs(lazy.plugins()) do
					if p.name == plugin_name then
						plugin_data = p
						break
					end
				end
				if not plugin_data then
					vim.api.nvim_err_writeln("❌ Plugin not installed: " .. plugin_name)
					break -- skip to next plugin
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
			end
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
-- function LazyManager.get_backup_dir()
-- 	return backup_dir
-- end

function LazyManager.telescope_restore(callback)
	local ok, telescope = pcall(require, "telescope.builtin")
	if not ok then
		vim.api.nvim_err_writeln("❌ Telescope is not installed!")
		return
	end
	-- Only show backups in the sandbox backup_dir
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
		end

		local lazy = require("lazy")
		local plugins = {}
		for _, plugin in pairs(lazy.plugins()) do
			table.insert(plugins, plugin.name)
		end

		if #args == 0 then
			UI.telescope_plugin_picker(plugins, function(selected)
				if selected then
					LazyManager.telescope_plugin_backups(selected)
				end
			end)
			return
		end

		if #args == 1 then
			LazyManager.telescope_plugin_backups(args[1])
			return
		end

		if #args > 1 then
			local files = vim.fn.glob(backup_dir .. "*.json", true, true)
			if #files == 0 then
				vim.api.nvim_err_writeln("❌ No backups found in" .. backup_dir)
				return
			end
			table.sort(files, function(a, b)
				return a > b
			end)
			UI.telescope_backup_picker(
				files,
				"Select Lazy.nvim Backup to Restore (MULTI-PLUGIN)",
				function(selected_backup)
					LazyManager.restore_plugins(args, selected_backup)
				end
			)
			return
		end
	end, {
		nargs = "*",
		complete = function(ArgLead, CmdLine, CursorPos)
			local lazy = require("lazy")
			local completions = {}
			for _, plugin in pairs(lazy.plugins()) do
				local name = plugin.name
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
		local file_path = args[1]
		if not file_path or file_path == "" then
			-- If Telescope is available, open a fuzzy picker for backup files
			if pcall(require, "telescope.builtin") then
				local files = vim.fn.glob(backup_dir .. "*.json", true, true)
				if #files == 0 then
					vim.api.nvim_err_writeln("❌ No backups found in " .. backup_dir)
					return
				end
				require("telescope.pickers")
					.new({}, {
						prompt_title = "Select Lazy.nvim Backup to Restore (ALL plugins)",
						finder = require("telescope.finders").new_table({ results = files }),
						sorter = require("telescope.config").values.generic_sorter({}),
						attach_mappings = function(_, _)
							local actions = require("telescope.actions")
							local action_state = require("telescope.actions.state")
							actions.select_default:replace(function(prompt_bufnr)
								actions.close(prompt_bufnr)
								local selection = action_state.get_selected_entry()
								if selection and selection[1] then
									LazyManager.restore_file_full(selection[1])
								end
							end)
							return true
						end,
					})
					:find()
				return
			else
				vim.api.nvim_err_writeln("❌ Please specify a backup file.")
				return
			end
		end
		LazyManager.restore_file_full(file_path)
	end, {
		nargs = "?",
		complete = function(ArgLead, CmdLine, CursorPos)
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

-- Phase 2: Telescope picker for backups containing the selected plugin
function LazyManager.telescope_plugin_backups(plugin_name)
	local files = vim.fn.glob(backup_dir .. "*.json", true, true)
	if #files == 0 then
		vim.api.nvim_err_writeln("❌ No backups found in " .. backup_dir)
		return
	end
	local matching = {}
	for _, file in ipairs(files) do
		local f = io.open(file, "r")
		if f then
			local content = f:read("*a")
			f:close()
			local ok, data = pcall(vim.fn.json_decode, content)
			if ok and data and data[plugin_name] then
				table.insert(matching, { file = file, commit = data[plugin_name] })
			end
		end
	end
	if #matching == 0 then
		vim.api.nvim_err_writeln("❌ No backups found for plugin: " .. plugin_name)
		return
	end
	if pcall(require, "telescope.builtin") then
		require("telescope.pickers")
			.new({}, {
				prompt_title = "Select backup for " .. plugin_name,
				finder = require("telescope.finders").new_table({
					results = matching,
					entry_maker = function(entry)
						return {
							value = entry,
							display = vim.fn.fnamemodify(entry.file, ":t"),
							ordinal = vim.fn.fnamemodify(entry.file, ":t"),
						}
					end,
				}),
				previewer = require("telescope.previewers").new_buffer_previewer({
					define_preview = function(self, entry, _)
						local commit = entry.value.commit or "(no commit)"
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {
							"Plugin: " .. plugin_name,
							"Backup: " .. vim.fn.fnamemodify(entry.value.file, ":t"),
							"Commit: " .. commit,
						})
					end,
				}),
				attach_mappings = function(_, _)
					local actions = require("telescope.actions")
					local action_state = require("telescope.actions.state")
					actions.select_default:replace(function(prompt_bufnr)
						actions.close(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						if selection and selection.value and selection.value.file then
							LazyManager.restore_plugins({ plugin_name }, selection.value.file)
						end
					end)
					return true
				end,
			})
			:find()
	else
		-- Fallback: just restore from the most recent matching backup
		table.sort(matching, function(a, b)
			return a.file > b.file
		end)
		LazyManager.restore_plugins({ plugin_name }, matching[1].file)
	end
end

-- Restore all plugins from a specific backup file (no plugin filtering)
function LazyManager.restore_file_full(backup_path)
	if not backup_path or backup_path == "" then
		vim.api.nvim_err_writeln("❌ Please specify a backup file.")
		return
	end
	local backup_to_use = backup_path
	if not backup_to_use:match("^/") and not backup_to_use:match("^~") then
		backup_to_use = backup_dir .. backup_to_use
	end
	local file = io.open(backup_to_use, "r")
	if not file then
		vim.api.nvim_err_writeln("❌ Error: No backup file found at " .. backup_to_use)
		return
	end
	local content = file:read("*a")
	file:close()
	local ok, plugin_versions = pcall(vim.fn.json_decode, content)
	if not ok then
		vim.api.nvim_err_writeln("❌ Error: Invalid JSON in backup file")
		return
	end
	local backup_filename = vim.fn.fnamemodify(backup_to_use, ":t")
	local prompt_msg = "Are you sure you want to restore ALL plugins from " .. backup_filename .. "? (y/n): "
	UI.input({ prompt = prompt_msg }, function(input)
		if not input or input:lower() ~= "y" then
			print("Restore canceled.")
			return
		end
		local lazy = require("lazy")
		local plugins_to_restore = {}
		for name, version in pairs(plugin_versions) do
			table.insert(plugins_to_restore, { name = name, version = version })
		end
		print("🔄 Restoring all " .. #plugins_to_restore .. " plugins from backup...")
		for _, plugin_info in ipairs(plugins_to_restore) do
			local plugin_name = plugin_info.name
			local target_version = plugin_info.version
			local plugin_data = nil
			for _, p in pairs(lazy.plugins()) do
				if p.name == plugin_name then
					plugin_data = p
					break
				end
			end
			if not plugin_data then
				vim.api.nvim_err_writeln("❌ Plugin not installed: " .. plugin_name)
				break
			end
			local plugin_dir = plugin_data.dir
			if vim.fn.isdirectory(plugin_dir) == 1 then
				local check_cmd = string.format(
					"cd %s && git cat-file -e %s",
					vim.fn.shellescape(plugin_dir),
					vim.fn.shellescape(target_version)
				)
				vim.fn.system(check_cmd)
				if vim.v.shell_error == 0 then
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
					print(
						"⚠️  Commit "
							.. target_version:sub(1, 7)
							.. " not found locally for "
							.. plugin_name
							.. ", attempting to fetch..."
					)
					local fetch_cmd = string.format("cd %s && git fetch --all", vim.fn.shellescape(plugin_dir))
					vim.fn.system(fetch_cmd)
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
		end
		print("🔄 Restart Neovim to ensure all changes take effect.")
	end)
end

return LazyManager
