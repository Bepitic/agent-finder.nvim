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
  openai: "your-openai-api-key-here"  # Required for chat functionality
  anthropic: "your-anthropic-api-key-here"

# Agents Directory
# The plugin will automatically load all .yaml files from the agents/ directory
agents_directory: agents/
```

**Note**: The `openai` API key is required for the chat interface to work with real AI responses. Without it, the chat will show error messages.

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
| `:AFChat` | 💬 Start chat with AI agent (split window) |
| `:AFTools` | 🔧 Load available tools |
| `:AFTool` | ⚙️ Execute a specific tool |
| `:AFSchema` | 📋 Export tools schema as JSON |
| `:AFPrompt` | 🤖 Generate AI agent prompt with tools |
| `:AFGoal` | 🎯 Set AI agent goal for current buffer |
| `:AFApply` | ⚡ Apply AI agent goal to current buffer |
| `:AFEnv` | 🔑 Export API keys to vim.env |

## ⌨️ Default Keymaps

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>afl` | `:AFLoad` | 📥 Load agents |
| `<leader>afL` | `:AFList` | 📋 List agents |
| `<leader>afs` | `:AFSelect` | 🎯 Select agent |
| `<leader>afc` | `:AFChat` | 💬 Start chat |
| `<leader>aft` | `:AFTools` | 🔧 Load tools |
| `<leader>afS` | `:AFSchema` | 📋 Export tools schema |
| `<leader>afp` | `:AFPrompt` | 🤖 Generate AI prompt |
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

3. **💬 Start Chat**: Have a conversation with an AI agent:
   ```
   :AFChat
   ```
   This opens a split window where you can chat with the selected agent.

4. **🎯 Set Goal**: Define what you want the AI agent to do:
   ```
   :AFGoal
   ```
   Enter your goal when prompted (e.g., "Review this function for potential bugs").

5. **⚡ Apply Goal**: Apply the goal to your current buffer:
   ```
   :AFApply
   ```
   This will append a comment with your goal to the current file.

6. **🔑 Export Environment**: If you need API keys in your environment:
   ```
   :AFEnv
   ```

### Manual Loading (Optional)

If you prefer to load agents manually:
```
:AFLoad
```
This loads agents from your YAML configuration without showing the list.

### Chat Interface

The plugin includes a full chat interface for interactive conversations with AI agents:

- **Split Window**: Opens a vertical split with the chat interface
- **Agent Selection**: Choose any agent from your configuration
- **Real-time Chat**: Type messages and get responses from OpenAI
- **Message History**: Full conversation history is maintained
- **Save Conversations**: Export chat logs to markdown files
- **OpenAI Integration**: Uses GPT-3.5-turbo for real AI responses

#### OpenAI Configuration

To use the chat interface with real AI responses, you need to configure your OpenAI API key:

1. **Set API Key in agents.yaml**:
   ```yaml
   api_keys:
     openai: "your-openai-api-key-here"
   ```

2. **Or set environment variable**:
   ```bash
   export OPENAI_API_KEY="your-openai-api-key-here"
   ```

3. **Load agents and start chatting**:
   ```vim
   :AFLoad    " Load agents with API keys
   :AFChat    " Start chat interface
   ```

#### Chat Controls

- **`<Enter>`**: Send message
- **`<Esc>`**: Exit chat
- **`<C-s>`**: Save conversation to file

#### Chat Features

- **Markdown Formatting**: Chat is displayed in markdown format
- **Agent Context**: Each agent uses its specific prompt as system context
- **Conversation History**: Full message history is preserved
- **Auto-save**: Conversations can be saved with timestamps

### Tools System

The plugin includes a powerful tools system for extending functionality:

- **Tool Definition**: Each tool is defined in a Lua file with metadata and implementation
- **Parameter Validation**: Automatic type checking and required parameter validation
- **Error Handling**: Detailed error messages for tool execution failures
- **Extensible**: Easy to add new tools by creating Lua files

#### Built-in Tools

- **`list_files`**: Lists files in the workspace with filtering options
  - Parameters: `path`, `pattern`, `include_hidden`, `max_depth`
  - Example: `:AFTool list_files`

#### Tool Commands

- **`:AFTools`**: Load all available tools
- **`:AFTool <name>`**: Execute a specific tool
- **`:AFSchema`**: Export tools schema as JSON
- **`:AFPrompt`**: Generate AI agent prompt with tools
- **`<leader>aft`**: Quick keymap to load tools
- **`<leader>afS`**: Quick keymap to export tools schema
- **`<leader>afp`**: Quick keymap to generate AI prompt

#### Creating Custom Tools

Create a new tool by adding a Lua file to the `tools/` directory:

```lua
-- My Custom Tool
local M = {}

-- Tool metadata
M.name = "My Custom Tool"
M.description = "Description of what the tool does"
M.version = "1.0.0"
M.author = "agent-finder.nvim"

-- Tool parameters definition
M.parameters = {
  param1 = {
    type = "string",
    required = true,
    description = "Required string parameter"
  },
  param2 = {
    type = "number",
    required = false,
    default = 42,
    description = "Optional number parameter"
  }
}

-- Tool implementation
function M.execute(params)
  local param1 = params.param1
  local param2 = params.param2 or 42
  
  -- Validate parameters
  if not param1 then
    return { success = false, error = "param1 is required" }
  end
  
  -- Tool logic here
  local result = {
    success = true,
    data = {
      message = "Tool executed successfully",
      param1 = param1,
      param2 = param2
    }
  }
  
  return result
end

return M
```

### AI Integration

The plugin provides powerful AI integration features for working with external AI models:

#### Tool Schema Export

Generate JSON schemas for all available tools that can be sent to AI models:

```vim
:AFSchema    " Export tools schema as JSON
<leader>afS  " Quick keymap
```

This creates a JSON schema like:
```json
{
  "list_files": {
    "tool_name": "list_files",
    "description": "Lists all files in the current workspace directory with optional filtering",
    "parameters": {
      "type": "object",
      "properties": {
        "path": { "type": "string", "description": "Directory path to list files from" },
        "pattern": { "type": "string", "description": "File pattern to match" },
        "include_hidden": { "type": "boolean", "description": "Whether to include hidden files" },
        "max_depth": { "type": "number", "description": "Maximum directory depth to search" }
      },
      "required": []
    }
  }
}
```

#### AI Agent Prompt Generation

Generate a complete prompt for AI agents with tool schemas:

```vim
:AFPrompt    " Generate AI agent prompt
<leader>afp  " Quick keymap
```

This creates a prompt like:
```
I'd like to simulate an AI agent that I'm designing. The agent will be built using these components:

Goals:
* Find potential code enhancements
* Ensure changes are small and self-contained
* Get user approval before making changes
* Maintain existing interfaces

Available Tools:
[Tool schemas in JSON format]

At each step, your output must be an action to take using one of the available tools. 

Stop and wait and I will type in the result of the action as my next message.

Ask me for the first task to perform.
```

### Telescope Integration

The plugin integrates with [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for a better user experience:

- **`:AFList`**: Shows all available agents in a searchable list
- **`:AFSelect`**: Interactive agent selection with preview
- **`:AFChat`**: Select agent for chat interface
- **Preview**: Press `<C-p>` in Telescope to see the full agent prompt
- **Fallback**: If Telescope isn't available, commands fall back to command-line output

### Quick Keymap Workflow

```vim
<leader>afL  " List agents (Telescope) - auto-loads if needed
<leader>afs  " Select agent (Telescope) - auto-loads if needed
<leader>afc  " Start chat with agent - auto-loads if needed
<leader>aft  " Load tools
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
├── tools/                   # Tool definitions
│   └── list_files.lua       # Workspace file listing tool
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
