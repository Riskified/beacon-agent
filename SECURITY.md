# Security Policy

## Scope

This document covers the `beacon-integrate` Claude Code plugin — the skill file and install script distributed in this repository.

## What this plugin does and doesn't do

**Does:**
- Read files in the target codebase to detect framework and session variables
- Write/edit template and include files to inject the beacon snippet
- Run curl and local server commands to verify the integration
- Generate test files in the `tests/` directory

**Does not:**
- Transmit your codebase or session data to any external service
- Store or log session IDs beyond the local `beacon_audit.json`
- Require or handle Riskified API credentials
- Access any files outside the specified SITE_DIR (except reading framework tooling like `package.json`)

## Threat model

**Fraudster misuse:**
The beacon snippet and its session_id requirements are documented in Riskified's public developer docs. This plugin does not expose any non-public information about Riskified's fraud detection logic. It automates a documented integration process — it does not provide information that would help someone circumvent fraud detection.

**Supply chain:**
- The skill file (`beacon-integrate.md`) is a plain-text Markdown file — review it before installing
- The install script only downloads the skill file and places it in `~/.claude/commands/`
- No compiled binaries, no npm dependencies at runtime
- Pin to a specific commit hash for production use:
  ```bash
  curl -fsSL https://raw.githubusercontent.com/riskified/beacon-agent/<COMMIT_SHA>/beacon-integrate.md \
    -o ~/.claude/commands/beacon-integrate.md
  ```

**Codebase access:**
Claude Code will prompt for approval before writing any file. Do not use `--dangerously-skip-permissions` with this plugin in production environments.