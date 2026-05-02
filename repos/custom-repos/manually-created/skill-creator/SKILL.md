---
name: skill-creator
description: >
  Create new skills, modify and improve existing skills, and measure skill
  performance. Use when users want to create a skill from scratch, edit or
  optimize an existing skill, break a complex process into modular sub-skills,
  run evals to test a skill, or optimize a skill's description for better
  triggering accuracy. Platform-agnostic — works with any AI coding agent
  (GitHub Copilot, Claude Code, Codex, Cursor, Windsurf, etc.).
---

# Skill Creator

A platform-agnostic skill for creating, testing, and iteratively improving
skills for AI coding agents.

## High-Level Process

1. Understand what the user wants the skill to do
2. Interview for edge cases, inputs/outputs, success criteria
3. Draft the skill (SKILL.md + bundled resources)
4. Create test prompts and run them
5. Evaluate results (qualitative + quantitative)
6. Improve the skill based on feedback
7. Repeat until satisfied
8. Optimize the description for triggering accuracy

Jump in wherever the user is in this process. If they already have a draft,
go straight to eval/iterate. If they say "just vibe with me", skip the formal
eval pipeline.

---

## Communicating with the User

Adapt your language to the user's technical level. Pay attention to context
cues — if someone is clearly an experienced developer, use technical terms
freely. If they seem newer to coding or AI agents, briefly explain terms like
"assertion", "eval", or "frontmatter" when first using them.

Default: assume moderate technical literacy. Terms like "evaluation" and
"benchmark" are fine. For "JSON schema" or "YAML frontmatter", add a brief
gloss if unsure.

---

## Creating a Skill

### Step 1: Capture Intent

Start by understanding what the user wants. The conversation may already
contain a workflow to capture (e.g., "turn this into a skill"). If so, extract
answers from conversation history first — tools used, sequence of steps,
corrections made, input/output formats observed. The user confirms before
proceeding.

Key questions:
1. What should this skill enable the agent to do?
2. When should this skill trigger? (what user phrases/contexts)
3. What's the expected output format?
4. Should we set up test cases? (suggest yes for objectively verifiable
   outputs like file transforms, code generation, data extraction; suggest no
   for subjective outputs like writing style)

### Step 2: Interview and Research

Proactively ask about:
- Edge cases and failure modes
- Input/output formats, example files
- Success criteria (what "done right" looks like)
- Dependencies (tools, APIs, file types)
- Whether this should be one skill or decomposed into sub-skills

For complex processes with conditional logic, map out the decision tree early.
Identify which branches can be separate sub-skills vs. inline conditionals.

**Sub-skill decomposition heuristic:**
- If a branch has >20 lines of unique instructions → candidate for sub-skill
- If a branch is reused across multiple parent skills → definitely a sub-skill
- If a branch requires different tools/dependencies → separate sub-skill
- Otherwise → inline conditional in the parent skill

### Step 3: Write the Skill

Read `references/skill-anatomy.md` for the full anatomy and structure guide.
Read `references/writing-patterns.md` for writing patterns and style.

Key points (details in references):

**Frontmatter** — YAML with `name` and `description`:
- `name`: lowercase, hyphens, verb-led (e.g., `create-connector`, `validate-schema`)
- `description`: Primary triggering mechanism. Include BOTH what the skill does
  AND specific contexts/phrases for when to use it. Be slightly "pushy" — agents
  tend to under-trigger skills. Start with action context, not "Use when..."
  unless your platform requires it.

**Body** — Markdown instructions:
- Use imperative form ("Run the validator", not "You should run the validator")
- Explain the WHY behind instructions — agents are smart, reasoning > rigid rules
- Keep SKILL.md under 500 lines; split into reference files if approaching limit
- Define output formats with explicit templates when consistency matters
- Include 1-2 concrete examples (input → output)

**Bundled resources:**
- `scripts/` — Executable code for deterministic/repetitive tasks
- `references/` — Docs loaded into context as needed (schemas, API docs, domain knowledge)
- `assets/` — Files used in output (templates, icons, fonts)
- `agents/` — Subagent instructions for specialized tasks (grading, comparison)

**Degrees of Freedom** (from OpenAI's model — match specificity to fragility):
- **High freedom** (text instructions): Multiple approaches valid, judgment needed
- **Medium freedom** (pseudocode/parameterized scripts): Preferred pattern exists
- **Low freedom** (specific scripts, exact steps): Fragile ops, consistency critical

### Step 4: Test

Read `references/testing-guide.md` for the complete testing methodology.

Quick summary:
1. Write 2-3 realistic test prompts (what a real user would say)
2. Share with user for confirmation
3. Run test prompts with the skill active
4. Run same prompts WITHOUT the skill (baseline) if subagents available
5. Compare outputs

### Step 5: Evaluate and Improve

After test runs:
1. Review outputs with the user
2. Identify gaps, failures, unexpected behavior
3. Improve the skill based on feedback:
   - **Generalize** — don't overfit to specific test cases
   - **Keep it lean** — remove instructions that aren't pulling their weight
   - **Explain the why** — reasoning > ALWAYS/NEVER rules
   - **Bundle repeated work** — if every test run writes the same helper script,
     bundle it in `scripts/`
4. Rerun tests, repeat until satisfied

### Step 6: Optimize Description (Optional)

After the skill works well, optimize the description for triggering accuracy:
1. Generate 15-20 eval queries (mix of should-trigger and should-not-trigger)
2. Test each query — does the agent pick up the skill when it should?
3. Iterate on the description wording
4. Focus negative tests on near-misses (adjacent domains, ambiguous phrasing)
   not obviously irrelevant queries

---

## Modular Skill Architecture

For complex processes (like connector creation with many conditional paths),
decompose into a skill hierarchy:

```
connector-builder/
├── SKILL.md                    # Orchestrator — routes to sub-skills
├── references/
│   └── connector-types.md      # Decision matrix for connector type selection
└── sub-skills/
    ├── auth-setup/
    │   └── SKILL.md            # OAuth, API key, JWT setup flows
    ├── schema-mapping/
    │   └── SKILL.md            # Field mapping, type conversion
    ├── error-handling/
    │   └── SKILL.md            # Retry logic, error codes, fallbacks
    └── testing/
        └── SKILL.md            # Integration tests, mocking, validation
```

**Orchestrator pattern:** The parent SKILL.md contains:
- Overview of the full process
- Decision flowchart for which sub-skill to invoke
- Cross-cutting concerns (naming conventions, shared config)
- References to sub-skills with clear triggering conditions

**Sub-skill pattern:** Each sub-skill is self-contained:
- Can be used independently or as part of the parent flow
- Has its own frontmatter with specific trigger description
- References shared resources from parent via relative paths

---

## Anti-Rationalization Patterns

When creating skills that enforce process discipline (e.g., "always write tests
first", "never skip validation"), agents will find loopholes under pressure.

Read `references/anti-rationalization.md` for the full guide on:
- Closing loopholes explicitly
- Building rationalization tables from test failures
- Creating red-flag checklists
- Addressing "spirit vs. letter" arguments

Quick version: If the skill contains a rule the agent might want to skip,
explicitly list the rationalizations and counter each one. Don't just state
the rule — forbid specific workarounds.

---

## Platform Adaptation Guide

This skill-creator produces platform-agnostic skills. To deploy, adapt the
output to your platform's conventions:

| Concept | Claude Code | GitHub Copilot | Codex (OpenAI) | Cursor/Windsurf |
|---------|-------------|----------------|----------------|-----------------|
| Skill file | `SKILL.md` in skill dir | `.instructions.md` or `.github/copilot-instructions.md` | `SKILL.md` in skill dir | `.cursorrules` or rules dir |
| Triggering | `description` in frontmatter | `description` + `applyTo` in frontmatter | `description` in frontmatter | File-level or global rules |
| Custom agents | `agents/` subdir | `.agent.md` files | `agents/openai.yaml` | Not supported natively |
| Skill location | `~/.claude/skills/` or project | Project root or `~/.copilot/` | `~/.codex/skills/` or project | Project root |
| Subagents | Native support | Agent invocation via `@agent` | Task spawning | Limited |

**Copilot-specific notes:**
- Use `.instructions.md` with YAML frontmatter (`description`, `applyTo` glob)
- For custom agent modes, use `.agent.md` files
- Skills in `~/.copilot/agents/skills/` are user-global
- Project skills go in `.github/` or project root

**Claude Code-specific notes:**
- Standard `SKILL.md` with `name` + `description` frontmatter
- `~/.claude/skills/` for global, project dir for project-specific
- Full subagent support for parallel test execution

---

## Reference Files

- `references/skill-anatomy.md` — Complete structure guide: frontmatter, body,
  bundled resources, progressive disclosure, directory organization
- `references/writing-patterns.md` — Writing style, examples, output format
  templates, flowchart usage, token efficiency
- `references/testing-guide.md` — Test case design, baseline comparison,
  assertion drafting, grading, iteration loop
- `references/anti-rationalization.md` — Patterns for bulletproofing
  discipline-enforcing skills against agent loopholes

## Scripts

- `scripts/init_skill.sh` — Scaffold a new skill directory with template files
- `scripts/validate_skill.sh` — Validate skill structure, frontmatter, naming

---

## The Core Loop (Don't Forget)

1. Figure out what the skill is about
2. Draft or edit the skill
3. Run agent-with-skill on test prompts
4. Evaluate outputs with the user
5. Improve and repeat
6. Optionally optimize the description for triggering
7. Package and deliver

Take your time with improvements — reason about what the user actually needs,
don't just pattern-match on their words. Write a draft, review it fresh, then
improve. The goal is skills that work a million times across many prompts, not
just for the test cases.
