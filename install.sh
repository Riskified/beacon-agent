#!/usr/bin/env bash
set -e

REPO="https://raw.githubusercontent.com/riskified/beacon-agent/main"
DEST="$HOME/.claude/commands"
FILE="beacon-integrate.md"
LOG="$HOME/.riskified-beacon-installs.log"

# ── Check Claude Code ──────────────────────────────────────────────────────
if ! command -v claude &> /dev/null; then
  echo ""
  echo "  ✗  Claude Code not found."
  echo "     Install it from https://claude.ai/download then re-run this script."
  exit 1
fi

# ── Acknowledgment ─────────────────────────────────────────────────────────
echo ""
echo "  Riskified Beacon Integration — Claude Code Plugin"
echo "  ─────────────────────────────────────────────────"
echo ""
echo "  This plugin writes code into your storefront codebase."
echo "  Before continuing, confirm you understand the following:"
echo ""
echo "    1. Always run this in a staging or development environment first."
echo "    2. Review every file change before deploying to production."
echo "    3. Supported frameworks only: Flask, PHP, Node/Express, React + Vite."
echo "       Results on other stacks are undefined."
echo "    4. Riskified provides this plugin as-is with no warranty."
echo "       Riskified is not liable for production issues arising from its use."
echo ""
echo "  Full terms: https://github.com/riskified/beacon-agent#disclaimer"
echo ""
printf "  Type AGREE to accept and continue: "
read -r REPLY

if [ "$REPLY" != "AGREE" ]; then
  echo ""
  echo "  Installation cancelled."
  echo ""
  exit 1
fi

# ── Write acknowledgment record (before download — survives any install error) ──
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
PLUGIN_VERSION="1.0.0"

cat >> "$LOG" << EOF
---
timestamp:  $TIMESTAMP
user:       $(whoami)
hostname:   $(hostname)
plugin:     beacon-integrate v$PLUGIN_VERSION
agreed:     AGREE
terms_url:  https://github.com/riskified/beacon-agent#disclaimer
EOF

# ── Install ────────────────────────────────────────────────────────────────
mkdir -p "$DEST"
curl -fsSL "$REPO/$FILE" -o "$DEST/$FILE"

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo "  ✓  Installed to $DEST/$FILE"
echo "  ✓  Acknowledgment logged to $LOG"
echo ""
echo "  Usage — open Claude Code in your project and run:"
echo ""
echo "    /beacon-integrate /path/to/your/store www.yourshop.com"
echo ""
