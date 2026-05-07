# Contributing to calctl

Thank you for considering contributing to calctl! This document provides guidelines and instructions for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)
- [Feature Requests](#feature-requests)

## Code of Conduct

This project follows the standard open-source code of conduct:

- Be respectful and inclusive
- Welcome newcomers and help them get started
- Focus on constructive feedback
- Prioritize the community's best interests

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **bash** (version 4.0+)
- **curl**
- **jq**
- **git**
- A working [Caldera](https://github.com/mitre/caldera) installation for testing

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/calctl.git
   cd calctl
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/original-org/calctl.git
   ```

### Development Setup

1. Make the script executable:
   ```bash
   chmod +x calctl
   ```

2. Test that it works:
   ```bash
   ./calctl --version
   ./calctl --help
   ```

3. Source the completion script for development:
   ```bash
   source calctl-completion.bash
   ```

## Development Workflow

### Creating a Branch

Create a feature branch for your changes:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions/updates

### Making Changes

1. **Keep changes focused**: One feature or fix per branch
2. **Test thoroughly**: Ensure your changes work as expected
3. **Update documentation**: Update README.md, help text, and comments
4. **Follow coding standards**: See [Coding Standards](#coding-standards) below

### Staying Up to Date

Regularly sync with the upstream repository:

```bash
git fetch upstream
git rebase upstream/main
```

## Coding Standards

### Bash Style Guide

We follow the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) with these highlights:

#### General

- Use **4 spaces** for indentation (no tabs)
- Maximum line length: **100 characters**
- Use **lowercase** with **underscores** for function and variable names
- Use **UPPERCASE** for constants and environment variables

#### Functions

```bash
# Good: Descriptive name with underscore separators
function get_operation_status() {
    local op_id="${1:-$OPERATION_ID}"
    
    # Function body
}

# Bad: CamelCase or unclear name
function getOpStatus() {
    # ...
}
```

#### Error Handling

- Use `set -euo pipefail` at the top of scripts
- Check return codes explicitly for important operations
- Provide helpful error messages

```bash
if ! create_operation "$name" "$adversary_id"; then
    echo -e "${RED}[!] Failed to create operation${NC}"
    return 1
fi
```

#### Comments

- Use comments to explain **why**, not **what**
- Add section headers for major groups of functions
- Document function parameters and return values

```bash
# Function: Check agent health (fail-fast for automation workflows)
# Parameters:
#   $1 - max_age_seconds (optional, default: 180)
# Returns:
#   0 - Agent is alive
#   3 - Agent health check failed
check_agent_health() {
    # ...
}
```

#### Variables

- Quote all variables: `"$variable"` not `$variable`
- Use `local` for function-scoped variables
- Use `readonly` for constants

```bash
readonly VERSION="1.0.0"
local temp_file=$(mktemp)
echo "Processing $temp_file"
```

### Code Organization

#### File Structure

- `calctl`: Main CLI entry point
  - Argument parsing
  - Command routing
  - Help text
  - Configuration loading

- `caldera_api_lib.sh`: API functions library
  - Section 1: Setup and Configuration
  - Section 2: Agent Management
  - Section 3: Operation Management - Creation
  - Section 4: Operation Management - State Control
  - Section 5: Operation Monitoring
  - Section 6: Operation Cleanup
  - Section 7: Automation Workflows
  - Section 8: Adversary Profiles Reference
  - Section 9: Usage Examples

#### Adding New Commands

1. Add subcommand to help text in `calctl`
2. Add case statement in command handler
3. Implement function in `caldera_api_lib.sh` if needed
4. Update bash completion in `calctl-completion.bash`
5. Add documentation to `README.md`
6. Update `CHANGELOG.md`

#### Adding New Features

1. Discuss in an issue first for major changes
2. Keep backwards compatibility when possible
3. Add aliases for renamed functions
4. Update all relevant documentation

### Documentation Standards

#### Help Text

- Keep help text concise and scannable
- Provide clear examples
- Document all flags and parameters
- Use consistent formatting

#### README Updates

When adding features, update:
- Quick Start examples if applicable
- Usage section with new commands
- Common Workflows if introducing new patterns
- Troubleshooting section for known issues

#### Code Comments

- Comment complex logic
- Explain non-obvious behavior
- Document API expectations
- Note any workarounds or hacks

## Testing

### Manual Testing

Test your changes against a live Caldera installation:

```bash
# 1. Set up test environment
export CALDERA_API_KEY="test-key"
export CALDERA_API_URL="http://localhost:8888/api/rest"

# 2. Test basic functionality
./calctl config check
./calctl agent check
./calctl inventory courses

# 3. Test new features
./calctl your-new-command

# 4. Test error conditions
./calctl your-new-command invalid-input
```

### Test Checklist

Before submitting, verify:

- [ ] `./calctl --help` works correctly
- [ ] All subcommands have working `--help`
- [ ] Dry-run mode works for destructive operations
- [ ] JSON output is valid (pipe through `jq`)
- [ ] Verbose mode provides useful debug info
- [ ] Error messages are clear and actionable
- [ ] Tab completion works (test with bash-completion)
- [ ] Works with empty inventory
- [ ] Works with populated inventory
- [ ] No shell syntax errors (`shellcheck calctl caldera_api_lib.sh`)

### ShellCheck

Run ShellCheck on your changes:

```bash
shellcheck calctl caldera_api_lib.sh calctl-completion.bash
```

Address any warnings or errors before submitting.

## Submitting Changes

### Commit Messages

Write clear, descriptive commit messages:

```
Short summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what changed and why, not how.

- Bullet points are okay
- Use present tense: "Add feature" not "Added feature"
- Reference issues: "Fixes #123" or "Related to #456"
```

Good examples:
```
Add inventory validate command

Adds 'calctl inventory validate' to check JSON structure and required
fields. Validates courses object exists and each lab has required id,
adversary_id, and name fields.

Fixes #42
```

```
Fix agent health check threshold calculation

The threshold was incorrectly using seconds instead of the sleep_max
value from agent data. Now properly calculates threshold as sleep_max * 3.
```

### Pull Request Process

1. **Update documentation**: Ensure README.md, help text, and comments are current
2. **Update CHANGELOG.md**: Add entry under "Unreleased" section
3. **Test thoroughly**: Follow the [Testing](#testing) checklist
4. **Push to your fork**: `git push origin feature/your-feature`
5. **Create Pull Request** on GitHub with:
   - Clear title summarizing the change
   - Description of what changed and why
   - Link to related issues
   - Screenshots for UI changes (if applicable)
6. **Respond to feedback**: Address review comments promptly
7. **Squash commits**: If requested, squash into logical commits

### PR Review Criteria

Maintainers will check:

- Code quality and style compliance
- Test coverage and manual testing
- Documentation completeness
- Backwards compatibility
- Performance impact
- Security implications

## Reporting Issues

### Bug Reports

When reporting bugs, include:

- **calctl version**: `./calctl --version`
- **Caldera version**: From Caldera UI or logs
- **Operating system**: macOS, Linux distro, etc.
- **Shell version**: `bash --version`
- **Steps to reproduce**
- **Expected behavior**
- **Actual behavior**
- **Error messages**: Use `--verbose` for details
- **Relevant config**: Sanitized config settings

Template:
```markdown
**calctl version:** 1.0.0
**Caldera version:** 5.2.0
**OS:** macOS 14.0
**Shell:** bash 5.2.21

**Steps to reproduce:**
1. Run `calctl lab run mycourse lab-01`
2. ...

**Expected:** Operation should complete successfully

**Actual:** Operation times out with error...

**Error output:**
```
[paste error here]
```
```

### Security Issues

**Do not open public issues for security vulnerabilities.**

Instead, email the maintainers directly at [security@example.com] with:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Feature Requests

We welcome feature requests! When requesting features:

1. **Search existing issues** first
2. **Explain the use case**: Why is this needed?
3. **Describe the feature**: What should it do?
4. **Provide examples**: Mock command usage
5. **Consider alternatives**: What other approaches exist?

Template:
```markdown
**Use case:**
I need to [accomplish some task] because [reason].

**Proposed solution:**
Add a new command: `calctl feature do-thing`

Example usage:
```bash
calctl feature do-thing --option value
```

**Alternatives considered:**
- Could use existing command X, but it doesn't...
- Tried workaround Y, but it requires...

**Additional context:**
This would be especially useful for [scenario].
```

## Development Tips

### Debugging

Use verbose mode and dry-run for development:

```bash
./calctl --verbose --dry-run lab run mycourse lab-01
```

Add debug output in your code:

```bash
if [ "$VERBOSE" -eq 1 ]; then
    echo -e "${BLUE}[DEBUG] Variable value: $my_var${NC}"
fi
```

### Testing with Docker

Test in a clean environment:

```bash
docker run -it --rm -v "$PWD:/calctl" ubuntu:latest bash
cd /calctl
apt-get update && apt-get install -y curl jq
./calctl --help
```

### Common Development Tasks

```bash
# Check syntax without running
bash -n calctl

# Run shellcheck
shellcheck calctl caldera_api_lib.sh

# Test JSON output
./calctl --format json inventory courses | jq

# Test completion
source calctl-completion.bash
calctl <TAB><TAB>

# Test dry-run mode
./calctl --dry-run operation delete test-id
```

## Questions?

- Open an issue for general questions
- Check existing issues and PRs
- Review documentation in README.md
- Join the discussion in [relevant forum/chat]

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

---

Thank you for contributing to calctl! Your efforts help make this tool better for the entire Caldera community.
