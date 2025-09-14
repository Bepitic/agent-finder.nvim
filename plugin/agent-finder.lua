-- agent-finder.nvim plugin entry point
-- This file is automatically loaded by Neovim

-- Register commands and autocmds when the plugin loads
local function setup_commands()
  -- Register user commands
  vim.api.nvim_create_user_command('AFLoad', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.load_agents()
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Load AI agents from YAML configuration' })

  vim.api.nvim_create_user_command('AFGoal', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.set_goal()
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Set AI agent goal for current buffer' })

  vim.api.nvim_create_user_command('AFApply', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.apply_goal()
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Apply AI agent goal to current buffer' })

  vim.api.nvim_create_user_command('AFEnv', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.export_env()
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Export API keys to vim.env' })
end

-- Set up default keymaps
local function setup_keymaps()
  local ok, config = pcall(require, 'agent_finder.config')
  if ok and config.get('default_keymaps') then
    local opts = { silent = true, noremap = true }
    
    vim.keymap.set('n', '<leader>afl', '<cmd>AFLoad<cr>', vim.tbl_extend('force', opts, { desc = 'Load agents' }))
    vim.keymap.set('n', '<leader>afg', '<cmd>AFGoal<cr>', vim.tbl_extend('force', opts, { desc = 'Set goal' }))
    vim.keymap.set('n', '<leader>afa', '<cmd>AFApply<cr>', vim.tbl_extend('force', opts, { desc = 'Apply goal' }))
  end
end

-- Initialize the plugin
setup_commands()
setup_keymaps()
