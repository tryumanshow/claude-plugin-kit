#!/usr/bin/env bash
# show-usage.sh — Token gauge via UserPromptSubmit hook (v3)
# Calls Anthropic usage API directly (safe: runs once per user message).
# Saves result to cache for statusLine to read.

PAYLOAD=$(cat 2>/dev/null || true)

# ── Get session ID ─────────────────────────────────────────────────────────────
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

API_CACHE="$HOME/.claude/hooks/token-gauge/api-cache.json"

python3 - "$SESSION_FILE" "$API_CACHE" <<'PYEOF'
import sys, json, os, time, subprocess, urllib.request, urllib.error

CACHE_TTL_MS = 300_000  # 5 minutes — skip API call if cache is fresh

session_file = sys.argv[1]
api_cache_f  = sys.argv[2]

# ── Context gauge: last input token count (last 30KB, fast) ───────────────────
ctx_tokens = 0
try:
    with open(session_file, "rb") as f:
        f.seek(0, 2); size = f.tell()
        f.seek(max(0, size - 30000))
        for line in f.read().decode("utf-8", errors="ignore").splitlines():
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

# ── Read existing cache (skip API if fresh) ────────────────────────────────────
plan_name       = None
five_h          = None
seven_d         = None
api_unavailable = False

try:
    with open(api_cache_f) as f:
        cached = json.load(f)
    cache_age = time.time() * 1000 - cached.get("timestamp", 0)
    if cache_age < CACHE_TTL_MS:
        d = cached.get("data", {})
        plan_name       = d.get("planName")
        five_h          = d.get("fiveHour")
        seven_d         = d.get("sevenDay")
        api_unavailable = d.get("apiUnavailable", False)
        # Skip API call — use cached data
        cached_ok = True
    else:
        cached_ok = False
except Exception:
    cached_ok = False

if not cached_ok:
    try:
        keychain_raw = subprocess.check_output(
            ["/usr/bin/security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],
            stderr=subprocess.DEVNULL, timeout=3
        ).decode().strip()
        creds        = json.loads(keychain_raw)
        oauth        = creds.get("claudeAiOauth", {})
        access_token = oauth.get("accessToken", "")
        sub_type     = oauth.get("subscriptionType", "")

        plan_map  = {"claude_max_plus": "Max", "claude_pro": "Pro", "claude_team": "Team"}
        plan_name = plan_map.get(sub_type) or (sub_type.replace("_", " ").title() if sub_type else None)

        if access_token and plan_name:
            req = urllib.request.Request(
                "https://api.anthropic.com/api/oauth/usage",
                headers={"Authorization": f"Bearer {access_token}", "User-Agent": "token-gauge/3"}
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                data = json.loads(resp.read())

            def pct(v):
                return int(float(v) * 100) if v is not None else None

            five_h  = pct(data.get("five_hour",  {}).get("utilization"))
            seven_d = pct(data.get("seven_day",  {}).get("utilization"))

    except urllib.error.HTTPError:
        api_unavailable = True
    except Exception:
        api_unavailable = True

# ── Save to cache for statusLine (only when we made a fresh API call) ──────────
if not cached_ok:
    try:
        os.makedirs(os.path.dirname(api_cache_f), exist_ok=True)
        with open(api_cache_f, "w") as f:
            json.dump({
                "data": {
                    "planName":      plan_name,
                    "fiveHour":      five_h,
                    "sevenDay":      seven_d,
                    "apiUnavailable": api_unavailable,
                },
                "timestamp": int(time.time() * 1000)
            }, f)
    except Exception:
        pass

# ── Build gauge string ─────────────────────────────────────────────────────────
MAX    = 200000
pct_c  = int(ctx_tokens * 100 / MAX) if ctx_tokens else 0
bar_w  = 20
bar    = "█" * int(pct_c * bar_w / 100) + "░" * (bar_w - int(pct_c * bar_w / 100))
used_k = ctx_tokens // 1000
free_k = (MAX - ctx_tokens) // 1000
icon   = "🚨" if pct_c >= 95 else "⚠️ " if pct_c >= 85 else "🧠"

lines = [f"{icon} Context: {bar} {pct_c}% | {used_k}k used · {free_k}k left · 200k max"]

if five_h is not None or seven_d is not None or api_unavailable:
    plan_tag = f"[{plan_name}] " if plan_name else ""
    if api_unavailable:
        lines.append(f"📊 {plan_tag}⚠️ rate limited")
    else:
        fh = f"{five_h}%" if five_h is not None else "…"
        sd = f"{seven_d}%" if seven_d is not None else "…"
        lines.append(f"📊 {plan_tag}5-hour: {fh} · 7-day: {sd}")

print(json.dumps({"continue": True, "additionalContext": " | ".join(lines)}, ensure_ascii=False))
PYEOF
