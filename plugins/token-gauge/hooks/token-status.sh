#!/usr/bin/env bash
# token-status.sh — statusLine output for token-gauge
# Called by combined-status.sh; outputs a single line to the Claude Code status bar.

python3 - 2>/dev/null <<'PYEOF'
import os, json, glob, sys

home = os.path.expanduser("~")
files = glob.glob(f"{home}/.claude/projects/**/*.jsonl", recursive=True)
if not files:
    sys.exit(0)

# Most recently modified session
latest = max(files, key=os.path.getmtime)

last = 0
try:
    with open(latest, "rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(0, size - 30000))   # read last ~30 KB only (fast)
        data = f.read().decode("utf-8", errors="ignore").splitlines()
    for line in data:
        try:
            obj = json.loads(line.strip())
            if obj.get("type") == "assistant":
                u = obj.get("message", {}).get("usage", {})
                total = (u.get("input_tokens", 0)
                       + u.get("cache_read_input_tokens", 0)
                       + u.get("cache_creation_input_tokens", 0))
                if total > 0:
                    last = total
        except Exception:
            pass
except Exception:
    sys.exit(0)

if not last:
    sys.exit(0)

MAX = 200000
pct = int(last * 100 / MAX)
bar_w = 14
filled = int(pct * bar_w / 100)
bar = "█" * filled + "░" * (bar_w - filled)
used_k = last // 1000
free_k = (MAX - last) // 1000

icon = "🚨" if pct >= 95 else "⚠️" if pct >= 85 else "🧠"
print(f"{icon} {bar} {pct}%  {used_k}k/{MAX//1000}k")
PYEOF
