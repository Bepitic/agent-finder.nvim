-- agent-finder.nvim plugin entry point
-- This file is automatically loaded by Neovim

local M = {}

-- Register commands and autocmds when the plugin loads
M.setup = function()
  -- Register user commands
  vim.api.nvim_create_user_command('AFLoad', function()
    require('agent_finder').load_agents()
  end, { desc = 'Load AI agents from YAML configuration' })

  vim.api.nvim_create_user_command('AFGoal', function()
    require('agent_finder').set_goal()
  end, { desc = 'Set AI agent goal for current buffer' })

  vim.api.nvim_create_user_command('AFApply', function()
    require('agent_finder').apply_goal()
  end, { desc = 'Apply AI agent goal to current buffer' })

  vim.api.nvim_create_user_command('AFEnv', function()
    require('agent_finder').export_env()
  end, { desc = 'Export API keys to vim.env' })

  -- Set up default keymaps if not disabled
  local config = require('agent_finder.config')
  if config.default_keymaps then
    local opts = { silent = true, noremap = true }
    
    vim.keymap.set('n', '<leader>afl', '<cmd>AFLoad<cr>', vim.tbl_extend('force', opts, { desc = 'Load agents' }))
    vim.keymap.set('n', '<leader>afg', '<cmd>AFGoal<cr>', vim.tbl_extend('force', opts, { desc = 'Set goal' }))
    vim.keymap.set('n', '<leader>afa', '<cmd>AFApply<cr>', vim.tbl_extend('force', opts, { desc = 'Apply goal' }))
  end
end

-- Auto-setup when plugin loads
M.setup()

return M
