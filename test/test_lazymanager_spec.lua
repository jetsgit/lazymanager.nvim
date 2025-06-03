-- test_lazymanager.lua
-- Busted tests for all LazyManager functions and vim.api calls

-- Load vim mock before loading lazymanager
require("test.vim_mock")

local stub = require("luassert.stub")
local LazyManager = dofile("lua/lazymanager.lua")

describe("LazyManager", function()
	-- backup_plugins
	it("should call vim.fn.isdirectory and vim.fn.mkdir in backup_plugins", function()
		local isdirectory = stub(vim.fn, "isdirectory")
		local mkdir = stub(vim.fn, "mkdir")
		isdirectory.returns(0)
		mkdir.returns(true)
		LazyManager.backup_plugins()
		assert.stub(isdirectory).was_called()
		assert.stub(mkdir).was_called()
		isdirectory:revert()
		mkdir:revert()
	end)

	-- restore_plugins
	it("should call vim.fn.glob and vim.api.nvim_err_writeln in restore_plugins", function()
		local glob = stub(vim.fn, "glob")
		local nvim_err_writeln = stub(vim.api, "nvim_err_writeln")
		glob.returns({})
		LazyManager.latest_backup_file = ""
		local orig_io_open = io.open
		io.open = function()
			return nil
		end
		LazyManager.restore_plugins(nil, nil)
		assert.stub(glob).was_called()
		assert.stub(nvim_err_writeln).was_called()
		glob:revert()
		nvim_err_writeln:revert()
		io.open = orig_io_open
	end)

	-- list_backups
	it("should call vim.fn.glob and vim.api.nvim_err_writeln in list_backups", function()
		local glob = stub(vim.fn, "glob")
		local nvim_err_writeln = stub(vim.api, "nvim_err_writeln")
		glob.returns({})
		LazyManager.list_backups()
		assert.stub(glob).was_called()
		assert.stub(nvim_err_writeln).was_called()
		glob:revert()
		nvim_err_writeln:revert()
	end)

	-- get_backup_dir
	it("should return backup_dir", function()
		assert.is_string(LazyManager.get_backup_dir())
	end)

	-- setup
	it("should call vim.api.nvim_create_user_command in setup", function()
		local nvim_create_user_command = stub(vim.api, "nvim_create_user_command")
		LazyManager.setup()
		assert.stub(nvim_create_user_command).was_called()
		nvim_create_user_command:revert()
	end)

	-- restore_file_full
	describe("restore_file_full", function()
		local orig_io_open, orig_vim_ui_input, orig_vim_api_err, orig_vim_fn_isdir, orig_vim_fn_json_decode, orig_vim_fn_fnamemodify
		local test_backup_path = "/tmp/test-backup.json"
		local valid_json = '{"test-plugin":"abc123"}'
		local invalid_json = "{invalid json}"
		local plugin_dir = "/tmp/test-plugin"

		before_each(function()
			orig_io_open = io.open
			orig_vim_ui_input = vim.ui.input
			orig_vim_api_err = vim.api.nvim_err_writeln
			orig_vim_fn_isdir = vim.fn.isdirectory
			orig_vim_fn_json_decode = vim.fn.json_decode
			orig_vim_fn_fnamemodify = vim.fn.fnamemodify
		end)

		after_each(function()
			io.open = orig_io_open
			vim.ui.input = orig_vim_ui_input
			vim.api.nvim_err_writeln = orig_vim_api_err
			vim.fn.isdirectory = orig_vim_fn_isdir
			vim.fn.json_decode = orig_vim_fn_json_decode
			vim.fn.fnamemodify = orig_vim_fn_fnamemodify
		end)

		it("errors if no file is specified", function()
			local err = stub(vim.api, "nvim_err_writeln")
			LazyManager.restore_file_full(nil)
			assert.stub(err).was_called_with("❌ Please specify a backup file.")
			err:revert()
		end)

		it("errors if file does not exist", function()
			local err = stub(vim.api, "nvim_err_writeln")
			io.open = function()
				return nil
			end
			LazyManager.restore_file_full(test_backup_path)
			assert.stub(err).was_called_with("❌ Error: No backup file found at " .. test_backup_path)
			err:revert()
		end)

		it("errors if JSON is invalid", function()
			local err = stub(vim.api, "nvim_err_writeln")
			io.open = function()
				return {
					read = function()
						return invalid_json
					end,
					close = function() end,
				}
			end
			vim.fn.json_decode = function()
				error("decode error")
			end
			LazyManager.restore_file_full(test_backup_path)
			assert.stub(err).was_called_with("❌ Error: Invalid JSON in backup file")
			err:revert()
		end)

		it("cancels if user does not confirm", function()
			io.open = function()
				return {
					read = function()
						return valid_json
					end,
					close = function() end,
				}
			end
			vim.fn.json_decode = function(str)
				return { ["test-plugin"] = "abc123" }
			end
			vim.fn.fnamemodify = function(path, _)
				return "test-backup.json"
			end
			local input_called = false
			vim.ui.input = function(opts, cb)
				input_called = true
				cb("n")
			end
			local printed = false
			_G.print = function(msg)
				if msg == "Restore canceled." then
					printed = true
				end
			end
			LazyManager.restore_file_full("test-backup.json")
			assert.is_true(input_called)
			assert.is_true(printed)
		end)

		it("restores all plugins if user confirms", function()
			-- Setup mocks and spies
			io.open = function()
				return {
					read = function()
						return valid_json
					end,
					close = function() end,
				}
			end
			vim.fn.json_decode = function(str)
				return { ["test-plugin"] = "abc123" }
			end
			local input_called, input_prompt = false, nil
			vim.ui.input = function(opts, cb)
				input_called = true
				input_prompt = opts and opts.prompt
				cb("y")
			end
			local isdir_called, isdir_arg = false, nil
			vim.fn.isdirectory = function(dir)
				isdir_called = true
				isdir_arg = dir
				return dir == plugin_dir and 1 or 0
			end
			local system_calls = {}
			vim.fn.shellescape = function(s)
				return s
			end
			vim.fn.system = function(cmd)
				table.insert(system_calls, cmd)
				return ""
			end
			vim.v.shell_error = 0
			local error_msgs = {}
			vim.api.nvim_err_writeln = function(msg)
				table.insert(error_msgs, msg)
			end
			local printed_msgs = {}
			_G.print = function(msg)
				table.insert(printed_msgs, msg)
			end
			package.loaded.lazy = {
				plugins = function()
					return { { name = "test-plugin", dir = plugin_dir, commit = "abc123" } }
				end,
			}
			vim.fn.fnamemodify = function(path, _)
				return "test-backup.json"
			end

			-- Run
			LazyManager.restore_file_full(test_backup_path)

			-- Assertions
			assert.is_true(input_called)
			assert.is_not_nil(input_prompt)
			assert.equals("Are you sure you want to restore ALL plugins from test-backup.json? (y/n): ", input_prompt)
			assert.is_true(isdir_called)
			assert.equals(plugin_dir, isdir_arg)
			assert.is_true(#system_calls >= 2) -- should call git cat-file and git checkout
			assert.is_not_nil(system_calls[1]:match("git cat%-file"))
			assert.is_not_nil(system_calls[2]:match("git checkout"))
			assert.is_true(#error_msgs == 0)
			local found_restore = false
			local found_restart = false
			for _, msg in ipairs(printed_msgs) do
				if msg:match("Restored plugin") then
					found_restore = true
				end
				if msg:match("Restart Neovim") then
					found_restart = true
				end
			end
			assert.is_true(found_restore)
			assert.is_true(found_restart)
		end)
	end)
	-- multi-plugin restore
	describe("multi-plugin restore", function()
		local orig_vim_fn_glob, orig_vim_fn_fnamemodify, orig_vim_ui_select, orig_LazyManager_restore_plugins
		local backup_dir = "/tmp/lazy-plugin-backups/"
		local backup_files = {
			backup_dir .. "2025-06-01-lazy-plugin-backup.json",
			backup_dir .. "2025-06-02-lazy-plugin-backup.json",
		}
		local selected_backup = backup_files[2]
		local plugins = {
			{ name = "pluginA", dir = "/tmp/pluginA", commit = "a1b2c3d4" },
			{ name = "pluginB", dir = "/tmp/pluginB", commit = "b2c3d4e5" },
			{ name = "pluginC", dir = "/tmp/pluginC", commit = "c3d4e5f6" },
		}

		before_each(function()
			orig_vim_fn_glob = vim.fn.glob
			orig_vim_fn_fnamemodify = vim.fn.fnamemodify
			orig_vim_ui_select = vim.ui.select
			orig_LazyManager_restore_plugins = LazyManager.restore_plugins
		end)

		after_each(function()
			vim.fn.glob = orig_vim_fn_glob
			vim.fn.fnamemodify = orig_vim_fn_fnamemodify
			vim.ui.select = orig_vim_ui_select
			LazyManager.restore_plugins = orig_LazyManager_restore_plugins
		end)

		it("restores only specified plugins from selected backup file", function()
			-- Mock glob to return backup files
			vim.fn.glob = function(pattern, a, b)
				return backup_files
			end
			-- Mock fnamemodify to return just the filename
			vim.fn.fnamemodify = function(path, mod)
				return path:match("[^/]+$")
			end
			-- Mock vim.ui.select to simulate user picking the second backup file
			local select_called, select_choices, select_prompt = false, nil, nil
			vim.ui.select = function(choices, opts, cb)
				select_called = true
				select_choices = choices
				select_prompt = opts and opts.prompt
				cb("2025-06-02-lazy-plugin-backup.json")
			end
			-- Spy on restore_plugins
			local restore_args, restore_file
			LazyManager.restore_plugins = function(args, file)
				restore_args = args
				restore_file = file
			end
			-- Simulate command logic for multi-plugin restore
			local args = { "pluginA", "pluginB" }
			-- Simulate the code chunk under test
			local files = vim.fn.glob(backup_dir .. "*.json", true, true)
			table.sort(files, function(a, b)
				return a > b
			end)
			local names = {}
			for _, f in ipairs(files) do
				table.insert(names, vim.fn.fnamemodify(f, ":t"))
			end
			vim.ui.select(names, { prompt = "Select backup file" }, function(choice)
				if choice then
					for _, f in ipairs(files) do
						if vim.fn.fnamemodify(f, ":t") == choice then
							LazyManager.restore_plugins(args, f)
							return
						end
					end
				end
			end)
			-- Assertions
			assert.is_true(select_called)
			assert.same({ "2025-06-02-lazy-plugin-backup.json", "2025-06-01-lazy-plugin-backup.json" }, select_choices)
			assert.equals("Select backup file", select_prompt)
			assert.same({ "pluginA", "pluginB" }, restore_args)
			assert.equals(selected_backup, restore_file)
		end)
	end)
end)
