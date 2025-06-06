-- lua/lazymanager/git.lua
-- Handles all git operations for plugin restoration
local M = {}

-- Check if a commit exists in the repo
function M.commit_exists(plugin_dir, commit)
  local check_cmd = string.format(
    "cd %s && git cat-file -e %s",
    vim.fn.shellescape(plugin_dir),
    vim.fn.shellescape(commit)
  )
  vim.fn.system(check_cmd)
  return vim.v.shell_error == 0
end

-- Checkout a specific commit in the repo
function M.checkout_commit(plugin_dir, commit)
  local git_cmd = string.format(
    "cd %s && git checkout %s",
    vim.fn.shellescape(plugin_dir),
    vim.fn.shellescape(commit)
  )
  local result = vim.fn.system(git_cmd)
  return vim.v.shell_error == 0, result
end

-- Fetch all remotes for the repo
function M.fetch_all(plugin_dir)
  local fetch_cmd = string.format("cd %s && git fetch --all", vim.fn.shellescape(plugin_dir))
  vim.fn.system(fetch_cmd)
end

return M
