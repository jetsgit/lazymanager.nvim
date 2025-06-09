--- Git utilities for LazyManager.
-- @module lazymanager.git
-- Handles all git operations for plugin restoration (commit check, checkout, fetch).

local M = {}

--- Check if a commit exists in the repo.
-- @param plugin_dir string: Path to the plugin directory.
-- @param commit string: Commit hash to check.
-- @return boolean: True if commit exists, false otherwise.
function M.commit_exists(plugin_dir, commit)
  local check_cmd = string.format(
    "cd %s && git cat-file -e %s",
    vim.fn.shellescape(plugin_dir),
    vim.fn.shellescape(commit)
  )
  vim.fn.system(check_cmd)
  return vim.v.shell_error == 0
end

--- Checkout a specific commit in the repo.
-- @param plugin_dir string: Path to the plugin directory.
-- @param commit string: Commit hash to checkout.
-- @return boolean, string: True if successful, and the command result.
function M.checkout_commit(plugin_dir, commit)
  local git_cmd = string.format(
    "cd %s && git checkout %s",
    vim.fn.shellescape(plugin_dir),
    vim.fn.shellescape(commit)
  )
  local result = vim.fn.system(git_cmd)
  return vim.v.shell_error == 0, result
end

--- Fetch all remotes for the repo.
-- @param plugin_dir string: Path to the plugin directory.
function M.fetch_all(plugin_dir)
  local fetch_cmd = string.format("cd %s && git fetch --all", vim.fn.shellescape(plugin_dir))
  vim.fn.system(fetch_cmd)
end

return M
