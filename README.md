# calctl - Caldera Control CLI
A command-line tool for managing [MITRE Caldera](https://caldera.mitre.org/) operations. Provides a user-friendly interface to the Caldera REST API with built-in workflows for automation.

## Features

- 🎯 **Subcommand-based interface** - Intuitive `kubectl`-style commands
- 🔧 **Config file support** - System and user configuration files  
- 🔍 **Dry-run mode** - Preview operations before execution
- 📊 **Multiple output formats** - Table, JSON, and summary views
- 🚀 **Lab automation** - Built-in workflows for training labs and CI/CD
- 📦 **JSON inventory** - Centralized lab metadata management
- ⚡ **Bash completion** - Tab completion for commands, flags, and arguments
- 🎨 **Colored output** - Clear visual feedback (can be disabled)

## Quick Start

```bash
# Check version
./calctl --version

# Initialize configuration
./calctl config init

# List available courses
./calctl inventory courses

# Run a lab (automation mode)
./calctl lab run mycourse lab-01

# Check agent health
./calctl agent check

# Preview a lab run (dry-run)
./calctl --dry-run lab run mycourse lab-02
```

## Installation

calctl automatically detects library and inventory files in multiple locations, supporting development, user, and system-wide installations.

### Option 1: Use in place (recommended for testing)
```bash
cd /path/to/instruqt
./calctl --help
```

Files are loaded from the same directory as the executable.

### Option 2: User installation
```bash
# Copy to local bin and lib
mkdir -p ~/.local/bin ~/.local/lib/calctl
cp calctl ~/.local/bin/
cp caldera_api_lib.sh ~/.local/lib/calctl/
cp adversaries.json ~/.local/lib/calctl/

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"

# Now you can use it anywhere
calctl --help
```

Library files are automatically detected in `~/.local/lib/calctl/`.

### Option 3: System-wide installation (requires sudo)
```bash
sudo cp calctl /usr/local/bin/
sudo mkdir -p /usr/local/lib/calctl
sudo cp caldera_api_lib.sh /usr/local/lib/calctl/
sudo cp adversaries.json /usr/local/lib/calctl/
```

Library files are automatically detected in `/usr/local/lib/calctl/`.

### Bash Completion Setup

```bash
# Source in current shell
source calctl-completion.bash

# Or add to your shell profile
echo "source /path/to/calctl-completion.bash" >> ~/.bashrc
# or for zsh
echo "source /path/to/calctl-completion.bash" >> ~/.zshrc
```

See [COMPLETION_GUIDE.md](COMPLETION_GUIDE.md) for detailed completion documentation.

## Configuration

### Initialize Config File

```bash
calctl config init
```

This creates `~/.config/calctl/config` with default settings.

### Configuration Files

calctl loads configuration in this order (later overrides earlier):
1. System config: `/etc/calctl/config`
2. User config: `~/.config/calctl/config`
3. Environment variables

### Environment Variables

- `CALDERA_API_URL` - Override Caldera API endpoint (default: http://localhost:8888/api/rest)
- `CALDERA_API_KEY` - Set API key (recommended over config file)
- `CALDERA_CONFIG_PATH` - Path to Caldera config file for auto-detection
- `ADVERSARY_INVENTORY_PATH` - Override inventory file location

**Security Note**: Never store API keys in config files. Use environment variables:

```bash
export CALDERA_API_KEY="your-api-key-here"
calctl config show
```

### Caldera Configuration Detection

calctl automatically searches for Caldera config files in these locations:
- `/opt/caldera/conf/local.yml`
- `/etc/caldera/local.yml`
- `~/.caldera/conf/local.yml`
- `./conf/local.yml`

Set `CALDERA_CONFIG_PATH` to specify a custom location.

### Configuration Management

```bash
# Show current configuration
calctl config show

# Set configuration values
calctl config set CALDERA_API "http://localhost:8888/api/rest"
calctl config set VERBOSE 1

# Check Caldera server connection
calctl config check
```

## Usage

### Global Flags

```bash
-h, --help              Show help message
-v, --version           Show version information
--verbose               Enable verbose output
--quiet                 Suppress non-essential output
--no-color              Disable colored output
--dry-run               Preview operations without executing
--format <type>         Output format: table, json, summary
```

### Agent Management

```bash
# List all agents
calctl agent list

# Check Windows agent health
calctl agent check

# Get specific agent details
calctl agent get <paw>

# Wait for agent to connect (5 min timeout)
calctl agent wait 300
```

### Operation Management

```bash
# Create operation (paused state)
calctl operation create "Lab 3.2(A)" "31d8a88e-fbce-46a8-89b7-742cf4b6b2db"

# List all operations
calctl operation list
calctl --format json operation list  # JSON output

# Get operation status
calctl operation status <operation-id>

# Resume/pause operation
calctl operation resume <operation-id>
calctl operation pause <operation-id>

# Monitor until complete
calctl operation monitor <operation-id>

# Show execution summary
calctl operation summary <operation-id>

# Show failure details
calctl operation failures <operation-id>

# Export results to JSON
calctl operation export <operation-id> results.json

# Delete operation
calctl operation delete <operation-id>
```

### Lab Workflows

#### Automation Mode (for CI/CD and unattended execution)

Fully automated workflow: agent check → create → monitor → export

```bash
# Run lab automation
calctl lab run mycourse lab-01

# Run with custom output directory
calctl lab run mycourse lab-02 /tmp/results

# Preview what would happen (dry-run)
calctl --dry-run lab run mycourse lab-02
```

**Exit Codes:**
- `0` - Success (75-100% success rate)
- `1` - Partial success (25-74%)
- `2` - Low success (0-24%)
- `3` - Agent health check failed
- `4` - Operation creation failed
- `5` - Operation timeout
- `6` - Invalid inventory (lab not found)

#### Manual Mode (for developer testing)

Interactive workflow: create paused → wait → resume → monitor → cleanup prompt

```bash
# Run lab in manual mode (60s wait for environment setup)
calctl lab manual mycourse lab-01 60

# Custom wait time (120s)
calctl lab manual mycourse lab-02 120
```

#### List Labs

```bash
# List all labs for a course
calctl lab list mycourse

# JSON output
calctl --format json lab list mycourse
```

### Inventory Management

```bash
# List all courses
calctl inventory courses

# List labs for a course
calctl inventory labs esend
calctl --format json inventory labs esend  # JSON output

# Show specific lab metadata
calctl inventory show esend 3.2a
calctl --format json inventory show esend 3.2a  # JSON output

# Add new adversary template (interactive)
calctl inventory add esend
```

## Output Formats

### Table (default)
Human-readable formatted output with colors.

```bash
calctl inventory labs esend
```

### JSON
Machine-readable JSON for scripting and automation.

```bash
calctl --format json inventory labs esend | jq '.[].id'
calctl --format json operation status <op-id> | jq '.state'
```

### Summary
Compact summary view (not fully implemented for all commands).

```bash
calctl --format summary operation list
```

## Common Workflows

### Developer Testing Workflow

```bash
# 1. Initialize and check configuration
calctl config init
calctl config check

# 2. Check agent health
calctl agent check

# 3. List available labs
calctl inventory labs mycourse

# 4. Run lab in manual mode (gives time to configure environment)
calctl lab manual mycourse lab-01 60

# 5. Review results in Caldera Web UI
```

### Automation Workflow (CI/CD)

```bash
# 1. Set API key via environment variable
export CALDERA_API_KEY="your-api-key-here"

# 2. Run lab automation
calctl lab run mycourse lab-01 /tmp/results

# 3. Check exit code
echo $?

# 4. Review exported results
cat /tmp/results/operation_*.json | jq '.execution'
```

### Dry-Run Testing

```bash
# Preview lab run
calctl --dry-run lab run esend 3.2c

# Preview operation creation
calctl --dry-run operation create "Test" "abc-123"

# Preview operation deletion
calctl --dry-run operation delete <op-id>
```

### Scripting with JSON Output

```bash
# Get all lab IDs for a course
calctl --format json inventory labs mycourse | jq -r '.[].id'

# Check if agent is alive
if calctl agent check >/dev/null 2>&1; then
    echo "Agent is healthy"
else
    echo "Agent health check failed"
    exit 1
fi

# Monitor operation and parse results
calctl --format json operation status <op-id> | jq '{
    state: .state,
    progress: "\(.chain | length)/\(.adversary.atomic_ordering | length)"
}'
```

## Inventory System

Lab metadata is stored in `adversaries.json` or `adversaries.example.json`:

```json
{
  "courses": {
    "mycourse": {
      "name": "My Training Course",
      "organization": "Your Organization",
      "labs": [
        {
          "id": "lab-01",
          "adversary_id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
          "name": "Example Lab: Initial Access",
          "abilities": 3,
          "duration_seconds": 120,
          "success_rate": "90%",
          "notes": "Your lab description here"
        }
      ]
    }
  }
}
```

### Adding New Labs

```bash
# Interactive template creator
calctl inventory add mycourse

# Or edit adversaries.json directly
vim adversaries.json
```

## Troubleshooting

### API Key Not Set

```bash
# Check current configuration
calctl config show

# Set via environment variable (recommended)
export CALDERA_API_KEY="your-key-here"

# Or let calctl auto-detect from Caldera config
calctl config init  # Auto-detects from standard locations
```

### Caldera Config Not Found

```bash
# Set custom config path
export CALDERA_CONFIG_PATH="/path/to/caldera/conf/local.yml"

# Or specify in user config
calctl config set CALDERA_CONFIG_PATH "/custom/path/local.yml"
```

### Agent Not Found

```bash
# Check agent status
calctl agent check

# Wait for agent to connect
calctl agent wait 300

# Verify agent is running on target system
# (Check Sandcat or other agent deployment)
```

### Lab Not Found

```bash
# Verify lab exists in inventory
calctl inventory labs mycourse

# Add missing lab to inventory
calctl inventory add mycourse
```

### Completion Not Working

```bash
# Source the completion script
source calctl-completion.bash

# Verify registration
complete -p calctl

# For dynamic completions (courses/labs), ensure jq is installed
which jq
```

### Verbose Mode for Debugging

```bash
# Enable verbose output
calctl --verbose lab run mycourse lab-01

# Shows:
# - Config file loading
# - API key detection  
# - Inventory loading
# - Detailed progress
```

## Migration from Direct API Usage

If you were previously using Caldera REST API directly or via shell scripts:

### Old Way
```bash
# Direct curl commands
curl -X POST "$CALDERA_API" -H "KEY: $API_KEY" -d '{...}'

# Or sourced library
source caldera_api_lib.sh
set_api_key
check_windows_agent
run_lab_operation "Lab Name" "adversary-id"
```

### New Way
```bash
export CALDERA_API_KEY="your-key"
calctl agent check
calctl lab run mycourse lab-01
```

## Dependencies

- **bash** - Shell interpreter
- **curl** - HTTP requests to Caldera API
- **jq** - JSON parsing

Optional:
- **bash-completion** - For enhanced tab completion

## Architecture

```
calctl (CLI wrapper)
  ├─ Sources: caldera_api_lib.sh (function library)
  ├─ Reads: adversaries.json (lab inventory)
  ├─ Config: ~/.config/calctl/config (user settings)
  └─ Calls: Caldera REST API (http://localhost:8888/api/rest)
```

## Version

Current version: **1.0.0**

```bash
calctl --version
```

## Support

For issues or questions:
1. Check this README
2. Review [COMPLETION_GUIDE.md](COMPLETION_GUIDE.md)
3. Use `--verbose` flag for debugging
4. Check Caldera server logs

## License

Internal tool for Elastic Security training labs.
