#!/usr/bin/env bash
# fork-session.sh - Fork a Claude Code session at a specific conversation turn
# Usage: fork-session.sh <session-id> [line-number]

set -euo pipefail

SESSION_ID="${1:-}"
CUTOFF_ARG="${2:-}"

if [[ -z "$SESSION_ID" ]]; then
    echo "Usage: fork-session.sh <session-id> [line-number]" >&2
    exit 1
fi

# ── Locate session file ───────────────────────────────────────────────────────
SESSION_FILE=$(find ~/.claude/projects -name "${SESSION_ID}.jsonl" 2>/dev/null | head -1)
if [[ -z "$SESSION_FILE" ]] || [[ ! -f "$SESSION_FILE" ]]; then
    echo "❌ Session file not found: $SESSION_ID" >&2
    exit 1
fi

SESSION_DIR=$(dirname "$SESSION_FILE")
TOTAL_LINES=$(wc -l < "$SESSION_FILE" | tr -d ' ')

# ── Working directory from session ───────────────────────────────────────────
SESSION_CWD=$(python3 -c "
import json, sys
with open('$SESSION_FILE') as f:
    for line in f:
        try:
            obj = json.loads(line)
            if 'cwd' in obj:
                print(obj['cwd'])
                sys.exit(0)
        except:
            pass
import os; print(os.environ.get('HOME', '~'))
" 2>/dev/null)

echo ""
echo "📜 Session : $SESSION_ID"
echo "   Directory: $SESSION_CWD"
echo "   Turns    : $TOTAL_LINES lines"
echo ""

# ── Resolve cutoff line ───────────────────────────────────────────────────────
if [[ -n "$CUTOFF_ARG" ]] && [[ "$CUTOFF_ARG" =~ ^[0-9]+$ ]]; then
    # Direct mode — line number passed as argument
    CUTOFF_LINE="$CUTOFF_ARG"
elif command -v fzf &>/dev/null; then
    # Interactive mode — arrow-key picker via fzf
    ENTRIES=$(python3 - "$SESSION_FILE" <<'PYEOF'
import sys, json

with open(sys.argv[1]) as f:
    for i, line in enumerate(f):
        try:
            obj = json.loads(line.strip())
            t = obj.get('type', '')
            if t not in ('user', 'assistant'):
                continue

            msg = obj.get('message', {})
            content = msg.get('content', '')
            text = ''

            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                for item in content:
                    if not isinstance(item, dict):
                        continue
                    if item.get('type') == 'text':
                        text = item.get('text', '')
                        break
                    elif item.get('type') == 'tool_use':
                        text = f"[tool: {item.get('name', '?')}]"
                        break
                    elif item.get('type') == 'thinking':
                        continue

            text = text.replace('\n', ' ').replace('\r', '').strip()[:80]
            if not text:
                text = '(no text content)'

            indicator = '👤 User  ' if t == 'user' else '🤖 Claude'
            print(f"{i+1}\t{indicator}\t{text}")
        except Exception:
            pass
PYEOF
)

    SELECTED=$(echo "$ENTRIES" | fzf \
        --delimiter=$'\t' \
        --with-nth=2,3 \
        --prompt="  Fork at ▶ " \
        --header=" ↑↓ navigate · Enter select · Esc cancel" \
        --border=rounded \
        --height=50% \
        --reverse \
        --color='header:italic:dim,prompt:blue,pointer:cyan,hl:green' \
        --margin=1,2 \
        2>/dev/tty) || { echo "❌ Cancelled."; exit 1; }

    CUTOFF_LINE=$(echo "$SELECTED" | cut -f1)
else
    # Fallback — plain list + number prompt (fzf not installed)
    python3 - "$SESSION_FILE" <<'PYEOF'
import sys, json

with open(sys.argv[1]) as f:
    for i, line in enumerate(f):
        try:
            obj = json.loads(line.strip())
            t = obj.get('type', '')
            if t not in ('user', 'assistant'):
                continue
            msg = obj.get('message', {})
            content = msg.get('content', '')
            text = ''
            if isinstance(content, str):
                text = content
            elif isinstance(content, list):
                for item in content:
                    if not isinstance(item, dict): continue
                    if item.get('type') == 'text':
                        text = item.get('text', ''); break
                    elif item.get('type') == 'tool_use':
                        text = f"[tool: {item.get('name', '?')}]"; break
            text = text.replace('\n', ' ').strip()[:90] or '(no text)'
            indicator = '👤 User  ' if t == 'user' else '🤖 Claude'
            print(f"  {indicator}  line {i+1:4d}  │  {text}")
        except Exception:
            pass
PYEOF
    echo ""
    echo -n "Enter line number to fork at (Enter = full session, line $TOTAL_LINES): "
    read -r CUTOFF_LINE </dev/tty
    CUTOFF_LINE="${CUTOFF_LINE:-$TOTAL_LINES}"
fi

# ── Validate cutoff ───────────────────────────────────────────────────────────
if ! [[ "$CUTOFF_LINE" =~ ^[0-9]+$ ]] || [[ "$CUTOFF_LINE" -lt 1 ]]; then
    echo "❌ Invalid line number: '$CUTOFF_LINE'" >&2
    exit 1
fi
[[ "$CUTOFF_LINE" -gt "$TOTAL_LINES" ]] && CUTOFF_LINE=$TOTAL_LINES

# ── Write forked session ──────────────────────────────────────────────────────
NEW_UUID=$(python3 -c "import uuid; print(uuid.uuid4())")
NEW_FILE="${SESSION_DIR}/${NEW_UUID}.jsonl"

python3 - "$SESSION_FILE" "$NEW_UUID" "$CUTOFF_LINE" "$NEW_FILE" <<'PYEOF'
import sys, json

src, new_uuid, cutoff, dst = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
written = 0

with open(src) as fin, open(dst, 'w') as fout:
    for i, line in enumerate(fin):
        if i >= cutoff:
            break
        try:
            obj = json.loads(line.strip())
            if 'sessionId' in obj:
                obj['sessionId'] = new_uuid
            fout.write(json.dumps(obj, ensure_ascii=False) + '\n')
        except Exception:
            fout.write(line)
        written += 1

print(f"written:{written}")
PYEOF

echo ""
echo "✅ Forked session created"
echo "   UUID : $NEW_UUID"
echo "   Lines: $CUTOFF_LINE / $TOTAL_LINES"
echo ""
echo "🚀 Opening forked session in new terminal..."

LAUNCH_CMD="cd '${SESSION_CWD}' && claude --resume '${NEW_UUID}'"

if [[ -n "${TMUX:-}" ]]; then
    tmux new-window "$LAUNCH_CMD"
    echo "✅ Opened in new tmux window."
elif [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || pgrep -xq "iTerm2" 2>/dev/null; then
    osascript <<ASEOF
tell application "iTerm2"
    create window with default profile
    tell current session of current window
        write text "${LAUNCH_CMD}"
    end tell
    activate
end tell
ASEOF
    echo "✅ Opened in new iTerm2 window."
else
    osascript <<ASEOF
tell application "Terminal"
    do script "${LAUNCH_CMD}"
    activate
end tell
ASEOF
    echo "✅ Opened in new Terminal window."
fi
