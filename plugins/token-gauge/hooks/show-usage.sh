#!/usr/bin/env bash
# show-usage.sh - Token gauge via UserPromptSubmit hook
# Outputs JSON with additionalContext so it appears as a system-reminder
# before each Claude response — no typing required.

PAYLOAD=$(cat 2>/dev/null || true)

# ── Get session ID ────────────────────────────────────────────────────────────
SESSION_ID="${CLAUDE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID=$(echo "$PAYLOAD" | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('session_id',''))
except: print('')
" 2>/dev/null)
fi

if [[ -z "$SESSION_ID" ]]; then
    echo '{"continue": true}'
    exit 0
fi

SESSION_FILE=$(find ~/.claude/projects -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)

if [[ -z "$SESSION_FILE" || ! -f "$SESSION_FILE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# ── Read last assistant token usage from session JSONL ────────────────────────
USED=$(python3 - "$SESSION_FILE" <<'PYEOF' 2>/dev/null
import sys, json
last = 0
with open(sys.argv[1]) as f:
    for line in f:
        try:
            obj = json.loads(line.strip())
            if obj.get('type') == 'assistant':
                u = obj.get('message', {}).get('usage', {})
                # Total context = direct + cache_read + cache_creation
                total = (u.get('input_tokens', 0)
                       + u.get('cache_read_input_tokens', 0)
                       + u.get('cache_creation_input_tokens', 0))
                if total > 0:
                    last = total
        except Exception:
            pass
print(last)
PYEOF
)

if [[ -z "$USED" || "$USED" == "0" ]]; then
    echo '{"continue": true}'
    exit 0
fi

MAX=200000
PCT=$(( USED * 100 / MAX ))

# ── Build bar (Unicode, no ANSI — system-reminder is plain text) ──────────────
BAR_WIDTH=24
FILLED=$(( PCT * BAR_WIDTH / 100 ))
EMPTY=$(( BAR_WIDTH - FILLED ))

BAR=$(python3 -c "print('█'*${FILLED} + '░'*${EMPTY})")

USED_K=$(( USED / 1000 ))
FREE_K=$(( (MAX - USED) / 1000 ))

# Urgency indicator
if   (( PCT >= 95 )); then ICON="🚨"
elif (( PCT >= 85 )); then ICON="⚠️ "
else                       ICON="🧠"
fi

GAUGE="${ICON} Context: ${BAR} ${PCT}% | ${USED_K}k used · ${FREE_K}k left · 200k max"

# ── Output as additionalContext → appears as system-reminder ──────────────────
python3 -c "
import json
print(json.dumps({'continue': True, 'additionalContext': '$GAUGE'}, ensure_ascii=False))
"
