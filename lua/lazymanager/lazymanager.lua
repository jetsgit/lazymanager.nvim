local Backup = require("lazymanager.backup")
local ui = require("lazymanager.ui")
local git = require("lazymanager.git")
local json_utils = require("lazymanager.utils.json")

-- Define LazyManager as a module

LazyManager = {}
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

--JSON pretty-printing function moved to json.lua
-- Helper function to pretty-print a Lua table as indented JSON
-- local function json_pretty(tbl, indent)
-- 	indent = indent or 2
-- 	local function quote(str)
-- 		return '"' .. tostring(str):gsub('"', '\\"') .. '"'
-- 	end
-- 	local function is_array(t)
-- 		local i = 0
-- 		for _ in pairs(t) do
-- 			i = i + 1
-- 			if t[i] == nil then
-- 				return false
-- 			end
-- 		end
-- 		return true
-- 	end
-- 	local function dump(t, level)
-- 		level = level or 0
-- 		local pad = string.rep(" ", level * indent)
-- 		if type(t) ~= "table" then
-- 			if type(t) == "string" then
-- 				return quote(t)
-- 			else
-- 				return tostring(t)
-- 			end
-- 		end
-- 		local isarr = is_array(t)
-- 		local items = {}
-- 		for k, v in pairs(t) do
-- 			local key = isarr and "" or (quote(k) .. ": ")
-- 			table.insert(items, pad .. string.rep(" ", indent) .. key .. dump(v, level + 1))
-- 		end
-- 		if isarr then
-- 			return "[\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "]"
-- 		else
-- 			return "{\n" .. table.concat(items, ",\n") .. "\n" .. pad .. "}"
-- 		end
-- 	end
-- 	return dump(tbl, 0)
-- end

-- Use timestamped backup file
LazyManager.latest_backup_file = get_backup_filename()
local success, err = json_utils.write_file(LazyManager.latest_backup_file, plugin_versions)

if success then
	print("✅ Plugins backed up to: " .. LazyManager.latest_backup_file)
else
	vim.api.nvim_err_writeln("❌ Error: Could not create backup file. " .. (err or ""))
end
-- local json = json_pretty(plugin_versions, 2)
-- local file = io.open(LazyManager.latest_backup_file, "w")
-- if file then
-- 	file:write(json)
-- 	file:close()
-- 	print("✅ Plugins backed up to: " .. LazyManager.latest_backup_file)
-- else
-- 	vim.api.nvim_err_writeln("❌ Error: Could not create backup file.")
-- end

-- Helper: resolve which backup file to use
local function resolve_backup_file(args, backup_path)
	if vim.fn.isdirectory(backup_dir) == 0 then
		vim.fn.mkdir(backup_dir, "p")
	end
	if backup_path and backup_path ~= "" then
		if not backup_path:match("^/") and not backup_path:match("^~") then
			return backup_dir .. backup_path
		end
		return backup_path
	end
	if LazyManager.latest_backup_file ~= "" then
		return LazyManager.latest_backup_file
	end
	local files = vim.fn.glob(backup_dir .. "*.json", true, true)
	table.sort(files, function(a, b)
		return a > b
	end)
	if #files > 0 then
		print("✅ Using most recent backup: " .. vim.fn.fnamemodify(files[1], ":t"))
		return files[1]
	else
		vim.api.nvim_err_writeln("❌ Error: No backup files found!")
		return nil
	end
end

-- Helper: prompt user for confirmation (moved to ui.lua)
-- Helper: restore a single plugin (moved to git.lua)

-- Centralized error handler
local function report_error(msg)
	vim.api.nvim_err_writeln(msg)
end

-- Helper: restore a single plugin using git.lua
local function restore_plugin(plugin_data, target_version)
	local plugin_name = plugin_data.name
	local plugin_dir = plugin_data.dir
	if vim.fn.isdirectory(plugin_dir) ~= 1 then
		report_error("❌ Plugin directory not found: " .. plugin_name .. " at " .. plugin_dir)
		return
	end
	if git.commit_exists(plugin_dir, target_version) then
		local ok, result = git.checkout_commit(plugin_dir, target_version)
		if ok then
			print("✅ Restored plugin: " .. plugin_name .. " to " .. target_version:sub(1, 7))
		else
			report_error("❌ Failed to restore " .. plugin_name .. ": " .. result)
		end
	else
		print(
			"⚠️  Commit "
				.. target_version:sub(1, 7)
				.. " not found locally for "
				.. plugin_name
				.. ", attempting to fetch..."
		)
		git.fetch_all(plugin_dir)
		local ok, result = git.checkout_commit(plugin_dir, target_version)
		if ok then
			print("✅ Restored plugin: " .. plugin_name .. " to " .. target_version:sub(1, 7) .. " (after fetch)")
		else
			report_error(
				"❌ Failed to restore "
					.. plugin_name
					.. " even after fetch. Commit may not exist: "
					.. target_version:sub(1, 7)
			)
		end
	end
end

-- Helper: get plugins to restore
local function get_plugins_to_restore(args, plugin_versions)
	local plugins = {}
	if not args or #args == 0 or (args and #args == 1 and args[1] == "") then
		for name, version in pairs(plugin_versions) do
			table.insert(plugins, { name = name, version = version })
		end
	else
		for _, plugin_name in ipairs(args) do
			if plugin_name and plugin_name ~= "" then
				local version = plugin_versions[plugin_name]
				if version then
					table.insert(plugins, { name = plugin_name, version = version })
				else
					vim.api.nvim_err_writeln("❌ No backup found for plugin: " .. plugin_name)
				end
			end
		end
	end
	return plugins
end

function LazyManager.restore_plugins(args, backup_path)
	local backup_to_use = resolve_backup_file(args, backup_path)
	if not backup_to_use then
		return
	end
	local file = io.open(backup_to_use, "r")
	if not file then
		report_error("❌ Error: No backup file found at " .. backup_to_use)
		return
	end
	local content = file:read("*a")
	file:close()
	local ok, plugin_versions = pcall(vim.fn.json_decode, content)
	if not ok then
		report_error("❌ Error: Invalid JSON in backup file")
		return
	end
	local backup_filename = vim.fn.fnamemodify(backup_to_use, ":t")
	local prompt_msg = "Are you sure you want to restore plugins from " .. backup_filename .. "? (y/n): "
	ui.input({ prompt = prompt_msg }, function(input)
		if not input or input:lower() ~= "y" then
			print("Restore canceled.")
			return
		end
		local lazy = require("lazy")
		local plugins_to_restore = get_plugins_to_restore(args, plugin_versions)
		if not args or #args == 0 or (args and #args == 1 and args[1] == "") then
			print("🔄 Restoring all " .. #plugins_to_restore .. " plugins from backup...")
		else
			print("🔄 Restoring " .. #plugins_to_restore .. " specified plugins...")
		end
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
				report_error("❌ Plugin not installed: " .. plugin_name)
			else
				restore_plugin(plugin_data, target_version)
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

		-- No arguments: show plugin selection UI
		if #args == 0 then
			local lazy = require("lazy")
			local plugins = {}
			for _, plugin in pairs(lazy.plugins()) do
				table.insert(plugins, plugin.name)
			end
			if pcall(require, "telescope.builtin") then
				require("telescope.pickers")
					.new({}, {
						prompt_title = "Select plugin to restore",
						finder = require("telescope.finders").new_table({ results = plugins }),
						sorter = require("telescope.config").values.generic_sorter({}),
						attach_mappings = function(_, _)
							local actions = require("telescope.actions")
							local action_state = require("telescope.actions.state")
							actions.select_default:replace(function(prompt_bufnr)
								actions.close(prompt_bufnr)
								local selection = action_state.get_selected_entry()
								if selection and selection[1] then
									LazyManager.telescope_plugin_backups(selection[1])
								end
							end)
							return true
						end,
					})
					:find()
			else
				vim.ui.select(plugins, { prompt = "Select plugin to restore" }, function(choice)
					if choice then
						LazyManager.telescope_plugin_backups(choice)
					end
				end)
			end
			return
		end

		-- One argument: skip plugin selection, go directly to backup selection for that plugin
		if #args == 1 then
			LazyManager.telescope_plugin_backups(args[1])
			return
		end

		-- MULTI-PLUGIN RESTORE: If multiple plugins specified, prompt for backup file, then restore all specified plugins.
		if #args > 1 then
			local files = vim.fn.glob(backup_dir .. "*.json", true, true)
			if #files == 0 then
				vim.api.nvim_err_writeln("❌ No backups found in " .. backup_dir)
				return
			end
			table.sort(files, function(a, b)
				return a > b
			end)
<<<<<<< Updated upstream

			-- Use Telescope if available, else fallback to vim.ui.select
			local picker = function(cb)
				if pcall(require, "telescope.builtin") then
					require("telescope.pickers")
						.new({}, {
							prompt_title = "Select Lazy.nvim Backup to Restore (MULTI-PLUGIN)",
							finder = require("telescope.finders").new_table({ results = files }),
							sorter = require("telescope.config").values.generic_sorter({}),
							attach_mappings = function(_, _)
								local actions = require("telescope.actions")
								local action_state = require("telescope.actions.state")
								actions.select_default:replace(function(prompt_bufnr)
									actions.close(prompt_bufnr)
									local selection = action_state.get_selected_entry()
									if selection and selection[1] then
										cb(selection[1])
									end
								end)
								return true
							end,
						})
						:find()
				else
					local names = {}
					for _, f in ipairs(files) do
						table.insert(names, vim.fn.fnamemodify(f, ":t"))
					end
					vim.ui.select(names, { prompt = "Select backup file" }, function(choice)
						if choice then
							for _, f in ipairs(files) do
								if vim.fn.fnamemodify(f, ":t") == choice then
									cb(f)
									return
								end
							end
						end
					end)
||||||| Stash base
			table.sort(files, function(a, b) return a > b end)
			ui.telescope_backup_picker(files, "Select backup file", function(selected_backup)
				if selected_backup then
					LazyManager.restore_plugins(args, selected_backup)
=======
			ui.telescope_backup_picker(files, "Select backup file", function(selected_backup)
				if selected_backup then
					LazyManager.restore_plugins(args, selected_backup)
>>>>>>> Stashed changes
				end
			end

			picker(function(selected_backup)
				LazyManager.restore_plugins(args, selected_backup)
			end)
			return
		end
	end, {
		nargs = "*",
		complete = function(ArgLead, CmdLine, CursorPos)
			local lazy = require("lazy")
			local completions = {}

			-- Only complete plugins that are installed in the sandbox
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
						local file = entry.value.file
						local lines = {}
						if file then
							local f = io.open(file, "r")
							if f then
								for line in f:lines() do
									table.insert(lines, line)
								end
								f:close()
							else
								table.insert(lines, "(Could not open backup file)")
							end
						else
							table.insert(lines, "(No file selected)")
						end
						vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
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
	-- local file = io.open(backup_to_use, "r")
	-- if not file then
	-- 	vim.api.nvim_err_writeln("❌ Error: No backup file found at " .. backup_to_use)
	-- 	return
	-- end
	-- local content = file:read("*a")
	-- file:close()
	-- local ok, plugin_versions = pcall(vim.fn.json_decode, content)
	-- if not ok then
	-- 	vim.api.nvim_err_writeln("❌ Error: Invalid JSON in backup file")
	-- 	return
	-- end
	local plugin_versions, err = json_utils.read_file(backup_to_use)
	if not plugin_versions then
		vim.api.nvim_err_writeln("❌ Error: " .. (err or "Failed to read backup file at " .. backup_to_use))
		return
	end
	local backup_filename = vim.fn.fnamemodify(backup_to_use, ":t")
	local prompt_msg = "Are you sure you want to restore ALL plugins from " .. backup_filename .. "? (y/n): "
	vim.ui.input({ prompt = prompt_msg }, function(input)
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
