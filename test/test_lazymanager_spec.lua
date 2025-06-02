-- test_lazymanager.lua
-- Busted tests for all LazyManager functions and vim.api calls

-- Load vim mock before loading lazymanager
require('test.vim_mock')

local stub = require('luassert.stub')
local LazyManager = dofile('lua/lazymanager.lua')

describe('LazyManager', function()
  -- backup_plugins
  it('should call vim.fn.isdirectory and vim.fn.mkdir in backup_plugins', function()
    local isdirectory = stub(vim.fn, 'isdirectory')
    local mkdir = stub(vim.fn, 'mkdir')
    isdirectory.returns(0)
    mkdir.returns(true)
    LazyManager.backup_plugins()
    assert.stub(isdirectory).was_called()
    assert.stub(mkdir).was_called()
    isdirectory:revert()
    mkdir:revert()
  end)

  -- restore_plugins
  it('should call vim.fn.glob and vim.api.nvim_err_writeln in restore_plugins', function()
    local glob = stub(vim.fn, 'glob')
    local nvim_err_writeln = stub(vim.api, 'nvim_err_writeln')
    glob.returns({})
    LazyManager.latest_backup_file = ""
    local orig_io_open = io.open
    io.open = function() return nil end
    LazyManager.restore_plugins(nil, nil)
    assert.stub(glob).was_called()
    assert.stub(nvim_err_writeln).was_called()
    glob:revert()
    nvim_err_writeln:revert()
    io.open = orig_io_open
  end)

  -- list_backups
  it('should call vim.fn.glob and vim.api.nvim_err_writeln in list_backups', function()
    local glob = stub(vim.fn, 'glob')
    local nvim_err_writeln = stub(vim.api, 'nvim_err_writeln')
    glob.returns({})
    LazyManager.list_backups()
    assert.stub(glob).was_called()
    assert.stub(nvim_err_writeln).was_called()
    glob:revert()
    nvim_err_writeln:revert()
  end)

  -- get_backup_dir
  it('should return backup_dir', function()
    assert.is_string(LazyManager.get_backup_dir())
  end)

  -- setup
  it('should call vim.api.nvim_create_user_command in setup', function()
    local nvim_create_user_command = stub(vim.api, 'nvim_create_user_command')
    LazyManager.setup()
    assert.stub(nvim_create_user_command).was_called()
    nvim_create_user_command:revert()
  end)
end)
