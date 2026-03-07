#!/usr/bin/env bash
# combined-status.sh — token-gauge statusLine display
# Extracts model name from stdin, passes to token-status.sh via env var.

STDIN_DATA=$(cat)

CLAUDE_MODEL=$(echo "$STDIN_DATA" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    name = d.get('model', {}).get('display_name', '')
    name = name.replace('Claude ', '')
    print(name.split()[0] if name else '')
except:
    print('')
" 2>/dev/null)

export CLAUDE_MODEL
bash "$HOME/.claude/hooks/token-gauge/token-status.sh" 2>/dev/null || true
