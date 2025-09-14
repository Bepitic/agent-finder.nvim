# agent-finder.nvim

A Neovim plugin for managing and applying AI agents to your code. Load AI agents from YAML configuration, set goals, and apply them to your current buffer.

## Features

- 📁 **YAML Configuration**: Define AI agents in a simple YAML file
- 🎯 **Goal Setting**: Set specific goals for AI agents to work on
- 🔧 **Buffer Integration**: Apply agent goals directly to your current buffer
- 🔑 **API Key Management**: Secure handling of API keys for various AI services
- ⌨️ **Default Keymaps**: Convenient keybindings for common operations
- 🐧 **Cross-platform**: Works on Linux, macOS, and Windows

## Installation

### Using lazy.nvim

```lua
{
  "your-username/agent-finder.nvim",
  config = function()
    require('agent_finder').setup({
      -- Optional configuration
      agents_file = "~/.config/nvim/agents.yaml",
      default_keymaps = true,
      yaml_parser = "yq", -- or "lua"
      api_keys = {
        openai = "your-openai-key",
        anthropic = "your-anthropic-key",
      },
    })
  end,
}
```

### Using packer.nvim

```lua
use {
  'your-username/agent-finder.nvim',
  config = function()
    require('agent_finder').setup()
  end
}
```

### Using vim-plug

```vim
Plug 'your-username/agent-finder.nvim'
```

## Configuration

### YAML Configuration File

Create a YAML file at `~/.config/nvim/agents.yaml` (or specify a custom path):

```yaml
# API Keys Configuration
api_keys:
  openai: "your-openai-api-key-here"
  anthropic: "your-anthropic-api-key-here"

# AI Agents Configuration
agents:
  code_reviewer:
    name: "Code Reviewer"
    description: "Reviews code for best practices and bugs"
    prompt: |
      You are an expert code reviewer. Analyze the provided code and provide:
      1. Potential bugs or issues
      2. Code quality improvements
      3. Performance optimizations
      4. Best practice recommendations

  documenter:
    name: "Documentation Generator"
    description: "Generates comprehensive documentation"
    prompt: |
      You are a technical documentation expert. Generate clear, comprehensive documentation
      for the provided code including function descriptions, parameters, and examples.
```

### Plugin Configuration

```lua
require('agent_finder').setup({
  -- Path to agents YAML file
  agents_file = "~/.config/nvim/agents.yaml",
  
  -- Enable/disable default keymaps
  default_keymaps = true,
  
  -- YAML parser preference ('yq' or 'lua')
  yaml_parser = "yq",
  
  -- API keys (can also be set in YAML file)
  api_keys = {
    openai = "your-key-here",
    anthropic = "your-key-here",
  },
  
  -- Debug mode
  debug = false,
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:AFLoad` | Load AI agents from YAML configuration |
| `:AFGoal` | Set AI agent goal for current buffer |
| `:AFApply` | Apply AI agent goal to current buffer |
| `:AFEnv` | Export API keys to vim.env |

## Default Keymaps

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>afl` | `:AFLoad` | Load agents |
| `<leader>afg` | `:AFGoal` | Set goal |
| `<leader>afa` | `:AFApply` | Apply goal |

## Usage

1. **Load Agents**: First, load your AI agents from the YAML configuration:
   ```
   :AFLoad
   ```

2. **Set Goal**: Define what you want the AI agent to do:
   ```
   :AFGoal
   ```
   Enter your goal when prompted (e.g., "Review this function for potential bugs").

3. **Apply Goal**: Apply the goal to your current buffer:
   ```
   :AFApply
   ```
   This will append a comment with your goal to the current file.

4. **Export Environment**: If you need API keys in your environment:
   ```
   :AFEnv
   ```

## API

### Public Functions

```lua
local agent_finder = require('agent_finder')

-- Setup the plugin
agent_finder.setup(opts)

-- Load agents from YAML
agent_finder.load_agents()

-- Set goal for current buffer
agent_finder.set_goal()

-- Apply goal to current buffer
agent_finder.apply_goal()

-- Export API keys to environment
agent_finder.export_env()

-- Get current agents
local agents = agent_finder.get_agents()

-- Get current goal
local goal = agent_finder.get_goal()

-- Clear buffer state
agent_finder.clear_state()
```

## Dependencies

### Optional: yq for YAML parsing

For better YAML parsing support, install `yq`:

```bash
# macOS
brew install yq

# Ubuntu/Debian
sudo apt install yq

# Arch Linux
sudo pacman -S yq

# Windows (using Chocolatey)
choco install yq
```

If `yq` is not available, the plugin will fall back to a basic Lua YAML parser.

## Development

### Project Structure

```
agent-finder.nvim/
├── README.md
├── agents.yaml              # Example configuration
├── lua/
│   └── agent_finder/
│       ├── init.lua         # Public API
│       ├── config.lua       # Configuration management
│       ├── yaml.lua         # YAML parsing utilities
│       └── core.lua         # Core functionality
└── plugin/
    └── agent-finder.lua     # Plugin entry point
```

### Extending the Plugin

The plugin is designed to be modular and extensible. Key areas for extension:

1. **AI Integration**: Replace `_apply_goal_to_buffer()` in `core.lua` with actual API calls
2. **New Parsers**: Add support for additional YAML parsers in `yaml.lua`
3. **Additional Commands**: Add new commands in `plugin/agent-finder.lua`
4. **Custom Keymaps**: Override default keymaps in your configuration

### Example: Adding AI API Integration

```lua
-- In core.lua, replace _apply_goal_to_buffer with:
function M._apply_goal_to_buffer(goal)
  local agents = vim.b.agent_finder_agents
  local selected_agent = agents.code_reviewer -- or let user select
  
  -- Make API call to OpenAI/Anthropic/etc.
  local response = make_api_call(selected_agent.prompt, goal, current_buffer_content)
  
  -- Apply response to buffer
  apply_response_to_buffer(response)
end
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Inspired by the need for better AI integration in Neovim
- Built with the Neovim Lua API
- YAML parsing powered by yq (with Lua fallback)
