#!/usr/bin/env bash
# token-status.sh — statusLine output for token-gauge v3

python3 - "${CLAUDE_MODEL:-}" 2>/dev/null <<'PYEOF'
import os, json, glob, sys, datetime, time

model_name = sys.argv[1] if len(sys.argv) > 1 else ""
home = os.path.expanduser("~")
SESS_CACHE = f"{home}/.claude/hooks/token-gauge/session-path.cache"

# ── 1. Find session file (cached 5s to avoid expensive glob every 300ms) ──────
latest = None
try:
    lines = open(SESS_CACHE).read().splitlines()
    if len(lines) >= 2 and time.time() - float(lines[1]) < 5 and os.path.exists(lines[0]):
        latest = lines[0]
except Exception:
    pass

if not latest:
    files = glob.glob(f"{home}/.claude/projects/**/*.jsonl", recursive=True)
    if not files:
        sys.exit(0)
    latest = max(files, key=os.path.getmtime)
    try:
        open(SESS_CACHE, "w").write(f"{latest}\n{time.time()}")
    except Exception:
        pass

# ── 2. Single file read: first 1KB (timestamp) + last 30KB (tokens) ───────────
ctx_tokens = 0
elapsed_str = ""
try:
    with open(latest, "rb") as f:
        head = f.read(1024).decode("utf-8", errors="ignore")
        f.seek(0, 2); size = f.tell()
        f.seek(max(0, size - 30000))
        tail = f.read().decode("utf-8", errors="ignore").splitlines()

    for line in head.splitlines():
        try:
            ts = json.loads(line.strip()).get("timestamp")
            if ts:
                mins = int((datetime.datetime.now(datetime.timezone.utc)
                            - datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
                            ).total_seconds() / 60)
                elapsed_str = f"{mins}m" if mins < 60 else f"{mins//60}h{mins%60:02d}m"
                break
        except Exception:
            pass

    for line in tail:
        try:
            obj = json.loads(line.strip())
            if obj.get("type") == "assistant":
                u = obj.get("message", {}).get("usage", {})
                t = (u.get("input_tokens", 0)
                   + u.get("cache_read_input_tokens", 0)
                   + u.get("cache_creation_input_tokens", 0))
                if t > 0:
                    ctx_tokens = t
        except Exception:
            pass
except Exception:
    pass

# ── 3. Build status bar ───────────────────────────────────────────────────────
parts = []

if model_name:
    parts.append(f"Current Model: {model_name}")

if ctx_tokens:
    MAX  = 200000
    pct  = int(ctx_tokens * 100 / MAX)
    bar  = "█" * int(pct * 10 / 100) + "░" * (10 - int(pct * 10 / 100))
    icon = "🚨" if pct >= 95 else "⚠️" if pct >= 85 else "🧠"
    parts.append(f"Context: {icon} {bar} {pct}%  {ctx_tokens//1000}k/200k")

if elapsed_str:
    parts.append(f"Elapsed: {elapsed_str}")

print("  │  ".join(parts))
PYEOF
