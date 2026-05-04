# AGENTS.md Template

Adapt this template based on the project. Remove sections that don't apply. Final output must be under 80 lines.

---

## Required Sections

### 1. Project Overview

```markdown
## Project Overview
- **Name:** `{project-name}`
- **Language:** {Language} {version}
- **Framework:** {framework, omit if none}
- **Purpose:** {one-line description}
- **Entrypoint:** `{main class}` → {bootstrap summary}
```

### 2. Build Tool

```markdown
## Build Tool
Use **{tool}** ({runtime}):
\`\`\`
{build command}
{package command}
\`\`\`
```

### 3. File-Scoped Commands

```markdown
## File-Scoped Commands
| Task | Command |
|------|---------|
| Compile | `{cmd}` |
| Unit tests | `{cmd}` |
| Integration tests | `{cmd}` |
| Format check | `{cmd}` |
| Style check | `{cmd}` |
| Full CI check | `{cmd}` |
```

Only include rows that apply. Add additional rows if the project has other scopes (e2e, manual, etc.).

### 4. Key Conventions

```markdown
## Key Conventions
- **Formatting:** {tool} — config in `{file}`
- **Style:** {tool} — config in `{file}`. Suppress with {method}
- {Pattern 1 agents must follow}
- {Pattern 2 agents must follow}
- **PR/commit:** {naming convention}
- **Package layout:** `{base}.{sub-packages}`
```

Only include what an agent would get wrong without being told.

### 5. Commit Attribution

```markdown
## Commit Attribution
AI commits MUST include:
\`\`\`
Co-Authored-By: {agent name} <{agent email}>
\`\`\`
```

Use the identity of the agent executing the skill (e.g. `GitHub Copilot <noreply@github.com>`, `Claude <noreply@anthropic.com>`).

### 6. Architecture Quick Reference

```markdown
## Architecture Quick Reference
See `.github/instructions/architecture.instructions.md` for full details.

{3-line ASCII data flow diagram}
```

The ASCII diagram should show the high-level input → processing → output flow in 3 lines max.

### 7. Pointers to Instruction Files

```markdown
## External Dependencies
See `.github/instructions/external-dependencies.instructions.md`

## CI/CD
See `.github/instructions/ci-cd.instructions.md`

## Configuration
See `.github/instructions/configuration.instructions.md`
```

Add additional pointers if you created extra instruction files (api-contracts, testing, database, etc.).

### 8. Graphify (Optional)

```markdown
## Graphify (Optional)
If the `graphify` skill is available, run `/graphify` to regenerate the project knowledge graph after code changes. Output is in `graphify-out/`.
If graphify is not installed, skip — it is not required.
To install: https://github.com/safishamsi/graphify
```

### 9. Keeping Docs in Sync

```markdown
## Keeping Docs in Sync
When making code changes, update:
- `AGENTS.md` — if conventions, architecture, or dependencies change
- `.github/instructions/*.instructions.md` — if affected sections change
- `README.md` — if user-facing docs are impacted
- `graphify-out/` — re-run `/graphify` (only if installed)
```

---

## Adaptation Variants

| Project Type | Adjustments |
|-------------|-------------|
| Spring Boot | Add "Profiles" section with active profiles per env |
| Multi-module (Maven/Gradle/sbt) | Add "Modules" table (module → purpose) |
| Monorepo | Scope to subdirectory or create per-module AGENTS.md |
| Library (not a service) | Replace CI/CD pointer with publish info (coordinates, release process) |
| Serverless | Replace Helm/K8s with function/trigger docs |
| Microservices | Add "Service Dependencies" showing inter-service calls |
| Event-driven | Add "Event Flow" showing publish/subscribe topology |
