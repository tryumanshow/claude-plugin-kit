#!/usr/bin/env bash
# detect.sh — habit plugin / UserPromptSubmit hook
# Detects semantically similar prompts across sessions;
# when a pattern repeats 3+ times, injects an additionalContext suggestion
# so Claude can propose auto-generating a reusable skill.

PAYLOAD=$(cat 2>/dev/null || true)
SESSION_ID="${CLAUDE_SESSION_ID:-}"

# Write payload to temp file (env-var approach breaks on special chars)
TMPFILE=$(mktemp /tmp/habit-XXXXXXXX.json)
trap "rm -f '$TMPFILE'" EXIT
printf '%s' "$PAYLOAD" > "$TMPFILE"

python3 - "$TMPFILE" "$SESSION_ID" 2>/dev/null <<'PYEOF'
import sys, json, os, re, hashlib
from datetime import datetime
from pathlib import Path

tmpfile    = sys.argv[1] if len(sys.argv) > 1 else ""
session_id = sys.argv[2] if len(sys.argv) > 2 else ""

def bail():
    print(json.dumps({"continue": True}))
    sys.exit(0)

# ── Parse prompt ───────────────────────────────────────────────────────────────
try:
    with open(tmpfile) as f:
        payload = json.load(f)
    prompt = payload.get("prompt", "").strip()
except Exception:
    bail()

if not prompt:
    bail()

# ── Noise filters ──────────────────────────────────────────────────────────────
words = prompt.split()

# Too short to be a reusable pattern
if len(words) < 4:
    bail()

# Context-dependent (references current file/code — not reusable)
CONTEXT_MARKERS = {'this', 'these', '이거', '이것', '지금', '방금', '여기',
                   '그거', '저거', '위에', '아래', '해당', 'above', 'below'}
if any(w.lower() in CONTEXT_MARKERS for w in words[:6]):
    bail()

# Skill-acceptance replies ("ok", "스킬 만들어줘", …)
if len(words) <= 4 and any(k in prompt.lower() for k in
                            ('ok', 'ㅇㅋ', '응', 'yes', '네', '스킬 만들', 'skill')):
    bail()

# ── Storage ────────────────────────────────────────────────────────────────────
STORAGE_DIR   = Path.home() / ".claude" / "hooks" / "habit"
SKILLS_DIR    = STORAGE_DIR / "skills"
PATTERNS_FILE = STORAGE_DIR / "patterns.json"
STORAGE_DIR.mkdir(parents=True, exist_ok=True)
SKILLS_DIR.mkdir(parents=True, exist_ok=True)

try:
    with open(PATTERNS_FILE) as f:
        data = json.load(f)
except Exception:
    data = {"version": 1, "patterns": []}

patterns = data.get("patterns", [])

# ── Jaccard similarity ─────────────────────────────────────────────────────────
STOPWORDS = {'a','an','the','is','it','in','of','to','do','how','can','i',
             '을','를','이','가','은','는','에','의','로','하는','방법','어떻게','알려',
             '줘','줄','있어','있나','있는','뭐야','뭔가','뭔지','어떤','어디'}

# Korean tech terms → canonical English (보정: 파이썬/Python → python)
NORMALIZE_MAP = {
    '파이썬': 'python', '자바스크립트': 'javascript', '타입스크립트': 'typescript',
    '자바': 'java', '깃': 'git', '도커': 'docker', '리눅스': 'linux',
    '맥': 'mac', '윈도우': 'windows', '쿠버네티스': 'kubernetes',
    # Common verb synonyms for "load/parse/read"
    '파싱하는': 'read', '읽는': 'read', '불러오는': 'read', '불러오고': 'read',
    '파싱': 'read', '로드': 'read', '읽기': 'read',
}

def normalize(text):
    text = text.lower()
    text = re.sub(r'[^\w\s가-힣]', ' ', text)
    words = [w for w in text.split() if len(w) > 1 and w not in STOPWORDS]
    return {NORMALIZE_MAP.get(w, w) for w in words}

def jaccard(a, b):
    sa, sb = normalize(a), normalize(b)
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / len(sa | sb)

SIMILARITY_THRESHOLD = 0.25
REPEAT_COUNT         = 3

# ── Find best matching pattern ─────────────────────────────────────────────────
best_match, best_score = None, 0.0
for p in patterns:
    score = jaccard(prompt, p["representative"])
    if score > best_score:
        best_score, best_match = score, p

suggestion = None

if best_score >= SIMILARITY_THRESHOLD and best_match is not None:
    pat = best_match
    already_in_session = session_id and session_id in pat.get("sessions", [])

    if not already_in_session:
        if session_id:
            pat["sessions"].append(session_id)
        pat["prompts"].append(prompt)
        pat["count"] = max(len(pat.get("sessions", [])), len(pat["prompts"]))

        if pat["count"] >= REPEAT_COUNT and not pat.get("suggested"):
            pat["suggested"] = True
            suggestion = pat
else:
    # New pattern — deduplicate by ID
    pid = hashlib.md5(prompt.encode()).hexdigest()[:8]
    patterns.append({
        "id":             pid,
        "representative": prompt,
        "prompts":        [prompt],
        "sessions":       [session_id] if session_id else [],
        "count":          1,
        "suggested":      False,
        "skill_created":  False,
        "created_at":     datetime.now().isoformat(),
    })
    # Cap to 300 patterns to avoid unbounded growth
    if len(patterns) > 300:
        patterns = sorted(patterns, key=lambda p: p.get("count", 0), reverse=True)[:300]

data["patterns"] = patterns
with open(PATTERNS_FILE, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

# ── Output ─────────────────────────────────────────────────────────────────────
if suggestion:
    sample  = "\n".join(f'  • "{p}"' for p in suggestion["prompts"][-3:])
    context = (
        f"[HABIT] 이 주제의 질문이 {suggestion['count']}개의 다른 세션에서 반복됐어요:\n\n"
        f"{sample}\n\n"
        f"이 패턴으로 스킬을 만들면 다음부터 slash command로 바로 쓸 수 있어요.\n"
        f"'스킬 만들어줘' 또는 'ok'라고 하면 지금 바로 생성할게요.\n"
        f"(pattern-id: {suggestion['id']} | "
        f"skills → {str(SKILLS_DIR)})"
    )
    print(json.dumps({"continue": True, "additionalContext": context}, ensure_ascii=False))
else:
    print(json.dumps({"continue": True}))
PYEOF
