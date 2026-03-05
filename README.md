[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![Русский](https://img.shields.io/badge/lang-Русский-red.svg)](README.ru.md)

<h1 align="center">claude-statusline</h1>

<p align="center">
  A rich statusline for Claude Code — model, context, usage limits, git, session time.<br>
  Cross-platform. One command to install.
</p>

<p align="center">
  <a href="https://github.com/SfilD/claude-statusline/blob/main/LICENSE"><img src="https://img.shields.io/github/license/SfilD/claude-statusline?style=flat-square&color=green" alt="License"></a>
  <img src="https://img.shields.io/badge/bash-script-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash">
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue?style=flat-square" alt="Platform">
  <a href="https://github.com/SfilD/claude-statusline/stargazers"><img src="https://img.shields.io/github/stars/SfilD/claude-statusline?style=flat-square&color=yellow" alt="Stars"></a>
</p>

---

<p align="center">
  <img src="screenshot.jpg" alt="statusline screenshot">
</p>

## What it shows

| Segment | Example | Description |
|---------|---------|-------------|
| Model | `[Opus 4.6]` | Current model name |
| Context bar | `━━━━━━ 25% (50K/200K)` | Visual progress bar with token count. Green → yellow → red |
| Hourly limit | `H:78% 1h34m` | Remaining 5-hour usage quota + time until reset |
| Weekly limit | `W:87%` | Remaining 7-day usage quota |
| Project | `my-app` | Current directory name |
| Git branch | `git:(main)` | Active branch (hidden outside git repos) |
| MCP servers | `3 MCPs` | Connected MCP server count, read from plugin cache (hidden if 0) |
| Session time | `⏱ 12m` | Session duration, detected from transcript JSONL timestamps (gap >30 min = new session) |

Color coding: 🟢 > 50% — 🟡 20–50% — 🔴 < 20%.

## Installation

### Quick (from GitHub)

```bash
curl -fsSL https://raw.githubusercontent.com/SfilD/claude-statusline/main/install.sh | bash
```

### Manual

```bash
curl -fsSL https://raw.githubusercontent.com/SfilD/claude-statusline/main/statusline.sh -o ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

Restart Claude Code.

## Requirements

| Package | Purpose | macOS | Linux | Windows |
|---------|---------|-------|-------|---------|
| `jq` | JSON parsing | `brew install jq` | `sudo apt install jq` | `winget install jq` |
| `python3` | Time calculations | preinstalled | preinstalled | `winget install python` |
| `curl` | API requests | preinstalled | preinstalled | included in Git Bash |

## How it works

Claude Code runs the script after each assistant message, piping a JSON payload on stdin (model, context, paths, MCP servers). The script parses the JSON, fetches usage limits from the API, and outputs a formatted string with ANSI colors.

---

## Usage limits — `H:` and `W:`

The `H:78% 1h34m` and `W:87%` segments show remaining Claude Code rate limit quota (Pro/Max subscriptions).

| Limit | Meaning |
|-------|---------|
| **H** (hourly) | Rolling 5-hour window quota |
| **W** (weekly) | Rolling 7-day window quota |

Percentage shows **remaining** capacity (100% = full, 0% = limit reached). Time after `H:` shows when the 5-hour window fully resets.

### How it works under the hood

1. **Read OAuth token** from OS credential storage (Keychain / credentials file / Credential Manager)
2. **Call** `GET https://api.anthropic.com/api/oauth/usage` with `Bearer <token>`
3. **Calculate** `remaining = 100 - utilization`, format time until reset
4. **Cache** results for 2 minutes at `~/.claude/.usage-cache.json`

### Platform-specific token access

| Platform | Storage | Command |
|----------|---------|---------|
| **macOS** | Keychain Access | `security find-generic-password -s "Claude Code-credentials" -w` |
| **Linux** | `~/.claude/.credentials.json` → libsecret fallback | `cat ~/.claude/.credentials.json` |
| **Windows** (Git Bash) | `~/.claude/.credentials.json` → Credential Manager fallback | `cat ~/.claude/.credentials.json` |
| **WSL** | `~/.claude/.credentials.json` | `cat ~/.claude/.credentials.json` |

> **Linux / Windows / WSL**: the script checks `~/.claude/.credentials.json` first (used by Claude Code in WSL and headless environments). If the file is absent, it falls back to libsecret (`sudo apt install libsecret-tools`) on Linux or Credential Manager (`Install-Module -Name CredentialManager -Force`) on Windows.

Verify your token is accessible:

```bash
# macOS
security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK')"

# Linux / WSL / Windows (Git Bash)
cat ~/.claude/.credentials.json 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK')"

# Linux fallback (libsecret)
secret-tool lookup service "Claude Code-credentials" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK')"
```

If nothing prints, run `claude login` to re-authenticate.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| `H:` and `W:` missing | Token not found — verify with commands above |
| Shows `H:?% W:?%` | API error — token may be expired, run `claude login` |
| Numbers seem stuck | Cache is active (2 min) — wait or `rm ~/.claude/.usage-cache.json` |
| Script won't run | Check `jq`: `echo '{}'\| jq .` — install if missing |

---

## Customization

Edit `~/.claude/statusline.sh` directly, or use inside Claude Code:

```
/statusline add cost tracking
/statusline remove git branch
/statusline show only model and context
```

### Progress bar style

```bash
# Lines (default)
bar+="━"

# Blocks
bar+="█" / bar+="░"

# Dots
bar+="●" / bar+="○"
```

### Bar width

```bash
bar_len=10  # default: 6
```

### Remove a segment

Comment out the corresponding `parts+=()` line at the end of the script.

### Disable usage limits

If you use an API key without OAuth:

```bash
# Comment out line ~120:
# usage_data=$(get_usage)
```

## Uninstall

```bash
rm ~/.claude/statusline.sh ~/.claude/.usage-cache.json
# Remove the "statusLine" key from ~/.claude/settings.json
```

Or inside Claude Code: `/statusline remove it`

## License

[MIT](LICENSE) — based on [AndyShaman/claude-statusline](https://github.com/AndyShaman/claude-statusline)
