# Instruction File Templates

Use these frontmatter patterns when creating `.github/instructions/*.instructions.md` files.

## Frontmatter Structure

```yaml
---
description: "Use when [keyword-rich triggering conditions]"
applyTo: "pattern/**"  # optional — auto-attach when matching files are in context
---
```

- `description` is REQUIRED — keyword-rich, starts with "Use when..."
- `applyTo` is OPTIONAL — use for file-type-specific instructions

## architecture.instructions.md

```yaml
---
description: "Use when working on service architecture, data flow, actors, controllers, services, or understanding how the {project-name} pipeline/request handling works"
applyTo: "src/main/**"
---
```

**Sections to include:**
- System Overview (1-2 sentences)
- Boot Sequence (numbered steps from main → fully running)
- Key Modules / Packages (table: package → purpose)
- Request/Data Flow (how data enters, transforms, exits)
- Key Abstractions (interfaces, base classes, patterns)
- Data Flow Diagram (ASCII art)

**Adapt for:**
- Akka: document actor hierarchy and message flow
- Spring Boot: document auto-configuration, bean lifecycle, request pipeline
- Play: document routes, controllers, action composition
- ZIO/http4s: document effect layers, fiber supervision
- Vert.x: document verticle deployment, event bus

---

## external-dependencies.instructions.md

```yaml
---
description: "Use when working with {list key systems: Kafka, MongoDB, REST APIs, etc.}, external system integration, or connection configuration in {project-name}"
---
```

**Sections to include:**
- One section per external system type (Kafka, DB, API, etc.)
- Entity identifiers in tables
- Per-environment connection details (from Helm values / profiles)
- Protocols and auth mechanisms
- Downstream consumers (who reads our output)

---

## configuration.instructions.md

```yaml
---
description: "Use when working with environment variables, application config, profiles, feature flags, or any runtime configuration in {project-name}"
---
```

**Sections to include:**
- Config file location and format
- Environment variables table (variable, default, description)
- Feature flags
- Scheduled jobs (cron expressions, intervals)
- Config sections (copy key blocks from actual config)

**Adapt for:**
- HOCON (`application.conf`): show substitution patterns `${?ENV_VAR}`
- Spring YAML: show profile activation, property sources
- Gradle properties: show project-level vs system-level

---

## ci-cd.instructions.md

```yaml
---
description: "Use when working on CI/CD pipelines, deployments, Docker builds, Helm charts, release processes, or publishing for {project-name}"
---
```

**Sections to include:**
- CI Pipeline steps (ordered list matching actual workflow)
- Docker build details (base image, ports, entrypoint)
- Deployment process (how to deploy to each environment)
- Helm/K8s specifics (namespace, values per env)
- Secrets required
- Artifact repositories
- Monitoring endpoints

---

## api-contracts.instructions.md (optional)

```yaml
---
description: "Use when working with API endpoints, request/response schemas, HTTP routes, or API versioning in {project-name}"
applyTo: "src/main/**/controller/**"
---
```

**When to create:** Service exposes REST/gRPC/GraphQL APIs.

---

## domain-model.instructions.md (optional)

```yaml
---
description: "Use when working with domain entities, business logic, value objects, aggregates, or domain events in {project-name}"
applyTo: "src/main/**/domain/**"
---
```

**When to create:** Complex domain with DDD patterns, many entity relationships, or non-obvious business rules.

---

## testing.instructions.md (optional)

```yaml
---
description: "Use when writing or modifying tests, test fixtures, mocks, or test configuration in {project-name}"
applyTo: "src/test/**"
---
```

**When to create:** Non-obvious test setup (testcontainers, embedded DBs, custom fixtures, shared test harness).

---

## database.instructions.md (optional)

```yaml
---
description: "Use when working with database schema, migrations, queries, repositories, or data access in {project-name}"
applyTo: ["src/main/**/dao/**", "src/main/**/repository/**", "db/migration/**"]
---
```

**When to create:** Complex schema, multiple databases, migration tooling, or custom query patterns.

---

## security.instructions.md (optional)

```yaml
---
description: "Use when working with authentication, authorization, token handling, secrets, or security configuration in {project-name}"
---
```

**When to create:** Custom auth flows, OAuth/OIDC integration, RBAC patterns, or security-sensitive data handling.
