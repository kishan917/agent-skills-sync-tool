# Java Style & Formatting — Detailed Reference

Load this file when formatting or structuring Java code and you need detailed
conventions for naming, Javadoc, imports, code organization, and formatting.

---

## File Structure

A Java source file should be ordered as follows:

1. License/copyright comment (if applicable)
2. `package` statement
3. `import` statements (grouped and ordered)
4. Exactly one top-level class per file

```java
/*
 * Copyright 2024 Example Corp. All rights reserved.
 */
package com.example.users;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.example.common.BaseEntity;
import com.example.users.dto.UserDto;

public class UserService {
    // ...
}
```

---

## Import Ordering

- **MUST NOT** use wildcard imports (`import java.util.*`) — they hide dependencies and cause conflicts
- Group imports in this order (blank line between groups):
  1. `java.*`
  2. `javax.*`
  3. Third-party libraries (e.g., `com.google.*`, `org.apache.*`)
  4. Project-internal imports
- Within each group, sort alphabetically
- **MUST NOT** import unused classes — configure IDE to remove them on save

---

## Class Organization

Order members within a class:

1. Static constants (`static final`)
2. Static fields
3. Instance fields
4. Static initializer blocks (if needed)
5. Constructors
6. Factory methods (`static` creation methods)
7. Public methods
8. Package-private methods
9. Protected methods
10. Private methods
11. Inner classes / enums / interfaces (at bottom)

```java
public class UserService {
    // 1. Static constants
    private static final Logger log = LoggerFactory.getLogger(UserService.class);
    private static final int MAX_RETRIES = 3;

    // 2. Instance fields
    private final UserRepository repository;
    private final EmailService emailService;

    // 3. Constructor
    public UserService(UserRepository repository, EmailService emailService) {
        this.repository = Objects.requireNonNull(repository, "repository must not be null");
        this.emailService = Objects.requireNonNull(emailService, "emailService must not be null");
    }

    // 4. Public methods
    public Optional<User> findById(long id) { ... }
    public User create(CreateUserRequest request) { ... }

    // 5. Private methods
    private void validateRequest(CreateUserRequest request) { ... }
}
```

---

## Naming Conventions (Extended)

### Classes

| Type | Convention | Example |
|------|-----------|---------|
| Regular class | Noun, `UpperCamelCase` | `UserService`, `OrderProcessor` |
| Interface | Adjective or noun | `Runnable`, `Serializable`, `UserRepository` |
| Abstract class | Prefix with `Abstract` or `Base` | `AbstractValidator`, `BaseEntity` |
| Exception | Suffix with `Exception` | `UserNotFoundException`, `InvalidInputException` |
| Enum | Singular noun | `Color`, `Status`, `HttpMethod` |
| Record | Noun phrase | `UserResponse`, `Point`, `DateRange` |
| Test class | Suffix with `Test` | `UserServiceTest` |
| Annotation | Adjective or verb phrase | `@Nullable`, `@Transactional`, `@Validated` |

### Methods

| Type | Convention | Example |
|------|-----------|---------|
| Accessor | `get` + field name | `getName()`, `getAge()` |
| Boolean accessor | `is`/`has`/`can` + condition | `isActive()`, `hasPermission()` |
| Mutator | `set` + field name | `setName(String name)` |
| Conversion | `to` + target type | `toString()`, `toDto()`, `toEntity()` |
| Factory | `of`, `from`, `create`, `valueOf` | `List.of()`, `Instant.from()`, `createUser()` |
| Lifecycle | `init`, `start`, `stop`, `close`, `destroy` | `init()`, `close()` |

### Variables

- Local variables: short but descriptive — `user`, `order`, `retryCount`
- Loop variables: `i`, `j`, `k` only for simple index loops; use meaningful names for enhanced for
- Temporary variables: ok to use short names in small scope — `sb` for `StringBuilder`, `bos` for `ByteArrayOutputStream`
- **MUST NOT** use Hungarian notation (`strName`, `iCount`) — the type system handles this
- **SHOULD** include units in numeric variable names — `timeoutInMillis`, `maxSizeInBytes`

---

## Formatting Rules

### Indentation

- **MUST** use 4 spaces for indentation — never tabs
- Continuation lines: indent by 8 spaces (or 4 from the opening delimiter)

### Braces

- **MUST** use braces for all control structures, even single-line bodies
- Opening brace on the same line as the statement (K&R / "Egyptian" style)

```java
// Bad: no braces
if (condition)
    doSomething();

// Good: always use braces
if (condition) {
    doSomething();
}

// Good: single-line is acceptable only for guard clauses with immediate return
if (input == null) { return; }
```

### Line Length

- **SHOULD** limit lines to 100–120 characters
- Break long lines at operators, after commas, before `.` in method chains

```java
// Good: break method chain
List<String> names = users.stream()
    .filter(User::isActive)
    .map(User::getName)
    .sorted()
    .toList();

// Good: break long parameter list
public UserResponse createUser(
        String name,
        String email,
        int age,
        Department department) {
    // ...
}
```

### Whitespace

- Space after keywords (`if`, `for`, `while`, `catch`, `switch`)
- Space around binary operators (`=`, `+`, `-`, `==`, `&&`, `||`)
- No space after `(` or before `)`
- No space before `;`
- Blank line between methods
- Blank line between logical sections within a method
- No multiple consecutive blank lines

---

## Javadoc

### When to Write Javadoc

- **MUST** for all public classes, interfaces, enums, and records
- **MUST** for all public and protected methods
- **SHOULD** for package-private methods in API-heavy classes
- **SHOULD NOT** for private methods (use inline comments if needed)
- **SHOULD NOT** for trivial getters/setters — Javadoc adds noise without value

### Format

```java
/**
 * Finds a user by their unique identifier.
 *
 * <p>Returns an empty Optional if no user exists with the given ID.
 * The lookup is case-insensitive for string-based identifiers.
 *
 * @param id the unique identifier of the user; must be positive
 * @return an Optional containing the user if found, empty otherwise
 * @throws IllegalArgumentException if id is not positive
 * @since 2.0
 * @see UserRepository#findById(long)
 */
public Optional<User> findById(long id) { ... }
```

### Rules

- First sentence is a summary — ends with a period and appears in IDE tooltips
- Use `<p>` for paragraph breaks in description
- **MUST** document all parameters with `@param`
- **MUST** document return value with `@return` (unless void)
- **MUST** document all checked exceptions with `@throws`
- **SHOULD** use `{@code ...}` for inline code references
- **SHOULD** use `{@link ClassName#method}` for cross-references
- **MUST NOT** use `@author` tags — version control tracks authorship

---

## Comments

### Inline Comments

- **SHOULD** explain **why**, not **what** — code itself shows what; comments explain intent
- Place on a separate line above the code, not at end of line (except for very short clarifications)
- **MUST NOT** leave commented-out code in production — use version control

```java
// Bad: explains what (obvious from code)
i++; // increment i

// Good: explains why
// Skip the first element — it's the header row
for (int i = 1; i < rows.size(); i++) { ... }

// Bad: commented-out code
// String oldQuery = "SELECT * FROM users WHERE active = 1";
String query = "SELECT * FROM users WHERE status = 'ACTIVE'";
```

### TODO Comments

- Format: `// TODO(author): description` or `// TODO: description`
- **SHOULD** include a ticket/issue reference when available: `// TODO(PROJ-123): migrate to new API`
- **MUST NOT** leave TODOs indefinitely — they should be tracked in an issue tracker

---

## Constants and Magic Numbers

- **MUST NOT** use magic numbers or strings — extract to named constants
- Group related constants in a class or enum
- **SHOULD** use enums over constant classes when the values represent a fixed set

```java
// Bad: magic numbers
if (response.getStatusCode() == 200) { ... }
if (retryCount > 3) { ... }

// Good: named constants
private static final int HTTP_OK = 200;
private static final int MAX_RETRIES = 3;

if (response.getStatusCode() == HTTP_OK) { ... }
if (retryCount > MAX_RETRIES) { ... }

// Even better: use existing constants/enums
if (response.getStatusCode() == HttpStatus.OK.value()) { ... }
```

---

## Logging

- **SHOULD** use SLF4J as the logging facade — not `System.out.println()` or `java.util.logging`
- **MUST** use parameterized logging — never string concatenation

```java
// Bad: string concatenation (evaluated even if level disabled)
log.debug("Processing user: " + user.getName() + " with id: " + user.getId());

// Good: parameterized
log.debug("Processing user: {} with id: {}", user.getName(), user.getId());

// Good: guard expensive operations
if (log.isTraceEnabled()) {
    log.trace("Full user details: {}", user.toDetailedString());
}
```

### Log Levels

| Level | Use For |
|-------|---------|
| `ERROR` | Failures requiring immediate attention; service degradation |
| `WARN` | Unexpected conditions that are handled but worth investigating |
| `INFO` | Significant business events (user created, order processed) |
| `DEBUG` | Detailed technical information for debugging |
| `TRACE` | Very detailed information; typically only in development |
