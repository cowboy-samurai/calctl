# calctl Quick Reference

## One-Liners

```bash
# Quick health check
calctl agent check && calctl config check

# Run a lab
calctl lab run mycourse lab-01

# List all labs with JSON
calctl --format json inventory labs mycourse | jq

# Preview without executing
calctl --dry-run lab run mycourse lab-02

# Export operation results
calctl operation export $OP_ID results.json
```

## Commands

### Global Flags
```bash
--help              # Show help
--version           # Show version
--verbose           # Verbose output
--quiet             # Quiet mode
--no-color          # Disable colors
--dry-run           # Preview only
--format <type>     # Output format: table, json, summary
```

### Agent
```bash
calctl agent list                    # List all agents
calctl agent check                   # Check Windows agent health
calctl agent get <paw>               # Get agent details
calctl agent wait <timeout>          # Wait for agent
```

### Operation
```bash
calctl operation create <name> <adv-id>   # Create operation
calctl operation list                     # List operations
calctl operation status <op-id>           # Get status
calctl operation resume <op-id>           # Resume operation
calctl operation pause <op-id>            # Pause operation
calctl operation monitor <op-id>          # Monitor until complete
calctl operation summary <op-id>          # Show summary
calctl operation failures <op-id>         # Show failures
calctl operation export <op-id> <file>    # Export to JSON
calctl operation delete <op-id>           # Delete operation
```

### Lab
```bash
calctl lab run <course> <lab-id>          # Automation mode
calctl lab manual <course> <lab-id>       # Manual mode
calctl lab list <course>                  # List labs
```

### Inventory
```bash
calctl inventory courses                  # List courses
calctl inventory labs <course>            # List labs
calctl inventory show <course> <lab-id>   # Show lab details
calctl inventory add <course>             # Add new lab (interactive)
```

### Config
```bash
calctl config init                        # Initialize config
calctl config show                        # Show current config
calctl config check                       # Check server
calctl config set <key> <value>           # Set config value
```

## Common Workflows

### Developer Testing
```bash
calctl config init
calctl agent check
calctl inventory labs mycourse
calctl lab manual mycourse lab-01 60
```

### Automation Workflow (CI/CD)
```bash
export CALDERA_API_KEY="your-api-key-here"
calctl lab run mycourse lab-01 /tmp/results
echo $?  # Check exit code
```

### Dry-Run Testing
```bash
calctl --dry-run lab run mycourse lab-02
calctl --dry-run operation create "Test Lab" "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### JSON Scripting
```bash
calctl --format json inventory labs mycourse | jq -r '.[].id'
calctl --format json operation status <op-id> | jq '.state'
```

## Exit Codes

```
0   Success (75-100% success rate)
1   Partial success (25-74%)
2   Low success (0-24%)
3   Agent health check failed
4   Operation creation failed
5   Operation timeout
6   Invalid inventory (lab not found)
```

## Environment Variables

```bash
CALDERA_API_KEY              # API key (recommended)
CALDERA_API_URL              # API endpoint override (default: http://localhost:8888/api/rest)
CALDERA_CONFIG_PATH          # Path to Caldera config file
ADVERSARY_INVENTORY_PATH     # Inventory file override
```

## Configuration

### File Locations
```
/etc/calctl/config           # System config
~/.config/calctl/config      # User config (created by config init)
```

### Precedence
```
Environment Variables > User Config > System Config > Defaults
```

## Bash Completion

```bash
# Source in shell
source calctl-completion.bash

# Add to profile
echo "source /path/to/calctl-completion.bash" >> ~/.bashrc
```

## Available Labs (Example)

```
mycourse:
  lab-01  - Example Lab: Initial Access         [3 abilities, ~120s, 90%]
  lab-02  - Example Lab: Persistence            [5 abilities, ~180s, 85%]
```

Note: This is a placeholder. Populate `adversaries.json` with your actual courses.
Use `calctl inventory courses` to see all configured courses.
Use `calctl inventory labs <course>` to see labs for a specific course.

## Tips

- Use `--verbose` to debug issues
- Use `--dry-run` before running destructive operations
- Use `--format json` for scripting and automation
- Store API keys in environment variables, not config files
- Use tab completion to discover available commands
- Check `calctl <command> --help` for detailed help
