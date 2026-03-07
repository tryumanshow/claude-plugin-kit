---
name: setup
description: |
  Install the token-gauge plugin: adds model name, context gauge, and session
  elapsed time to the Claude Code status bar.
  Run once after installing the plugin. Re-run after plugin updates.
  Triggers: "setup token-gauge", "install token gauge hook", "enable usage display"
allowed-tools: Bash
---

Install token-gauge so model name, context usage, and session time appear in the
Claude Code status bar automatically — no commands needed.

Run the following and show all output:

```bash
python3 - "${CLAUDE_PLUGIN_ROOT}" << 'PYEOF'
import json, os, sys, shutil, stat

plugin_root   = sys.argv[1]
stable_dir    = os.path.expanduser("~/.claude/hooks/token-gauge")
settings_path = os.path.expanduser("~/.claude/settings.json")

os.makedirs(stable_dir, exist_ok=True)

# ── Copy hook scripts to stable, version-independent location ───────────────
for name in ("show-usage.sh", "token-status.sh", "combined-status.sh"):
    src = f"{plugin_root}/hooks/{name}"
    dst = f"{stable_dir}/{name}"
    shutil.copy2(src, dst)
    os.chmod(dst, os.stat(dst).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

combined_path   = f"{stable_dir}/combined-status.sh"
show_usage_path = f"{stable_dir}/show-usage.sh"

# ── Load or init settings ────────────────────────────────────────────────────
try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# ── If an existing statusLine is present, wrap it ────────────────────────────
existing_sl  = settings.get("statusLine", {})
existing_cmd = existing_sl.get("command", "") if isinstance(existing_sl, dict) else ""

if existing_cmd and "token-gauge" not in existing_cmd:
    wrapper_path = f"{stable_dir}/wrapper-status.sh"
    wrapper = (
        "#!/usr/bin/env bash\n"
        "STDIN_DATA=$(cat)\n"
        f'PREV=$( echo "$STDIN_DATA" | {existing_cmd} 2>/dev/null || true )\n'
        f'GAUGE=$( echo "$STDIN_DATA" | bash {combined_path} 2>/dev/null || true )\n'
        'if [[ -n "$PREV" && -n "$GAUGE" ]]; then\n'
        '    echo "${PREV}  │  ${GAUGE}"\n'
        'elif [[ -n "$GAUGE" ]]; then\n'
        '    echo "${GAUGE}"\n'
        'else\n'
        '    echo "${PREV}"\n'
        'fi\n'
    )
    with open(wrapper_path, "w") as f:
        f.write(wrapper)
    os.chmod(wrapper_path, os.stat(wrapper_path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    entry_path = wrapper_path
else:
    entry_path = combined_path

# ── Update statusLine ────────────────────────────────────────────────────────
settings["statusLine"] = {"type": "command", "command": entry_path}

# ── Clean up any old token-gauge hook entries ────────────────────────────────
hooks = settings.setdefault("hooks", {})
for event in ("Stop", "UserPromptSubmit"):
    hooks[event] = [
        e for e in hooks.get(event, [])
        if not any(
            "show-usage.sh" in h.get("command", "") or
            "token-gauge"   in h.get("command", "")
            for h in e.get("hooks", [])
        )
    ]

# ── Register UserPromptSubmit hook ───────────────────────────────────────────
hooks.setdefault("UserPromptSubmit", []).append({
    "matcher": "",
    "hooks": [{"type": "command", "command": show_usage_path}]
})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"✅ token-gauge v3 installed!")
print(f"   StatusLine : {entry_path}")
if existing_cmd and "token-gauge" not in existing_cmd:
    print(f"   Wrapping   : {existing_cmd}")
print(f"   Hook       : UserPromptSubmit → {show_usage_path}")
print()
print("Status bar will show:")
print("  Current Model: Sonnet  │  Context: 🧠 ██████░░░░ 62%  124k/200k  │  Elapsed: 1h23m")
print()
print("⚡ Restart Claude Code — the token gauge will appear in the status bar.")
PYEOF
```

Tell the user the gauge is now in the **status bar** (bottom of the terminal window) and will update automatically:
- Model name updates when switching between Opus and Sonnet
- Context gauge updates on every status bar poll (~300ms)
- Elapsed time counts from the first message in the current session

They need to restart Claude Code once for the statusLine change to take effect.
