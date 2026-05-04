# Build Tool Reference

Load this file when you need build-tool-specific commands and project structure patterns.

## sbt (Scala / Java)

**Marker:** `build.sbt`, `project/`

**Structure:**
```
build.sbt                 # Root build definition
project/
  build.properties        # sbt version
  plugins.sbt             # sbt plugins
  Dependencies.scala      # (optional) dependency definitions
  Versions.scala          # (optional) version constants
src/main/scala/           # Main sources
src/test/scala/           # Unit tests
src/it/scala/             # Integration tests (if configured)
```

**Commands:**
| Task | Command |
|------|---------|
| Compile | `sbt compile` |
| Test | `sbt test` |
| Integration test | `sbt it:test` |
| Format | `sbt scalafmtCheck` or `sbt scalafmt` |
| Style | `sbt scalastyle` |
| Package | `sbt assembly` or `sbt package` |
| Run | `sbt run` |
| Clean | `sbt clean` |

**Multi-project:** Look for `lazy val` project definitions or `.aggregate()` calls.

**Formatting:** Check for `.scalafmt.conf` (scalafmt), `scalastyle-config.xml` (scalastyle).

**Key plugins:** `sbt-assembly` (fat jar), `sbt-native-packager` (Docker/deb/rpm), `sbt-scalafmt`, `sbt-protoc` (protobuf).

---

## Maven (Java / Scala / Kotlin)

**Marker:** `pom.xml`

**Structure:**
```
pom.xml                   # Root POM
src/main/java/            # Main sources
src/main/resources/       # Resources (config files)
src/test/java/            # Test sources
modules/                  # (multi-module) submodules
```

**Commands:**
| Task | Command |
|------|---------|
| Compile | `mvn compile` |
| Test | `mvn test` |
| Integration test | `mvn verify` or `mvn failsafe:integration-test` |
| Package | `mvn package` |
| Install | `mvn install` |
| Format | `mvn spotless:check` or `mvn fmt:check` |
| Clean | `mvn clean` |
| Skip tests | `mvn package -DskipTests` |
| Single test | `mvn test -Dtest=ClassName` |

**Multi-module:** Check `<modules>` in root `pom.xml`. Each module has its own `pom.xml`.

**Formatting:** Check for `spotless-maven-plugin`, `maven-checkstyle-plugin`, `google-java-format`.

**Key plugins:** `spring-boot-maven-plugin`, `maven-shade-plugin` (fat jar), `jib-maven-plugin` (Docker), `protobuf-maven-plugin`.

---

## Gradle (Java / Kotlin / Scala)

**Marker:** `build.gradle` or `build.gradle.kts`, `settings.gradle(.kts)`, `gradlew`

**Structure:**
```
build.gradle(.kts)        # Root build script
settings.gradle(.kts)     # Project settings, multi-module includes
gradle/
  wrapper/                # Gradle wrapper
  libs.versions.toml      # (Gradle 7+) version catalog
src/main/java/            # Main sources
src/main/kotlin/          # Kotlin sources
src/test/                 # Tests
```

**Commands:**
| Task | Command |
|------|---------|
| Compile | `./gradlew build` |
| Test | `./gradlew test` |
| Integration test | `./gradlew integrationTest` |
| Format | `./gradlew spotlessCheck` |
| Package | `./gradlew jar` or `./gradlew shadowJar` |
| Run | `./gradlew bootRun` (Spring) or `./gradlew run` |
| Clean | `./gradlew clean` |
| Single test | `./gradlew test --tests "ClassName"` |
| Dependencies | `./gradlew dependencies` |

**Multi-module:** Check `settings.gradle` for `include` statements.

**Formatting:** Check for `spotless`, `ktlint`, `detekt` (Kotlin), `checkstyle`.

**Key plugins:** `shadow` (fat jar), `jib` (Docker), `spring-boot`, `application`, `protobuf`.

---

## Mill (Scala / Java)

**Marker:** `build.sc`

**Commands:**
| Task | Command |
|------|---------|
| Compile | `mill _.compile` |
| Test | `mill _.test` |
| Run | `mill _.run` |
| Assembly | `mill _.assembly` |

---

## Bazel (polyglot)

**Marker:** `WORKSPACE`, `BUILD` files

**Commands:**
| Task | Command |
|------|---------|
| Build | `bazel build //...` |
| Test | `bazel test //...` |
| Run | `bazel run //:target` |
| Query deps | `bazel query "deps(//:target)"` |

---

## Common Patterns Across Tools

### Fat JAR / Uber JAR
- sbt: `sbt-assembly` → `sbt assembly`
- Maven: `maven-shade-plugin` → `mvn package`
- Gradle: `shadow` plugin → `./gradlew shadowJar`

### Docker Build (no Dockerfile)
- sbt: `sbt-native-packager` → `sbt docker:publishLocal`
- Maven/Gradle: `jib` → `mvn jib:dockerBuild` / `./gradlew jibDockerBuild`
- Gradle: `bootBuildImage` (Spring Boot Buildpacks)

### Native Image (GraalVM)
- Maven: `native-maven-plugin` → `mvn -Pnative native:compile`
- Gradle: `org.graalvm.buildtools.native` → `./gradlew nativeCompile`

### Dependency Management
- sbt: `project/Dependencies.scala` or inline in `build.sbt`
- Maven: `<dependencyManagement>` in parent POM, BOM imports
- Gradle: `gradle/libs.versions.toml` (version catalog) or `ext` block
