#!/bin/bash
set -e

STATUSLINE_URL="https://raw.githubusercontent.com/SfilD/claude-statusline/main/statusline.sh"
DEST="$HOME/.claude/statusline.sh"
SETTINGS="$HOME/.claude/settings.json"

# Colors
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${GREEN}[+]${RESET} %s\n" "$1"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$1"; }
error() { printf "${RED}[x]${RESET} %s\n" "$1"; exit 1; }

# Check dependencies
for cmd in jq python3 curl; do
    if ! command -v "$cmd" &>/dev/null; then
        error "$cmd is required but not installed. Install it first."
    fi
done
info "Dependencies OK (jq, python3, curl)"

# Create ~/.claude if needed
mkdir -p "$HOME/.claude"

# Download or copy statusline.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/statusline.sh" ]; then
    cp "$SCRIPT_DIR/statusline.sh" "$DEST"
    info "Copied statusline.sh from local directory"
else
    curl -fsSL "$STATUSLINE_URL" -o "$DEST"
    info "Downloaded statusline.sh"
fi

chmod +x "$DEST"

# Update settings.json
if [ -f "$SETTINGS" ]; then
    if jq -e '.statusLine' "$SETTINGS" &>/dev/null; then
        warn "statusLine already configured in settings.json - skipping"
        warn "Current config: $(jq -c '.statusLine' "$SETTINGS")"
    else
        tmp=$(mktemp)
        jq '. + {"statusLine": {"type": "command", "command": "bash ~/.claude/statusline.sh"}}' "$SETTINGS" > "$tmp"
        mv "$tmp" "$SETTINGS"
        info "Added statusLine to existing settings.json"
    fi
else
    cat > "$SETTINGS" << 'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
EOF
    info "Created settings.json with statusLine config"
fi

echo ""
printf "${BOLD}${GREEN}Done!${RESET} Restart Claude Code to see the statusline.\n"
echo ""
echo "What you'll see:"
echo "  [Model] | ━━━━━━ 25% (50K/200K) | H:78% 1h34m W:87% | project | git:(main) | ⏱ 12m"
echo ""
echo "To remove: /statusline remove it"
