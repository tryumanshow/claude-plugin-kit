---
name: setup
description: |
  Install the token-gauge plugin: adds a live token gauge + usage stats to the
  Claude Code status bar and injects usage context before each response.
  Run once after installing the plugin. Re-run after plugin updates.
  Triggers: "setup token-gauge", "install token gauge", "enable usage display"
allowed-tools: Bash
---

Install token-gauge so context usage and weekly token stats appear in the Claude Code
status bar automatically — no commands needed.

Run the following and show all output:

```bash
python3 - "${CLAUDE_PLUGIN_ROOT}" << 'PYEOF'
import json, os, sys, shutil, stat, subprocess

plugin_root   = sys.argv[1]
stable_dir    = os.path.expanduser("~/.claude/hooks/token-gauge")
settings_path = os.path.expanduser("~/.claude/settings.json")

os.makedirs(stable_dir, exist_ok=True)

# ── Copy hook scripts to stable, version-independent location ───────────────
scripts = {
    "show-usage.sh":    f"{plugin_root}/hooks/show-usage.sh",
    "token-status.sh":  f"{plugin_root}/hooks/token-status.sh",
    "compute-usage.py": f"{plugin_root}/hooks/compute-usage.py",
}
for dst_name, src in scripts.items():
    dst = f"{stable_dir}/{dst_name}"
    shutil.copy2(src, dst)
    st = os.stat(dst).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH
    os.chmod(dst, st)

token_status_path = f"{stable_dir}/token-status.sh"
show_usage_path   = f"{stable_dir}/show-usage.sh"
compute_path      = f"{stable_dir}/compute-usage.py"
combined_path     = f"{stable_dir}/combined-status.sh"

# ── Load or init settings ────────────────────────────────────────────────────
try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# ── Detect existing statusLine command ──────────────────────────────────────
existing_sl  = settings.get("statusLine", {})
existing_cmd = existing_sl.get("command", "") if isinstance(existing_sl, dict) else ""

# ── Build combined-status.sh ─────────────────────────────────────────────────
if existing_cmd and "token-gauge" not in existing_cmd:
    combined = (
        "#!/usr/bin/env bash\n"
        "# combined-status.sh — existing statusLine + token-gauge\n"
        f'PREV_OUT=$( {existing_cmd} 2>/dev/null || true )\n'
        f'GAUGE=$( {token_status_path} 2>/dev/null || true )\n'
        'if [[ -n "$PREV_OUT" && -n "$GAUGE" ]]; then\n'
        '    echo "${PREV_OUT}  │  ${GAUGE}"\n'
        'elif [[ -n "$GAUGE" ]]; then\n'
        '    echo "${GAUGE}"\n'
        'else\n'
        '    echo "${PREV_OUT}"\n'
        'fi\n'
    )
else:
    combined = (
        "#!/usr/bin/env bash\n"
        f'{token_status_path} 2>/dev/null || true\n'
    )

with open(combined_path, "w") as f:
    f.write(combined)
os.chmod(combined_path, os.stat(combined_path).st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

# ── Update statusLine ────────────────────────────────────────────────────────
settings["statusLine"] = {"type": "command", "command": combined_path}

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

# ── Register UserPromptSubmit hook (injects context for Claude) ──────────────
hooks.setdefault("UserPromptSubmit", []).append({
    "matcher": "",
    "hooks": [{"type": "command", "command": show_usage_path}]
})

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

# ── Kick off initial weekly cache computation in background ──────────────────
try:
    subprocess.Popen(
        ["python3", compute_path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    print("⏳ Computing weekly usage stats in background…")
except Exception as e:
    print(f"⚠️  Could not start background computation: {e}")

print(f"✅ token-gauge v2 installed!")
print(f"   StatusLine : {combined_path}")
if existing_cmd and "token-gauge" not in existing_cmd:
    print(f"   Wrapping   : {existing_cmd}")
print(f"   Hook       : UserPromptSubmit → {show_usage_path}")
print(f"   Compute    : {compute_path} (background, 5-min cache)")
print()
print("Status bar will show:")
print("  🧠 ████████░░  68%  136k/200k  │  📊 3.2M  │  📅 45M · 31M↓")
print()
print("⚡ Restart Claude Code — the token gauge will appear in the status bar.")
PYEOF
```

Tell the user the gauge is now in the **status bar** (bottom of the terminal window) and will update automatically.
- Context gauge updates on every status bar poll
- Session total updates when the session file changes
- Weekly stats refresh every 5 minutes in the background (first run may take 10–30s)

They need to restart Claude Code once for the statusLine change to take effect.
