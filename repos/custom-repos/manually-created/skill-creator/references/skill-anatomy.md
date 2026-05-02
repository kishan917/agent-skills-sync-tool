# Skill Anatomy Reference

Complete structural guide for skill files.

## Directory Structure

```
skill-name/
├── SKILL.md                  # Main instructions (required)
│   ├── YAML frontmatter      # name + description (required)
│   └── Markdown body          # Instructions (required)
├── scripts/                   # Executable code (optional)
├── references/                # Context-loaded docs (optional)
├── assets/                    # Output resources (optional)
└── agents/                    # Subagent instructions (optional)
```

## SKILL.md Frontmatter

YAML between `---` fences at the top of the file. Only two required fields:

```yaml
---
name: my-skill-name
description: >
  What this skill does and when to use it. This is the primary triggering
  mechanism — the agent reads this to decide whether to load the skill.
---
```

### Name Rules
- Lowercase letters, digits, hyphens only
- Under 64 characters
- Verb-led phrases preferred: `create-connector`, `validate-schema`
- Namespace by tool when helpful: `gh-address-comments`, `jira-sync-status`
- Directory name must match the skill name

### Description Rules
- Primary triggering mechanism — most important field
- Include BOTH what the skill does AND when to use it
- Be specific about triggering contexts (phrases, file types, task types)
- Be slightly "pushy" — agents under-trigger by default
- Do NOT summarize the skill's workflow/process in the description
  (agents may follow the description shortcut instead of reading the full skill)
- Keep under 500 characters if possible (some platforms have limits)

**Why no workflow in description:** Testing shows that when a description
summarizes workflow, agents follow the description instead of reading the full
skill body. A description saying "does X then Y then Z" caused an agent to do
only X, even though the skill body clearly specified X→Y→Z with nuance.

Good descriptions focus on **when to trigger**, not **what happens after**:

```yaml
# BAD: Summarizes workflow — agent may shortcut
description: Creates connectors by first validating schema, then generating
  auth config, then building the adapter layer with retry logic

# GOOD: Triggering conditions only
description: >
  Create and configure data connectors with authentication, schema mapping,
  error handling, and integration testing. Use for any connector, adapter,
  or integration pipeline work involving APIs, databases, or file sources.
```

## SKILL.md Body

Markdown instructions the agent follows when the skill triggers.

### Structure Template

```markdown
# Skill Name

Brief overview — what this skill does, core principle in 1-2 sentences.

## Process / Workflow
Step-by-step instructions. Use numbered lists for sequences,
flowcharts for non-obvious decisions.

## Output Format
Explicit templates when consistency matters.

## Common Mistakes
What goes wrong + fixes.

## References
Pointers to bundled reference files with guidance on when to read each.
```

### Line Budget
- Target: under 500 lines for SKILL.md body
- If approaching 500 lines, split content into reference files
- Reference files have no line limit (scripts execute without loading)
- For reference files >300 lines, include a table of contents

## Bundled Resources

### Scripts (`scripts/`)
Executable code for deterministic, repetitive tasks.

- **When to bundle:** Same code gets rewritten every invocation, or
  deterministic reliability is critical
- **Example:** `scripts/rotate_pdf.py`, `scripts/validate_schema.sh`
- **Benefit:** Token-efficient, deterministic, can execute without loading
  into context
- **Note:** Scripts may still need reading for patching or env adjustments

### References (`references/`)
Documentation loaded into context as needed.

- **When to bundle:** Domain knowledge, schemas, API docs, detailed guides
- **Examples:** `references/schema.md`, `references/api_docs.md`,
  `references/auth-patterns.md`
- **Best practice:** For files >10k words, include grep search patterns in
  SKILL.md so the agent can search rather than read the whole file
- **Avoid duplication:** Info lives in EITHER SKILL.md or references, not both

### Assets (`assets/`)
Files used in the skill's output, not loaded into context.

- **When to bundle:** Templates, images, boilerplate, fonts
- **Examples:** `assets/template.docx`, `assets/logo.png`,
  `assets/frontend-template/`
- **Benefit:** Separates output resources from documentation

### Agents (`agents/`)
Instructions for specialized subagent tasks.

- **When to bundle:** Grading test results, blind comparison, analysis
- **Examples:** `agents/grader.md`, `agents/comparator.md`
- **Note:** Only useful on platforms supporting subagents (Claude Code, etc.)

## What NOT to Include

Do not create extraneous files:
- No README.md (SKILL.md IS the readme)
- No INSTALLATION_GUIDE.md
- No CHANGELOG.md
- No QUICK_REFERENCE.md

The skill contains only what the agent needs to do the job. No auxiliary
context about the creation process, setup procedures, or user-facing docs.

## Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata** (name + description) — Always in context (~100 words)
2. **SKILL.md body** — Loaded when skill triggers (<500 lines ideal)
3. **Bundled resources** — Loaded as needed (unlimited size)

### Disclosure Patterns

**Pattern 1: High-level guide with references**
```markdown
# PDF Processing

## Quick Start
Extract text with pdfplumber: [code example]

## Advanced Features
- Form filling: See references/forms.md
- API reference: See references/api.md
- Examples: See references/examples.md
```

**Pattern 2: Domain-specific organization**
```
cloud-deploy/
├── SKILL.md          # Workflow + provider selection logic
└── references/
    ├── aws.md        # AWS-specific patterns
    ├── gcp.md        # GCP-specific patterns
    └── azure.md      # Azure-specific patterns
```
Agent reads only the relevant reference file.

**Pattern 3: Conditional details**
```markdown
# DOCX Processing

## Creating Documents
Use docx-js for new documents. See references/docx-js.md.

## Editing Documents
For simple edits, modify XML directly.
For tracked changes: See references/redlining.md
For OOXML details: See references/ooxml.md
```

### Guidelines
- Keep references one level deep from SKILL.md (no nested references)
- For reference files >100 lines, include a table of contents at top
- Reference files clearly from SKILL.md with guidance on WHEN to read each

## Degrees of Freedom

Match instruction specificity to the task's fragility:

| Freedom Level | When to Use | Format |
|---------------|-------------|--------|
| **High** | Multiple valid approaches, context-dependent decisions | Text instructions, heuristics |
| **Medium** | Preferred pattern exists, some variation OK | Pseudocode, parameterized scripts |
| **Low** | Fragile operations, consistency critical, exact sequence required | Specific scripts, step-by-step commands |

Think of the agent navigating a path: a narrow bridge over a cliff needs exact
guardrails (low freedom), an open field allows many routes (high freedom).
