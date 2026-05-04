# CI/CD Patterns Reference

Load this file when identifying CI/CD pipelines, deployment strategies, and container builds.

## CI Platform Detection

| Marker File | Platform |
|-------------|----------|
| `.github/workflows/*.yml` | GitHub Actions |
| `Jenkinsfile` | Jenkins |
| `.gitlab-ci.yml` | GitLab CI |
| `.drone.yml` | Drone CI |
| `.circleci/config.yml` | CircleCI |
| `azure-pipelines.yml` | Azure DevOps |
| `.teamcity/` | TeamCity |
| `bitbucket-pipelines.yml` | Bitbucket Pipelines |
| `Makefile` (with CI targets) | Make-based (often wraps another CI) |

## Common Pipeline Steps

Document each step the CI performs:

### Build Phase
- Checkout code
- Setup JDK (note version and distribution)
- Cache dependencies (`.ivy2`, `.m2`, `.gradle`)
- Compile main + test sources

### Quality Phase
- Format check (scalafmt, spotless, google-java-format, ktlint)
- Style check (scalastyle, checkstyle, detekt, PMD)
- Lint (SpotBugs, Error Prone, Wartremover)
- Static analysis (SonarQube, Snyk)

### Test Phase
- Unit tests
- Integration tests (may require Docker/testcontainers)
- E2E tests
- Contract tests (Pact, Spring Cloud Contract)
- Coverage report (JaCoCo, scoverage)

### Package Phase
- Fat JAR / assembly
- Docker image build
- Native image (GraalVM)
- Debian/RPM package

### Publish Phase
- Push Docker image to registry (Artifactory, ECR, GCR, DockerHub)
- Publish artifacts (Maven Central, Artifactory, Nexus, GitHub Packages)
- Upload Helm chart

### Deploy Phase
- Kubernetes/Helm deploy
- VM deploy (Ansible, SSH)
- Serverless deploy (AWS Lambda, Cloud Functions)
- ArgoCD sync
- Deployment notification (Slack, Teams)

## Container Build Patterns

### Dockerfile
```dockerfile
# Common JVM patterns:
FROM eclipse-temurin:17-jdk-alpine    # or 8, 11, 21
FROM amazoncorretto:17-alpine
FROM gcr.io/distroless/java17-debian12  # minimal, no shell

COPY target/*.jar app.jar              # Maven/Gradle
COPY target/scala-*/app-assembly.jar . # sbt assembly

ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Note:** Record base image, exposed ports, entrypoint, and JAVA_OPTS pattern.

### Jib (no Dockerfile)
- Maven: `jib-maven-plugin` in `pom.xml`
- Gradle: `com.google.cloud.tools.jib` plugin
- Builds OCI image directly from compiled classes

### Buildpacks
- Spring Boot: `./gradlew bootBuildImage` or `mvn spring-boot:build-image`
- Paketo buildpacks auto-detect JVM version

### Multi-stage
```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS build
RUN mvn package -DskipTests

FROM eclipse-temurin:17-jre-alpine
COPY --from=build target/*.jar app.jar
```

## Deployment Targets

### Kubernetes / Helm
- Look in: `helm/`, `charts/`, `deploy/k8s/`
- Key files: `values.yaml`, `values.{env}.yaml`, `Chart.yaml`, `templates/`
- Record: namespace, replica strategy, resource limits, probes, secrets source

### VM / Systemd
- Look in: `deploy/`, Ansible playbooks, SSH scripts
- Record: target hosts, service file path, user, restart policy

### Serverless
- Look in: `serverless.yml`, `template.yaml` (SAM), `terraform/`
- Record: function name, runtime, memory, timeout, triggers

### Docker Compose (local dev)
- Look in: `docker-compose.yml`, `docker-compose.override.yml`
- Record: services spun up for local development

## Secrets Management

Document where secrets come from:
- GitHub Actions secrets / GitLab CI variables
- Kubernetes Secrets (mounted or env)
- HashiCorp Vault (injected at deploy time)
- AWS Secrets Manager / GCP Secret Manager
- `.env` files (local only, never committed)

Record which env vars are secrets vs plain config.

## Monitoring & Observability

Document endpoints and tools:
- Metrics: Prometheus (`/metrics`, `/actuator/prometheus`), Datadog, New Relic
- Health: `/health`, `/actuator/health`, `/ready`, `/live`
- Tracing: Jaeger, Zipkin, OpenTelemetry
- Logging: structured (JSON), log aggregation (ELK, Splunk, Loki)
- Dashboards: Grafana, Datadog, CloudWatch
