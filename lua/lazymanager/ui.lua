--- UI helpers for LazyManager.
-- @module lazymanager.ui
-- Provides Telescope pickers and wrappers for vim.ui.input/select.

local M = {}

--- Telescope plugin picker.
-- @param plugins table: List of plugin names.
-- @param on_select function: Callback with selected plugin name.
function M.telescope_plugin_picker(plugins, on_select)
  local ok, telescope = pcall(require, "telescope.pickers")
  if not ok then
    vim.ui.select(plugins, { prompt = "Select plugin to restore" }, on_select)
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  telescope.new({}, {
    prompt_title = "Select plugin to restore",
    finder = finders.new_table({ results = plugins }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(_, _)
      actions.select_default:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          on_select(selection[1])
        end
      end)
      return true
    end,
  }):find()
end

--- Telescope backup file picker.
-- @param files table: List of backup file paths.
-- @param prompt string|nil: Prompt for the picker.
-- @param on_select function: Callback with selected file path.
function M.telescope_backup_picker(files, prompt, on_select)
  local ok, telescope = pcall(require, "telescope.pickers")
  if not ok then
    local names = {}
    for _, f in ipairs(files) do
      table.insert(names, vim.fn.fnamemodify(f, ":t"))
    end
    vim.ui.select(names, { prompt = prompt or "Select backup file" }, function(choice)
      if choice then
        for _, f in ipairs(files) do
          if vim.fn.fnamemodify(f, ":t") == choice then
            on_select(f)
            return
          end
        end
      end
    end)
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  telescope.new({}, {
    prompt_title = prompt or "Select backup file",
    finder = finders.new_table({ results = files }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(_, _)
      actions.select_default:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection[1] then
          on_select(selection[1])
        end
      end)
      return true
    end,
  }):find()
end

--- Input helper (wraps vim.ui.input).
-- @param opts table: Options for input.
-- @param on_confirm function: Callback with user input.
function M.input(opts, on_confirm)
  vim.ui.input(opts, on_confirm)
end

--- Select helper (wraps vim.ui.select).
-- @param items table: List of items to select from.
-- @param opts table: Options for select.
-- @param on_choice function: Callback with selected item.
function M.select(items, opts, on_choice)
  vim.ui.select(items, opts, on_choice)
end

return M
