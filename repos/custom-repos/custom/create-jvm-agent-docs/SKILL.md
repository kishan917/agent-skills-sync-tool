---
name: create-jvm-agent-docs
description: >
  Generate AGENTS.md and .github/instructions/ files for JVM repositories
  (Java, Scala, Kotlin, Groovy, Clojure). Use when asked to create agent docs,
  bootstrap AGENTS.md, generate agent instructions, document a repository for
  AI agents, or set up agent-facing documentation. Covers any build tool (sbt,
  Maven, Gradle, Mill, Bazel), any framework (Spring Boot, Akka, Play, Quarkus,
  Micronaut, Vert.x, ZIO, http4s), any CI platform, any deployment target, and
  any external dependency type.
compatibility: Requires file system access and terminal. Works in VS Code, Claude Code, or any compatible agent.
metadata:
  author: k.yadav
  version: "2.0"
---

# Create Agent Documentation for JVM Projects

Generate minimal, high-signal `AGENTS.md` + `.github/instructions/*.instructions.md` by analyzing actual code, configs, and CI pipelines.

## Workflow

```
- [ ] Step 1: Detect project type and structure
- [ ] Step 2: Gather context from code and configs
- [ ] Step 3: Identify external dependencies with entity identifiers
- [ ] Step 4: Write AGENTS.md (< 80 lines)
- [ ] Step 5: Write instruction files in .github/instructions/
- [ ] Step 6: Verify output
```

## Step 1 — Detect Project Type

Identify the build tool, language, and framework by checking for marker files:

| Marker File | Build Tool | Notes |
|-------------|-----------|-------|
| `build.sbt`, `project/` | sbt | Scala projects |
| `pom.xml` | Maven | Check `<modules>` for multi-module |
| `build.gradle`, `build.gradle.kts` | Gradle | Check `settings.gradle` for multi-module |
| `build.sc` | Mill | Scala/Java |
| `BUILD`, `WORKSPACE` | Bazel | Monorepo |
| `project.clj` | Lein | Clojure |

Identify the primary language from source paths and file extensions under `src/`.

Read `references/build-tools.md` for build-tool-specific commands and patterns.

## Step 2 — Gather Context

Read these (adapt paths based on Step 1 findings):

**Always check:**
- Build definition (deps, versions, plugins, modules)
- Main entrypoint class(es)
- Application config (`application.conf`, `application.yml`, `application.properties`, `reference.conf`)
- CI pipeline (`.github/workflows/`, `Jenkinsfile`, `.gitlab-ci.yml`, `.drone.yml`, `Makefile`)
- Container config (`Dockerfile`, `docker-compose.yml`, `Jib` config)
- Deployment manifests (`helm/`, `k8s/`, `deploy/`, `terraform/`, `serverless.yml`)
- Formatter/linter configs (don't duplicate their content — just reference the file)
- `README.md`, `CONTRIBUTING.md`
- Package/module directory structure (`find src/main -type d`)

**If `/graphify` skill is available**, run it to get the project knowledge graph. If not available, skip — it is optional.

## Step 3 — Identify External Dependencies

For every external system, record the **entity identifier** — the specific resource name the code interacts with.

Read `references/external-deps.md` for patterns on finding each dependency type.

| System | Identifier Format | Where to Find |
|--------|------------------|---------------|
| SQL DB | `database.schema.table` | Entity classes, migrations, SQL files, ORM mappings |
| MongoDB | `database.collection` | DAO/repository classes, config |
| Kafka | `topic` + `consumer_group` | Consumer/producer configs, annotations |
| RabbitMQ | `exchange` / `queue` / `routing_key` | Channel declarations, bindings |
| REST API | `METHOD /endpoint` | HTTP client code, OpenAPI specs |
| gRPC | `package.Service/Method` | `.proto` files, stubs |
| Redis | `key_pattern` or `channel` | Cache/session code |
| Elasticsearch | `index_name` | Client config, repository code |
| S3/GCS/Blob | `bucket/prefix` | Storage client config |
| Pub/Sub | `topic` / `subscription` | Publisher/subscriber config |

## Step 4 — Write AGENTS.md

Use the template from `assets/agents-md-template.md`. Key rules:

- **Under 80 lines** — instruction-following degrades past 100
- **Headers + bullets** — no prose paragraphs
- **Commands in code blocks** — file-scoped when possible
- **Reference instruction files** — don't embed details
- **Don't duplicate linter/formatter rules** — reference config files
- **Trust agent capabilities** — omit obvious instructions

Required sections: Project Overview, Build Tool, File-Scoped Commands, Key Conventions, Commit Attribution, Architecture Quick Reference (3-line ASCII), External Dependencies (pointer), CI/CD (pointer), Configuration (pointer), Graphify (optional), Keeping Docs in Sync.

## Step 5 — Write Instruction Files

Create files in `.github/instructions/` with YAML frontmatter. Read `assets/instructions-templates.md` for frontmatter patterns.

**Create these files** (skip any that don't apply to the project):

| File | Content | `applyTo` |
|------|---------|-----------|
| `architecture.instructions.md` | Boot sequence, modules, data flow, key abstractions | `src/main/**` |
| `external-dependencies.instructions.md` | All systems with entity IDs, per-env connection details | (description only) |
| `configuration.instructions.md` | Env vars, config format, feature flags, schedules | (description only) |
| `ci-cd.instructions.md` | Pipeline steps, Docker, deploy process, secrets | (description only) |

Additional instruction files to create when the project warrants:

| File | When to create |
|------|---------------|
| `api-contracts.instructions.md` | REST/gRPC endpoints, request/response schemas |
| `domain-model.instructions.md` | Complex domain with many entities, DDD patterns |
| `testing.instructions.md` | Non-obvious test setup (testcontainers, fixtures, mocks) |
| `database.instructions.md` | Complex schema, migrations, multi-DB setup |
| `security.instructions.md` | Auth/authz patterns, token handling, secrets management |

Read `references/ci-cd-patterns.md` for CI/CD detection guidance.

## Step 6 — Verify

```bash
wc -l AGENTS.md .github/instructions/*.instructions.md
# AGENTS.md: < 80 lines
# Each instruction file: < 250 lines
```

Confirm:
- [ ] No assumptions made — all info sourced from actual files
- [ ] External deps have entity identifiers (not just "uses Kafka")
- [ ] Linter rules not duplicated (only referenced)
- [ ] Graphify section says "optional" and includes install link
- [ ] Docs-sync section present

## Gotchas

- Multi-module projects: document the module structure, not just root build file
- Spring Boot: env vars may come from `@Value`, `@ConfigurationProperties`, or profiles — check all
- Scala: protobuf types are often aliased with `Ddp...` prefix — note such conventions
- Monorepos: may need per-module instruction files or a module map
- Config precedence: HOCON includes, Spring profiles, Gradle build variants — document the layering
- Some projects use Vault/secrets managers — note which vars come from external secret stores vs Helm/env
- Kafka: check both `application.conf` topic names AND `@KafkaListener` annotations
- gRPC: entity IDs come from `.proto` file `service` + `rpc` definitions, not just Java stubs
