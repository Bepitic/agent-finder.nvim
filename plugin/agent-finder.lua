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

  vim.api.nvim_create_user_command('AFList', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.list_agents()
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'List available AI agents' })

  vim.api.nvim_create_user_command('AFSelect', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.select_agent()
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Select and set AI agent' })

  vim.api.nvim_create_user_command('AFChat', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.start_chat()
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Start chat with AI agent' })

  vim.api.nvim_create_user_command('AFTools', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      agent_finder.load_tools()
      local tools = agent_finder.get_tools()
      if vim.tbl_isempty(tools) then
        vim.notify('agent-finder.nvim: No tools loaded', vim.log.levels.WARN)
      else
        local tool_count = vim.tbl_count(tools)
        vim.notify(string.format('agent-finder.nvim: Loaded %d tools', tool_count), vim.log.levels.INFO)
      end
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Load available tools' })

  vim.api.nvim_create_user_command('AFTool', function(opts)
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      local tool_name = opts.args
      if tool_name == "" then
        vim.notify('agent-finder.nvim: Please specify a tool name', vim.log.levels.WARN)
        return
      end
      
      -- Load tools if not already loaded
      local tools = agent_finder.get_tools()
      if vim.tbl_isempty(tools) then
        agent_finder.load_tools()
        tools = agent_finder.get_tools()
      end
      
      -- Execute tool with no parameters for now
      local result = agent_finder.execute_tool(tool_name, {})
      if result.success then
        vim.notify(string.format('agent-finder.nvim: Tool "%s" executed successfully', tool_name), vim.log.levels.INFO)
        -- TODO: Display result in a buffer or window
      else
        vim.notify(string.format('agent-finder.nvim: Tool execution failed: %s', result.error), vim.log.levels.ERROR)
      end
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Execute a tool', nargs = 1 })

  vim.api.nvim_create_user_command('AFSchema', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      -- Load tools if not already loaded
      local tools = agent_finder.get_tools()
      if vim.tbl_isempty(tools) then
        agent_finder.load_tools()
      end
      
      local schema = agent_finder.generate_tools_schema()
      local json_schema = vim.fn.json_encode(schema)
      
      -- Create a new buffer to display the schema
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = vim.split(json_schema, '\n')
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'json')
      vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
      
      -- Open the buffer in a split
      vim.cmd('vsplit')
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_name(bufnr, 'agent-finder-tools-schema.json')
      
      vim.notify('agent-finder.nvim: Tool schema exported to buffer', vim.log.levels.INFO)
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Export tools schema as JSON' })

  vim.api.nvim_create_user_command('AFPrompt', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      -- Load tools if not already loaded
      local tools = agent_finder.get_tools()
      if vim.tbl_isempty(tools) then
        agent_finder.load_tools()
      end
      
      local prompt = agent_finder.generate_agent_prompt()
      
      -- Create a new buffer to display the prompt
      local bufnr = vim.api.nvim_create_buf(false, true)
      local lines = vim.split(prompt, '\n')
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
      vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
      
      -- Open the buffer in a split
      vim.cmd('vsplit')
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_name(bufnr, 'agent-finder-ai-prompt.md')
      
      vim.notify('agent-finder.nvim: AI agent prompt generated', vim.log.levels.INFO)
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Generate AI agent prompt with tools' })

  vim.api.nvim_create_user_command('AFStatus', function()
    local ok, agent_finder = pcall(require, 'agent_finder')
    if ok then
      local agents = agent_finder.get_agents()
      local api_keys = vim.b.agent_finder_api_keys or {}
      local tools = agent_finder.get_tools()
      
      local status = {
        "=== Agent Finder Status ===",
        "",
        "Agents loaded: " .. (agents and vim.tbl_count(agents) or 0),
        "API keys loaded: " .. (api_keys and vim.tbl_count(api_keys) or 0),
        "Tools loaded: " .. (tools and vim.tbl_count(tools) or 0),
        "",
        "OpenAI API key: " .. (api_keys.openai and "✅ Configured" or "❌ Not found"),
        "Environment OPENAI_API_KEY: " .. (vim.env.OPENAI_API_KEY and "✅ Set" or "❌ Not set"),
        "",
        "Available agents:",
      }
      
      if agents and not vim.tbl_isempty(agents) then
        for name, agent in pairs(agents) do
          table.insert(status, "  - " .. name .. ": " .. (agent.description or "No description"))
        end
      else
        table.insert(status, "  No agents loaded")
      end
      
      table.insert(status, "")
      table.insert(status, "Available tools:")
      
      if tools and not vim.tbl_isempty(tools) then
        for name, tool in pairs(tools) do
          table.insert(status, "  - " .. name .. ": " .. (tool.description or "No description"))
        end
      else
        table.insert(status, "  No tools loaded")
      end
      
      -- Display status in a buffer
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, status)
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'markdown')
      vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
      
      -- Open the buffer in a split
      vim.cmd('vsplit')
      vim.api.nvim_win_set_buf(0, bufnr)
      vim.api.nvim_buf_set_name(bufnr, 'agent-finder-status.md')
      
      vim.notify('agent-finder.nvim: Status displayed', vim.log.levels.INFO)
    else
      vim.notify('agent-finder.nvim: Failed to load module', vim.log.levels.ERROR)
    end
  end, { desc = 'Show agent-finder status and configuration' })
end

-- Set up default keymaps
local function setup_keymaps()
  local ok, config = pcall(require, 'agent_finder.config')
  if ok and config.get('default_keymaps') then
    local opts = { silent = true, noremap = true }
    
    vim.keymap.set('n', '<leader>afl', '<cmd>AFLoad<cr>', vim.tbl_extend('force', opts, { desc = 'Load agents' }))
    vim.keymap.set('n', '<leader>afg', '<cmd>AFGoal<cr>', vim.tbl_extend('force', opts, { desc = 'Set goal' }))
    vim.keymap.set('n', '<leader>afa', '<cmd>AFApply<cr>', vim.tbl_extend('force', opts, { desc = 'Apply goal' }))
    vim.keymap.set('n', '<leader>afs', '<cmd>AFSelect<cr>', vim.tbl_extend('force', opts, { desc = 'Select agent' }))
    vim.keymap.set('n', '<leader>afL', '<cmd>AFList<cr>', vim.tbl_extend('force', opts, { desc = 'List agents' }))
    vim.keymap.set('n', '<leader>afc', '<cmd>AFChat<cr>', vim.tbl_extend('force', opts, { desc = 'Start chat' }))
    vim.keymap.set('n', '<leader>aft', '<cmd>AFTools<cr>', vim.tbl_extend('force', opts, { desc = 'Load tools' }))
    vim.keymap.set('n', '<leader>afS', '<cmd>AFSchema<cr>', vim.tbl_extend('force', opts, { desc = 'Export tools schema' }))
    vim.keymap.set('n', '<leader>afp', '<cmd>AFPrompt<cr>', vim.tbl_extend('force', opts, { desc = 'Generate AI prompt' }))
    vim.keymap.set('n', '<leader>af?', '<cmd>AFStatus<cr>', vim.tbl_extend('force', opts, { desc = 'Show status' }))
  end
end

-- Initialize the plugin
setup_commands()
setup_keymaps()
