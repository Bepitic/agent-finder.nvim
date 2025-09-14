<div align="center">

# 🤖 agent-finder.nvim

<img src="img/Agent-Finder.png" alt="Agent Finder Logo" width="200"/>

*A Neovim plugin for managing and applying AI agents to your code*

[![Dark Icon](img/Agent-Finder-DarkIcon.png)](img/Agent-Finder-DarkIcon.png)
[![Light Icon](img/Agent-Finder-LightIcon.png)](img/Agent-Finder-LightIcon.png)

Load AI agents from YAML configuration, set goals, and apply them to your current buffer.

</div>

## ✨ Features

- 📁 **YAML Configuration**: Define AI agents in a simple YAML file
- 🎯 **Goal Setting**: Set specific goals for AI agents to work on
- 🔧 **Buffer Integration**: Apply agent goals directly to your current buffer
- 🔑 **API Key Management**: Secure handling of API keys for various AI services
- ⌨️ **Default Keymaps**: Convenient keybindings for common operations
- 🐧 **Cross-platform**: Works on Linux, macOS, and Windows

## 📦 Installation

### Using lazy.nvim

```lua
{
  "Bepitic/agent-finder.nvim",
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
  'Bepitic/agent-finder.nvim',
  config = function()
    require('agent_finder').setup()
  end
}
```

### Using vim-plug

```vim
Plug 'Bepitic/agent-finder.nvim'
```

## ⚙️ Configuration

### 📄 YAML Configuration File

Create a YAML file at `~/.config/nvim/agents.yaml` (or specify a custom path):

#### Option 1: Individual Agent Files (Recommended)

```yaml
# API Keys Configuration
api_keys:
  openai: "your-openai-api-key-here"
  anthropic: "your-anthropic-api-key-here"

# Agents Directory
# The plugin will automatically load all .yaml files from the agents/ directory
agents_directory: agents/
```

Then create individual agent files in the `agents/` directory:

**`agents/code_reviewer.yaml`:**
```yaml
name: "Code Reviewer"
description: "Reviews code for best practices, bugs, and improvements"
prompt: |
  You are an expert code reviewer. Analyze the provided code and provide:
  1. Potential bugs or issues
  2. Code quality improvements
  3. Performance optimizations
  4. Best practice recommendations
  
  Be constructive and specific in your feedback.
```

**`agents/documenter.yaml`:**
```yaml
name: "Documentation Generator"
description: "Generates comprehensive documentation for code"
prompt: |
  You are a technical documentation expert. Generate clear, comprehensive documentation for the provided code including:
  1. Function/class descriptions
  2. Parameter documentation
  3. Usage examples
  4. Return value descriptions
  
  Use appropriate documentation format for the language.
```

#### Option 2: Inline Agents

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

### 🔧 Plugin Configuration

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

## 🎮 Commands

| Command | Description |
|---------|-------------|
| `:AFLoad` | 📥 Load AI agents from YAML configuration |
| `:AFList` | 📋 List available AI agents (with Telescope) |
| `:AFSelect` | 🎯 Select AI agent from list (with Telescope) |
| `:AFGoal` | 🎯 Set AI agent goal for current buffer |
| `:AFApply` | ⚡ Apply AI agent goal to current buffer |
| `:AFEnv` | 🔑 Export API keys to vim.env |

## ⌨️ Default Keymaps

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>afl` | `:AFLoad` | 📥 Load agents |
| `<leader>afL` | `:AFList` | 📋 List agents |
| `<leader>afs` | `:AFSelect` | 🎯 Select agent |
| `<leader>afg` | `:AFGoal` | 🎯 Set goal |
| `<leader>afa` | `:AFApply` | ⚡ Apply goal |

## 🚀 Usage

### Basic Workflow

1. **📋 List Agents**: See all available agents (auto-loads if needed):
   ```
   :AFList
   ```
   This opens a Telescope picker showing all agents with descriptions.

2. **🎯 Select Agent** (Optional): Choose a specific agent:
   ```
   :AFSelect
   ```
   This opens a Telescope picker to select an agent. Press `<C-p>` to preview the agent's prompt.

3. **🎯 Set Goal**: Define what you want the AI agent to do:
   ```
   :AFGoal
   ```
   Enter your goal when prompted (e.g., "Review this function for potential bugs").

4. **⚡ Apply Goal**: Apply the goal to your current buffer:
   ```
   :AFApply
   ```
   This will append a comment with your goal to the current file.

5. **🔑 Export Environment**: If you need API keys in your environment:
   ```
   :AFEnv
   ```

### Manual Loading (Optional)

If you prefer to load agents manually:
```
:AFLoad
```
This loads agents from your YAML configuration without showing the list.

### Telescope Integration

The plugin integrates with [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for a better user experience:

- **`:AFList`**: Shows all available agents in a searchable list
- **`:AFSelect`**: Interactive agent selection with preview
- **Preview**: Press `<C-p>` in Telescope to see the full agent prompt
- **Fallback**: If Telescope isn't available, commands fall back to command-line output

### Quick Keymap Workflow

```vim
<leader>afL  " List agents (Telescope) - auto-loads if needed
<leader>afs  " Select agent (Telescope) - auto-loads if needed
<leader>afg  " Set goal - auto-loads agents if needed
<leader>afa  " Apply goal
<leader>afl  " Manual load (optional)
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

### Optional: Telescope for enhanced UI

For the best user experience with agent selection and listing, install [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim):

```lua
-- Using lazy.nvim
{
  'nvim-telescope/telescope.nvim',
  tag = '0.1.0',
  dependencies = { 'nvim-lua/plenary.nvim' }
}
```

Without Telescope, the plugin will fall back to command-line output for listing agents.

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
├── agents.yaml              # Main configuration file
├── agents/                  # Individual agent files (recommended)
│   ├── code_reviewer.yaml
│   ├── documenter.yaml
│   ├── refactorer.yaml
│   ├── test_generator.yaml
│   ├── security_auditor.yaml
│   ├── performance_optimizer.yaml
│   ├── lua_expert.yaml
│   └── general_assistant.yaml
├── lua/
│   └── agent_finder/
│       ├── init.lua         # Public API
│       ├── config.lua       # Configuration management
│       ├── yaml.lua         # YAML parsing utilities
│       └── core.lua         # Core functionality
└── plugin/
    └── agent-finder.lua     # Plugin entry point
```

### Benefits of Individual Agent Files

- **🎯 Organization**: Each agent has its own file, making them easy to find and manage
- **🔄 Version Control**: Track changes to individual agents separately
- **👥 Collaboration**: Multiple people can work on different agents without conflicts
- **📝 Maintenance**: Easier to update, add, or remove specific agents
- **🔍 Discovery**: Clear file structure makes it easy to see what agents are available

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
