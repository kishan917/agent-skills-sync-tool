# 🤖 AI Agent & Skill Sync Tool

A configuration-driven utility to centralize and manage GitHub Copilot and Claude agents/skills from multiple repositories into a single local registry.

## 🌟 Overview
This tool clones configured external repositories into `repos/external-repos/<org>/<repo>`, supports your own local repositories in `repos/custom-repos`, and selectively "activates" agents/skills by symlinking them into `synced-items/agents` and `synced-items/skills` based on a `config.json`.

- **Global Access**: Use any agent or skill across all your local projects.
- **Selective Sync**: Filter by Repository Name or File Name using **Literals** or **Regex**.
- **Automatic Updates**: When you `git pull` an external repo, your registry updates instantly.
- **Cross-IDE Support**: Works with **VS Code** (global settings) and **IntelliJ** (project symlinks).

---

## 🏗️ Directory Structure
```
.
├── repos/
│   ├── config.json         <-- The Logic Controller + external repo URLs
│   ├── external-repos/
│   │   └── github/
│   │       └── awesome-repo/   <-- Auto-cloned/pulled from external_repos
│   └── custom-repos/
│       └── any-local-repo/ <-- Your local/custom repos (can be nested)
├── synced-items/
│   ├── agents/         <-- SYNC TARGET: Point VS Code/IntelliJ here
│   └── skills/         <-- SYNC TARGET: Point VS Code/IntelliJ here
├── sync-agents-skills.sh          <-- Execution Script
└── README.md           <-- Documentation

```

## ⚙️ Configuration (config.json)

`repos/config.json` is the single control file for everything. It has four top-level keys:

| Key | Purpose |
| :--- | :--- |
| `agaent_config` | Controls which `.agent.md` files are symlinked |
| `skill_config` | Controls which `SKILL.md` folders are symlinked |
| `external_repos` | List of Git URLs to clone/pull into `external-repos/<org>/<repo>` |
| `patch_skill_names` | `true` (default) — rewrites `name:` in each external `SKILL.md` to `<repo>.<skill>` so VS Code Copilot shows the namespaced name. Set to `false` to keep original names. |
| `sync_to_copilot_home` | `true` — also mirrors synced agent/skill symlinks into `~/.copilot/agents` and `~/.copilot/skills` for global Copilot access. `false` (default) — only syncs to `artifacts/synced-items/`. |
| `unwanted-for-now` | Ignored by the script — a parking lot for URLs you don't want active yet |

---

### Rule fields

Each entry in a `whitelist` or `blacklist` array has three fields:

| Field | Description |
| :--- | :--- |
| `type` | `"Literal"` — exact string match. `"Regex"` — full JS-style regex (tested via `jq`'s `test()`). |
| `repo` | The repo identifier to match against. **External repos:** `<org>/<repo>` slug (e.g. `openai/skills`). **Custom repos:** the subfolder name directly inside `repos/custom-repos/` (e.g. `manually-created`). Use `".*"` to match all repos. |
| `agent` / `skill` | The item name to match. For agents this matches both `name` and `name.agent.md`. For skills this matches the folder name. Use `".*"` to match all items. |

---

### apply_order / priority_order

Defines the order rules are evaluated. Both key names work (`apply_order` or `priority_order`).

```
["whitelist", "blacklist"]  →  start false, turn on by whitelist, turn off by blacklist
["blacklist", "whitelist"]  →  start false, turn off by blacklist, turn on by whitelist (whitelist wins)
```

The default when neither key exists is `["whitelist", "blacklist"]`.

---

### Common patterns

**Sync everything from all repos (catch-all)**
```json
{ "type": "Regex", "repo": ".*", "skill": ".*" }
```

**Sync everything from one repo**
```json
{ "type": "Literal", "repo": "JuliusBrussee/caveman", "skill": ".*" }
```
> `".*"` in a `"Literal"` rule is a special wildcard — it matches any value.

**Sync only specific items from a repo**
```json
{ "type": "Literal", "repo": "sickn33/antigravity-awesome-skills", "skill": "agents-md" }
```

**Sync all items matching a naming pattern from a repo**
```json
{ "type": "Regex", "repo": "github/awesome-copilot", "agent": "expert-.*" }
```

**Block specific items while keeping the catch-all**

Put the specific repo in the `blacklist` using a negative lookahead regex:
```json
"blacklist": [
    { "type": "Regex", "repo": "sickn33/antigravity-awesome-skills", "skill": "^(?!agents-md$).+" }
]
```
This blocks everything from that repo *except* `agents-md`. Because `apply_order` is `["whitelist", "blacklist"]`, the catch-all whitelist matches first, then the blacklist removes the unwanted items.

**Block specific items by exact name**
```json
"blacklist": [
    { "type": "Literal", "repo": "openai/skills", "skill": "skill-installer" }
]
```

**Block multiple exact names with one regex**
```json
{ "type": "Regex", "repo": "openai/skills", "skill": "^(openai-docs|skill-creator|skill-installer)$" }
```

**Sync all skills from a custom repo**

Custom repos under `repos/custom-repos/` use the first folder name as the repo identifier. For example, if your skills live in `repos/custom-repos/custom/brainstorming/`, the repo is `custom`:
```json
{ "type": "Regex", "repo": "custom", "skill": ".*" }
```
This whitelists all skills under `repos/custom-repos/custom/`. The synced names will be `custom.brainstorming`, `custom.skill-creator`, etc.

---

### Symlink naming

Synced items are named `<namespace>.<item>` to avoid collisions across repos:

| Source | Synced name |
| :--- | :--- |
| `external-repos/JuliusBrussee/caveman/caveman/` | `caveman.caveman` |
| `custom-repos/manually-created/brainstorming/` | `manually-created.brainstorming` |

The namespace is the **last segment** of the repo path (`basename` of `org/repo` for external, subfolder name for custom).

The delimiter (`.`) is controlled by the `NAME_DELIMITER` variable at the top of `sync-agents-skills.sh`. Change it to any character allowed in skill names (letters, numbers, hyphens, underscores, dots, spaces).

---

### Parking unwanted repos

The `unwanted-for-now` key is ignored by the script. Use it to store URLs you might want later without cluttering `external_repos`:

```json
"unwanted-for-now": [
    "https://github.com/github/awesome-copilot.git",
    "https://github.com/openai/skills.git"
]
```

---

## 🚀 How it Works

1. Clone/Pull: Reads `external_repos` from `repos/config.json` and clones missing repos or pulls existing ones into `repos/external-repos/<org>/<repo>`. On pull conflict, the repo is deleted and re-cloned cleanly.
2. Patch Names: If `patch_skill_names` is `true` (default), rewrites the `name:` field in each external `SKILL.md` to `<repo>.<skill>` — so VS Code Copilot displays the namespaced name instead of the bare skill name.
3. Crawl: Searches both `repos/external-repos/` and `repos/custom-repos/` recursively for `.agent.md` and `SKILL.md`.
2. Crawl: Searches both `repos/external-repos/` and `repos/custom-repos/` recursively for `.agent.md` and `SKILL.md`.
3. Repo Identification: Uses `<org>/<repo>` for external repos and first folder name for custom repos as the "Repo Name" for config matching.
4. Logic Engine (jq): Evaluates items against config.json, supporting Literal (extension-agnostic) and Regex matching.
5. Execution:
   - Link: Creates a symbolic link in the top-level agents/ or skills/ folder.
   - Purge: Deletes links for blacklisted or un-whitelisted items.
   - Garbage Collection: Deletes "broken" links if a source folder is deleted.
6. Copilot Home Sync: If `sync_to_copilot_home` is `true`, mirrors all synced symlinks into `~/.copilot/agents` and `~/.copilot/skills`. Existing symlinks are overwritten; stale ones are removed. Regular files/directories are left untouched.

---

## 🛠️ Usage

### Running the Sync
Requires jq installed (brew install jq on Mac).

# Standard sync
./sync-agents-skills.sh

# Dry run (see changes without applying)
./sync-agents-skills.sh --dry-run

### IDE Integration

#### Visual Studio Code
Add to your User settings.json:
{
    "github.copilot.chat.agentFilesLocations": ["~/path/to/AI/agent-skills-sync-tool/synced-items/agents"],
    "chat.agentSkillsLocations": { "~/path/to/AI/agent-skills-sync-tool/synced-items/skills": true }
}

#### Visual Studio Code (via ~/.copilot)
Set `"sync_to_copilot_home": true` in `config.json`. The script will symlink agents and skills directly into `~/.copilot/agents` and `~/.copilot/skills`, which VS Code Copilot picks up automatically — no manual `settings.json` paths needed.

#### IntelliJ / JetBrains
In your active project root:
mkdir -p .github
ln -s ~/path/to/AI/agent-skills-sync-tool/synced-items/agents .github/agents
ln -s ~/path/to/AI/agent-skills-sync-tool/synced-items/skills .github/skills

