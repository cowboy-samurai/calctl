# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-06

### Added - Initial Release

#### Core Features
- **CLI Interface**: `kubectl`-style command-line interface for Caldera operations
- **Subcommands**: Organized commands for agent, operation, lab, inventory, and config management
- **Configuration System**: Multi-level config files (system, user, environment variables)
- **Flexible API Detection**: Auto-detects Caldera config from multiple standard locations
- **Inventory Management**: JSON-based adversary profile inventory system
- **Output Formats**: Table (default), JSON, and summary output modes
- **Dry-Run Mode**: Preview operations before execution
- **Bash Completion**: Tab completion for commands, flags, and dynamic arguments
- **Colored Output**: Clear visual feedback with optional `--no-color` flag

#### Agent Management
- List all connected agents
- Check agent health with configurable thresholds
- Wait for agent connections with timeout
- Get detailed agent information by PAW

#### Operation Management
- Create operations in paused or running state
- List and query operations
- Resume, pause, and monitor operations
- Real-time execution monitoring with progress updates
- Detailed execution summaries and failure analysis
- Export operation results to JSON

#### Lab Workflows
- **Automation Mode**: Fully automated workflow for CI/CD and unattended execution
  - Agent health check
  - Operation creation and monitoring
  - Automatic result export
  - Exit codes for success/failure detection
- **Manual Mode**: Interactive workflow for development and testing
  - Pause between creation and execution
  - Manual resume control
  - Interactive cleanup prompts

#### Inventory System
- `inventory init`: Initialize inventory from example template
- `inventory validate`: Validate JSON structure and required fields
- `inventory courses`: List all configured courses
- `inventory labs`: List labs for a specific course
- `inventory show`: Display lab metadata
- `inventory add`: Interactive adversary template creator

#### Configuration Management
- `config init`: Create default configuration file
- `config show`: Display current configuration sources
- `config check`: Verify Caldera server connectivity
- `config set`: Update configuration values
- Environment variable support for all settings

### Design Principles

#### Vendor Agnostic
- Generic terminology (no vendor-specific references)
- Flexible inventory structure supporting any training course
- Configurable Caldera installation paths
- Works with any Caldera deployment

#### Flexible Configuration
- Multiple config file locations with precedence
- Environment variable overrides
- Auto-detection of Caldera configuration
- Custom inventory file paths

#### Automation-Friendly
- JSON output for parsing and scripting
- Meaningful exit codes for CI/CD integration
- Dry-run mode for testing
- Backwards compatibility aliases

#### User-Friendly
- Intuitive command structure
- Comprehensive help text
- Colored output for readability
- Tab completion for discoverability
- Verbose mode for debugging

### Configuration

#### Environment Variables
- `CALDERA_API_URL`: Caldera API endpoint (default: http://localhost:8888/api/rest)
- `CALDERA_API_KEY`: API authentication key
- `CALDERA_CONFIG_PATH`: Custom path to Caldera config file
- `ADVERSARY_INVENTORY_PATH`: Custom path to inventory file

#### Config File Locations (in precedence order)
1. Environment variables
2. `~/.config/calctl/config` (user config)
3. `/etc/calctl/config` (system config)
4. Built-in defaults

#### Caldera Config Detection
Automatically searches:
- `/opt/caldera/conf/local.yml`
- `/etc/caldera/local.yml`
- `~/.caldera/conf/local.yml`
- `./conf/local.yml`
- Custom path via `CALDERA_CONFIG_PATH`

### Installation Options

1. **In-place usage**: Run directly from repository
2. **User installation**: Install to `~/.local/bin` and `~/.local/lib/calctl`
3. **System-wide installation**: Install to `/usr/local/bin` and `/usr/local/lib/calctl`

### Exit Codes

- `0`: Success (75-100% operation success rate)
- `1`: Partial success (25-74% success rate)
- `2`: Low success (0-24% success rate)
- `3`: Agent health check failed
- `4`: Operation creation failed
- `5`: Operation timeout
- `6`: Invalid inventory (lab not found)

### Dependencies

- **bash**: Shell interpreter (required)
- **curl**: HTTP requests to Caldera API (required)
- **jq**: JSON parsing (required)
- **bash-completion**: Enhanced tab completion (optional)

### Documentation

- `README.md`: Comprehensive user guide
- `QUICK_REFERENCE.md`: Quick command reference
- `COMPLETION_GUIDE.md`: Bash completion setup and usage
- `CONTRIBUTING.md`: Contribution guidelines
- `CHANGELOG.md`: Version history (this file)

### Files

- `calctl`: Main CLI executable
- `caldera_api_lib.sh`: Function library for API interactions
- `adversaries.json`: Empty inventory template (user-editable)
- `adversaries.example.json`: Example inventory with placeholders
- `calctl-completion.bash`: Bash completion script

### Notes

This release represents a complete refactoring to be vendor-agnostic and suitable for the broader Caldera community. The tool maintains full backwards compatibility through function aliases while introducing modern, generic terminology.

---

## Version History

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Future Releases

See the project roadmap in `README.md` for planned features and enhancements.

[1.0.0]: https://github.com/your-org/calctl/releases/tag/v1.0.0
