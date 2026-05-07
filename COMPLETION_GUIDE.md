# calctl Bash Completion Guide

## Installation

### Option 1: Source in current shell
```bash
source /path/to/calctl-completion.bash
```

### Option 2: Add to your shell profile
Add this line to `~/.bashrc` or `~/.zshrc`:
```bash
source /path/to/calctl-completion.bash
```

### Option 3: Install system-wide (requires sudo)
```bash
# For Bash
sudo cp calctl-completion.bash /etc/bash_completion.d/calctl

# For user-specific (no sudo needed)
mkdir -p ~/.local/share/bash-completion/completions
cp calctl-completion.bash ~/.local/share/bash-completion/completions/calctl
```

## Features

### Command Completion
Type `calctl ` and press TAB to see available commands:
- `agent`
- `operation`
- `lab`
- `inventory`
- `config`

### Subcommand Completion
Type `calctl <command> ` and press TAB to see subcommands:

```bash
calctl agent <TAB>
# Completes: list, check, wait, get, help

calctl operation <TAB>
# Completes: create, list, status, resume, pause, monitor, summary, failures, export, delete, help

calctl lab <TAB>
# Completes: run, manual, list, help

calctl inventory <TAB>
# Completes: courses, labs, show, add, help

calctl config <TAB>
# Completes: init, show, check, set, help
```

### Flag Completion
Type `calctl --` and press TAB to see global flags:
- `--help`
- `--version`
- `--verbose`
- `--quiet`
- `--no-color`
- `--dry-run`
- `--format`

### Format Option Completion
```bash
calctl --format <TAB>
# Completes: table, json, summary
```

### Dynamic Argument Completion

#### Course Names
```bash
calctl lab run <TAB>
# Completes: mycourse (and other courses from your inventory)

calctl inventory labs <TAB>
# Completes: mycourse (and other courses from your inventory)
```

#### Lab IDs
```bash
calctl lab run mycourse <TAB>
# Completes: lab-01, lab-02 (lab IDs for the course)

calctl inventory show mycourse <TAB>
# Completes: lab-01, lab-02 (based on your inventory)
```

#### Config Keys
```bash
calctl config set <TAB>
# Completes: CALDERA_API, ADVERSARY_INVENTORY, NO_COLOR, VERBOSE, QUIET
```

## How It Works

The completion script:
1. Detects the current command context
2. Determines what arguments are valid for that position
3. For dynamic completions (courses, lab IDs), it calls `calctl` to query the inventory
4. Returns appropriate completions based on context

## Requirements

- Bash or Zsh shell
- `calctl` must be in PATH or completion script must know its location
- For dynamic completions: `jq` must be installed
- For lab completions: `adversaries.yml` must be accessible

## Troubleshooting

### Completion not working
1. Verify the script is sourced:
   ```bash
   complete -p calctl
   ```
   Should show: `complete -F _calctl_completion calctl`

2. Reload your shell or source the script again:
   ```bash
   source calctl-completion.bash
   ```

### Dynamic completions (courses/labs) not working
1. Verify `calctl` is in PATH:
   ```bash
   which calctl
   ```

2. Verify `jq` is installed:
   ```bash
   which jq
   ```

3. Test inventory commands manually:
   ```bash
   calctl --format json inventory courses
   calctl --format json inventory labs mycourse
   ```

### Completion is slow
Dynamic completions query the inventory, which may be slow for large inventories. The script caches nothing, so each TAB press re-queries. This is by design to ensure fresh data.
