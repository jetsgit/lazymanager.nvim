-- test/vim_mock.lua
-- Provides a mock 'vim' global for Busted tests outside Neovim
if not vim then
  vim = {
    fn = setmetatable({}, { __index = function(t, k)
      if k == "expand" then
        return function(arg)
          if arg == "~" then return "/tmp" end
          return arg
        end
      end
      return function() end
    end }),
    api = setmetatable({}, { __index = function() return function() end end }),
    ui = setmetatable({}, { __index = function() return function(_, cb) if cb then cb('y') end end end }),
    opt = setmetatable({}, { __index = function() return { prepend = function() end } end }),
    defer_fn = function(cb, _) if cb then cb() end end,
    v = { shell_error = 0 },
    loop = { fs_stat = function() return true end },
    g = {},
    keymap = { set = function() end },
  }
end

-- Explicitly define functions to allow stubbing
vim.fn.isdirectory = function() return 1 end
vim.fn.mkdir = function() return true end
vim.fn.glob = function() return {} end
vim.api.nvim_err_writeln = function() end

-- Mock the 'lazy' module for tests
package.loaded.lazy = {
  plugins = function()
    return {
      { name = "test-plugin", dir = "/tmp/test-plugin", commit = "abc123" },
    }
  end
}
