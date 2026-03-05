---
name: setup
description: |
  Install the habit plugin: registers a UserPromptSubmit hook that tracks
  repeated prompt patterns across sessions and suggests skill generation.
  Run once after installing the plugin.
  Triggers: "setup habit", "install habit", "enable pattern detection"
allowed-tools: Bash
---

Install the habit hook so repeated question patterns are detected automatically
across sessions and Claude can propose generating reusable skills.

Run the following and show all output:

```bash
python3 - "${CLAUDE_PLUGIN_ROOT}" << 'PYEOF'
import json, os, sys, shutil, stat

plugin_root   = sys.argv[1]
stable_dir    = os.path.expanduser("~/.claude/hooks/habit")
skills_dir    = os.path.join(stable_dir, "skills")
settings_path = os.path.expanduser("~/.claude/settings.json")

os.makedirs(stable_dir, exist_ok=True)
os.makedirs(skills_dir, exist_ok=True)

# ── Copy detect.sh to stable, version-independent location ──────────────────
src = f"{plugin_root}/hooks/detect.sh"
dst = f"{stable_dir}/detect.sh"
shutil.copy2(src, dst)
os.chmod(dst, os.stat(dst).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

# ── Load or init settings ────────────────────────────────────────────────────
try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.setdefault("hooks", {})

# ── Remove old habit hook entries ────────────────────────────────────────────
for event in ("Stop", "UserPromptSubmit"):
    hooks[event] = [
        e for e in hooks.get(event, [])
        if not any(
            "detect.sh" in h.get("command", "") or
            "habit"     in h.get("command", "")
            for h in e.get("hooks", [])
        )
    ]

# ── Register under UserPromptSubmit ─────────────────────────────────────────
hooks.setdefault("UserPromptSubmit", []).append({
    "matcher": "",
    "hooks": [{"type": "command", "command": dst}]
})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"✅ habit installed!")
print(f"   Hook   : UserPromptSubmit → {dst}")
print(f"   Skills : {skills_dir}")
print(f"   DB     : {stable_dir}/patterns.json")
print()
print("Now tracking prompt patterns across sessions.")
print("When a topic repeats 3+ times, Claude will suggest creating a skill.")
PYEOF
```

Tell the user:
- The hook is now active and silently tracks patterns in the background
- When a pattern repeats across 3+ different sessions, Claude will say so and offer to create a skill
- Generated skills are saved to `~/.claude/hooks/habit/skills/`
- To view detected patterns so far: `cat ~/.claude/hooks/habit/patterns.json | python3 -m json.tool`
