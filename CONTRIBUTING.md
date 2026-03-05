# Contributing

## Adding a new plugin

### 1. Create the directory structure

```bash
mkdir -p plugins/<name>/.claude-plugin
mkdir -p plugins/<name>/skills/<skill-name>
mkdir -p plugins/<name>/hooks          # optional, for Stop/PreToolUse hooks
```

### 2. Write `plugins/<name>/.claude-plugin/plugin.json`

```json
{
  "name": "<name>",
  "version": "1.0.0",
  "description": "What this plugin does",
  "author": { "name": "swryu" },
  "license": "MIT",
  "keywords": ["tag1", "tag2"]
}
```

### 3. Write `plugins/<name>/skills/<skill-name>/SKILL.md`

```yaml
---
name: <skill-name>
description: |
  What the skill does.
  Trigger phrases: "phrase 1", "phrase 2"
allowed-tools: Bash
---

Instructions for Claude...
```

### 4. Register in `marketplace.json`

Add an entry to `.claude-plugin/marketplace.json`:

```json
{
  "name": "<name>",
  "source": "./plugins/<name>",
  "description": "One-line description",
  "version": "1.0.0",
  "category": "productivity",
  "keywords": ["tag1", "tag2"]
}
```

### 5. Update `README.md`

Add a row to the Plugins table and a usage section.

### Checklist

- [ ] `plugin.json` has `name`, `version`, `description`, `author`
- [ ] `SKILL.md` has valid YAML frontmatter (`name`, `description`)
- [ ] Any shell scripts are executable (`chmod +x`)
- [ ] Entry added to `marketplace.json`
- [ ] README updated
