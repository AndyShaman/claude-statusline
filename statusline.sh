#!/bin/bash
# Claude Code statusline with usage limits
input=$(cat)

# === Extract from JSON ===
current_dir=$(echo "$input" | jq -r '.workspace.current_dir' | sed 's|\\|/|g')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir' | sed 's|\\|/|g')
model_name=$(echo "$input" | jq -r '.model.display_name')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
transcript=$(echo "$input" | jq -r '.transcript_path' | sed 's|\\|/|g')
mcps=$({
    # User-configured MCP servers from settings files
    for f in "$HOME/.claude/settings.json" "$HOME/.claude/settings.local.json" \
             "$project_dir/.claude/settings.json" "$project_dir/.claude/settings.local.json"; do
        [ -f "$f" ] && jq -r '.mcpServers // {} | keys[]' "$f" 2>/dev/null
    done
    # Plugin-provided MCP servers from installed plugin cache
    find "$HOME/.claude/plugins/cache" -name ".mcp.json" -exec jq -r 'keys[]' {} \; 2>/dev/null
} | sort -u | wc -l)
mcps=$((mcps + 0))  # ensure numeric

# === Git branch ===
cd "$current_dir" 2>/dev/null || cd "$project_dir" 2>/dev/null
branch=$(git -c core.useReplaceRefs=false -c gc.auto=0 branch --show-current 2>/dev/null)
project=$(basename "$current_dir")

# === Session time ===
# Claude Code reuses transcript files across sessions.
# Detect current session start by finding the last gap >30 min in timestamps.
session_time="0m"
if [ -f "$transcript" ]; then
    session_time=$(python3 - "$transcript" << 'PYEOF'
import json, sys
from datetime import datetime, timezone, timedelta
try:
    prev_ts = None
    session_start = None
    GAP = timedelta(minutes=30)
    filepath = sys.argv[1]
    size = __import__('os').path.getsize(filepath)
    with open(filepath, encoding='utf-8', errors='replace') as f:
        # For large files, seek to last 500KB (covers even multi-hour sessions)
        if size > 500000:
            f.seek(size - 500000)
            f.readline()  # skip partial line after seek
        for line in f:
            try:
                ts_str = json.loads(line).get("timestamp")
                if not ts_str:
                    continue
                ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                if prev_ts is None or (ts - prev_ts) > GAP:
                    session_start = ts
                prev_ts = ts
            except Exception:
                pass
    if session_start:
        elapsed = int((datetime.now(timezone.utc) - session_start).total_seconds() / 60)
        print(f"{elapsed // 60}h {elapsed % 60}m" if elapsed >= 60 else f"{elapsed}m")
    else:
        print("0m")
except Exception:
    print("0m")
PYEOF
)
fi

# === Context bar ===
used_int=$(printf "%.0f" "$used_pct")
context_tokens=$(echo "$used_pct $context_size" | awk '{printf "%.0f", $1 * $2 / 100}')
if [ "$context_tokens" -ge 1000 ] 2>/dev/null; then
    tokens_display="$((context_tokens / 1000))K"
else
    tokens_display="${context_tokens}"
fi
if [ "$context_size" -ge 1000 ] 2>/dev/null; then
    context_display="$((context_size / 1000))K"
else
    context_display="${context_size}"
fi

bar_len=6
filled=$((used_int * bar_len / 100))
empty=$((bar_len - filled))
if [ "$used_int" -lt 50 ]; then
    ctx_color="\033[32m"
elif [ "$used_int" -lt 80 ]; then
    ctx_color="\033[33m"
else
    ctx_color="\033[31m"
fi
bar="${ctx_color}"
for ((i=0; i<filled; i++)); do bar+="━"; done
for ((i=0; i<empty; i++)); do bar+="━"; done
bar+="\033[0m"

# === Usage limits (cached, refresh every 2 min) ===
CACHE_FILE="$HOME/.claude/.usage-cache.json"
CACHE_TTL=120

fetch_usage() {
    local token cred_json

    # Step 1: Read raw credentials JSON from platform-specific secure storage
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Keychain Access
        cred_json=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* || "$OSTYPE" == "win"* ]]; then
        # Windows (Git Bash / MSYS2 / Cygwin): credentials file or Credential Manager
        if [ -f "$HOME/.claude/.credentials.json" ]; then
            cred_json=$(cat "$HOME/.claude/.credentials.json" 2>/dev/null)
        else
            cred_json=$(powershell.exe -NoProfile -Command \
                '[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((Get-StoredCredential -Target "Claude Code-credentials" -AsCredentialObject).Password))' 2>/dev/null)
        fi
    else
        # Linux: credentials file or GNOME Keyring / KWallet via libsecret
        if [ -f "$HOME/.claude/.credentials.json" ]; then
            cred_json=$(cat "$HOME/.claude/.credentials.json" 2>/dev/null)
        else
            cred_json=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        fi
    fi

    # Step 2: Extract OAuth access token from JSON
    if [ -n "$cred_json" ]; then
        token=$(echo "$cred_json" \
            | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" 2>/dev/null)
    fi

    # Step 3: Call Anthropic usage API
    if [ -n "$token" ]; then
        curl -sf --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "Accept: application/json" 2>/dev/null
    fi
}

get_usage() {
    local now cache_time
    now=$(date +%s)
    cache_time=0

    if [ -f "$CACHE_FILE" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
        else
            cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
        fi
    fi

    if [ $((now - cache_time)) -gt $CACHE_TTL ]; then
        local data
        data=$(fetch_usage)
        if [ -n "$data" ] && echo "$data" | jq -e '.five_hour' >/dev/null 2>&1; then
            umask 077
            echo "$data" > "$CACHE_FILE"
        fi
    fi

    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
    fi
}

usage_color() {
    local val=$1
    if [ "$val" -gt 50 ] 2>/dev/null; then
        echo "\033[32m"
    elif [ "$val" -gt 20 ] 2>/dev/null; then
        echo "\033[33m"
    else
        echo "\033[31m"
    fi
}

usage_data=$(get_usage)
limits_part=""

if [ -n "$usage_data" ]; then
    five_h_used=$(echo "$usage_data" | jq -r '.five_hour.utilization // 0')
    week_used=$(echo "$usage_data" | jq -r '.seven_day.utilization // 0')
    five_h_reset=$(echo "$usage_data" | jq -r '.five_hour.resets_at // ""')

    five_h_left=$(python3 -c "import sys; print(int(100 - float(sys.argv[1])))" "$five_h_used" 2>/dev/null || echo "?")
    week_left=$(python3 -c "import sys; print(int(100 - float(sys.argv[1])))" "$week_used" 2>/dev/null || echo "?")

    time_left=""
    if [ -n "$five_h_reset" ] && [ "$five_h_reset" != "null" ]; then
        time_left=$(python3 -c "
import sys
from datetime import datetime, timezone
try:
    reset = datetime.fromisoformat(sys.argv[1].replace('Z', '+00:00'))
    now = datetime.now(timezone.utc)
    diff = reset - now
    s = int(diff.total_seconds())
    if s < 0:
        print('')
    elif s >= 3600:
        print(f'{s // 3600}h{(s % 3600) // 60}m')
    else:
        print(f'{(s % 3600) // 60}m')
except Exception:
    print('')
" "$five_h_reset" 2>/dev/null)
    fi

    five_color=$(usage_color "$five_h_left")
    week_color=$(usage_color "$week_left")

    if [ -n "$time_left" ]; then
        limits_part="${five_color}H:${five_h_left}% ${time_left}\033[0m ${week_color}W:${week_left}%\033[0m"
    else
        limits_part="${five_color}H:${five_h_left}%\033[0m ${week_color}W:${week_left}%\033[0m"
    fi
fi

# === Build output ===
parts=("[${model_name}]")
parts+=("${bar} ${used_int}% (${tokens_display}/${context_display})")

if [ -n "$limits_part" ]; then
    parts+=("$limits_part")
fi

parts+=("${project}")
[ -n "$branch" ] && parts+=("git:(${branch})")
[ "$mcps" -gt 0 ] 2>/dev/null && parts+=("${mcps} MCPs")
parts+=("⏱ ${session_time}")

result=""
for i in "${!parts[@]}"; do
    if [ "$i" -eq 0 ]; then
        result="${parts[$i]}"
    else
        result="$result | ${parts[$i]}"
    fi
done

printf '%b\n' "$result"
