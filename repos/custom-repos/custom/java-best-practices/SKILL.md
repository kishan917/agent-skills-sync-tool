---
name: java-best-practices
description: >
  Apply Java coding best practices, idiomatic style, and design patterns when
  writing, reviewing, or refactoring Java code. Use when the user is writing
  Java code, asking for code reviews, dealing with Java idioms (Optional,
  Stream API, records, sealed classes, try-with-resources), debugging
  Java-specific issues, or asking how to structure Java applications. Covers:
  naming conventions, immutability, null safety, error handling, type safety,
  concurrency patterns, collections best practices, modern Java features,
  and application architecture. Triggers even if the user does not explicitly
  say "best practices" or "coding standards."
license: CC BY 4.0
metadata:
  author: custom
  version: "1.0"
  sources: >
    https://dev.java/learn/,
    https://github.com/in28minutes/java-best-practices,
    https://blog.jetbrains.com/idea/2024/02/java-best-practices/,
    Effective Java 3rd Edition (Joshua Bloch)
compatibility: Java 8+, with version-specific features noted inline
---

# Java Best Practices Guide

Apply these rules when writing, reviewing, or refactoring Java code. Rules are
labeled **MUST** (never violate) or **SHOULD** (strong preference, deviate only
with a documented reason).

For deeper detail on a specific topic, load the appropriate reference file (see
the **Reference Files** section at the bottom).

---

## Naming Conventions (MUST)

- Classes, interfaces, enums, records → `UpperCamelCase` (e.g., `UserService`, `OrderStatus`)
- Methods, fields, local variables, parameters → `lowerCamelCase` (e.g., `calculateTotal`, `firstName`)
- Constants (`static final`) → `UPPER_SNAKE_CASE` (e.g., `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT_MS`)
- Packages → all lowercase, reverse domain (e.g., `com.example.users`)
- Type parameters → single uppercase letter (`T`, `E`, `K`, `V`) or descriptive (`<Element>`, `<Key>`)
- Boolean variables/methods → prefix with `is`, `has`, `can`, `should` (e.g., `isValid`, `hasPermission`)
- Avoid abbreviations — `customerEmailAddress` not `cea`; `timeoutInMillis` not `timeout`
- Test classes → suffix with `Test` (e.g., `UserServiceTest`); test methods → descriptive names (e.g., `shouldReturnEmptyWhenUserNotFound`)

---

## Immutability (SHOULD)

- **SHOULD** make fields `final` by default — assign once in constructor
- **SHOULD** make classes `final` unless explicitly designed for extension
- **SHOULD** use unmodifiable collections for return types: `Collections.unmodifiableList()` or `List.of()` (Java 9+), `List.copyOf()` (Java 10+)
- **SHOULD** use records for simple data carriers — they are immutable by design (Java 16+)
- **MUST NOT** expose mutable internal state — return defensive copies of collections and mutable objects

```java
// Bad: mutable data carrier
public class User {
    public String name;
    public int age;
}

// Good: immutable with final fields
public final class User {
    private final String name;
    private final int age;

    public User(String name, int age) {
        this.name = name;
        this.age = age;
    }

    public String getName() { return name; }
    public int getAge() { return age; }
}

// Best: record (Java 16+)
public record User(String name, int age) {}
```

---

## Null Safety (MUST)

- **MUST NOT** return `null` from methods — return `Optional<T>` (Java 8+), an empty collection, or a default value
- **MUST NOT** pass `null` as a method argument unless the API explicitly documents it
- **SHOULD** use `Optional<T>` for method return types that may have no result — never use `Optional` for fields, method parameters, or collection elements
- **MUST NOT** call `Optional.get()` without `isPresent()` check — use `orElse()`, `orElseGet()`, `orElseThrow()`, or `ifPresent()` instead
- **SHOULD** use `@Nullable` / `@NonNull` annotations (JSR-305 or JetBrains annotations) on public API boundaries

```java
// Bad: returning null
public User findUser(long id) {
    User user = db.query(id);
    return user; // may be null — caller will get NPE
}

// Good: Optional return
public Optional<User> findUser(long id) {
    return Optional.ofNullable(db.query(id));
}

// Bad: Optional.get() without check
String name = findUser(id).get().getName(); // throws NoSuchElementException

// Good: safe unwrapping
String name = findUser(id)
    .map(User::getName)
    .orElse("Unknown");
```

---

## Error Handling (MUST)

- **MUST NOT** use empty catch blocks — at minimum log the exception
- **MUST NOT** catch `Throwable` or `Error` — these indicate unrecoverable JVM conditions (`OutOfMemoryError`, `StackOverflowError`)
- **MUST** catch the most specific exception type, not broad `Exception`
- **SHOULD** prefer unchecked exceptions (`RuntimeException` subclasses) for programming errors; use checked exceptions only for recoverable conditions the caller must handle
- **MUST** use try-with-resources (Java 7+) for all `AutoCloseable` resources — never manually close in `finally`
- **MUST NOT** use exceptions for control flow — exceptions are for exceptional conditions, not business logic branching
- **SHOULD** include context in exception messages — what operation failed, what input caused it

```java
// Bad: empty catch block
try {
    readFile(path);
} catch (IOException e) {
    // silently swallowed — impossible to debug
}

// Bad: catching Throwable
try {
    process();
} catch (Throwable t) {
    log.error("Failed", t); // catches OutOfMemoryError!
}

// Good: specific catch with context
try {
    readFile(path);
} catch (FileNotFoundException e) {
    throw new ConfigurationException("Config file not found: " + path, e);
} catch (IOException e) {
    log.error("Failed to read file: {}", path, e);
}

// Good: try-with-resources (Java 7+)
try (var reader = new BufferedReader(new FileReader(path))) {
    return reader.lines().collect(Collectors.joining("\n"));
}
```

---

## Type Safety & Modern Java (SHOULD)

- **SHOULD** use `var` for local variables when the type is obvious from the right-hand side (Java 10+) — do NOT use `var` when the type is ambiguous
- **SHOULD** use switch expressions with arrow syntax and exhaustiveness checking (Java 14+)
- **SHOULD** use sealed classes/interfaces to model restricted type hierarchies (Java 17+)
- **SHOULD** use pattern matching in `instanceof` checks (Java 16+)
- **MUST NOT** use raw types — always parameterize generics (`List<String>` not `List`)
- **MUST NOT** use `java.util.Date` or `java.util.Calendar` — use `java.time` API (Java 8+)

```java
// Bad: raw type
List users = new ArrayList();

// Good: parameterized
List<User> users = new ArrayList<>();

// Good: var with obvious type (Java 10+)
var users = new ArrayList<User>();

// Bad: old instanceof + cast
if (shape instanceof Circle) {
    Circle c = (Circle) shape;
    return c.radius();
}

// Good: pattern matching instanceof (Java 16+)
if (shape instanceof Circle c) {
    return c.radius();
}

// Good: switch expression (Java 14+)
String label = switch (status) {
    case ACTIVE -> "Active";
    case INACTIVE -> "Inactive";
    case PENDING -> "Pending";
};

// Good: sealed hierarchy (Java 17+)
public sealed interface Shape permits Circle, Rectangle, Triangle {}
public record Circle(double radius) implements Shape {}
public record Rectangle(double width, double height) implements Shape {}
public record Triangle(double a, double b, double c) implements Shape {}
```

---

## Collections Best Practices

Choose the right collection for the use case:

| Need | Use |
|------|-----|
| Ordered, indexed access (O(1)) | `ArrayList` |
| Frequent insert/remove at both ends | `ArrayDeque` |
| Sorted elements | `TreeSet` / `TreeMap` |
| Fast key-value lookup | `HashMap` |
| Thread-safe map | `ConcurrentHashMap` |
| Unique elements | `HashSet` |
| FIFO queue | `ArrayDeque` or `LinkedList` |
| Immutable list (Java 9+) | `List.of(...)` |
| Immutable map (Java 9+) | `Map.of(...)` |

- **SHOULD** prefer `List.of()`, `Set.of()`, `Map.of()` factory methods for small immutable collections (Java 9+)
- **MUST NOT** use `Vector` or `Hashtable` — they are legacy synchronized wrappers; use `ArrayList` + `Collections.synchronizedList()` or `ConcurrentHashMap` instead
- **SHOULD** prefer `ArrayDeque` over `Stack` and over `LinkedList` for queue/deque usage
- **SHOULD** use `Stream` API (Java 8+) for declarative collection transformations — but avoid overusing streams for simple loops
- **MUST NOT** modify a collection while iterating — use `Iterator.remove()`, `removeIf()`, or collect into a new collection

```java
// Bad: modifying during iteration
for (String item : items) {
    if (item.isEmpty()) items.remove(item); // ConcurrentModificationException
}

// Good: removeIf (Java 8+)
items.removeIf(String::isEmpty);

// Good: Stream for transformation
List<String> upperNames = users.stream()
    .map(User::getName)
    .map(String::toUpperCase)
    .collect(Collectors.toList());

// Better: toList() (Java 16+)
List<String> upperNames = users.stream()
    .map(User::getName)
    .map(String::toUpperCase)
    .toList();
```

---

## Strings (MUST)

- **MUST NOT** use `+` for string concatenation in loops — use `StringBuilder`
- **SHOULD** use text blocks for multi-line strings (Java 15+)
- **SHOULD** use `String.formatted()` or `String.format()` for parameterized strings — never concatenate user input into SQL/HTML (injection risk)
- **SHOULD** compare strings with `.equals()`, never `==`

```java
// Bad: concatenation in loop
String result = "";
for (String s : items) {
    result += s + ", "; // creates a new String each iteration
}

// Good: StringBuilder
var sb = new StringBuilder();
for (String s : items) {
    sb.append(s).append(", ");
}

// Good: String.join (Java 8+)
String result = String.join(", ", items);

// Good: text block (Java 15+)
String query = """
        SELECT id, name
        FROM users
        WHERE active = true
        ORDER BY name
        """;
```

---

## Concurrency (MUST)

- **MUST NOT** create raw `Thread` instances for application logic — use `ExecutorService` or virtual threads (Java 21+)
- **MUST** use `ConcurrentHashMap` instead of `Collections.synchronizedMap()` for concurrent access
- **MUST NOT** use `synchronized` on non-final fields or on `this` for public classes — use private `final` lock objects
- **SHOULD** prefer `CompletableFuture` (Java 8+) over manual thread coordination
- **SHOULD** use virtual threads for I/O-bound tasks (Java 21+) — they are lightweight and scale better than platform threads
- **MUST** declare shared mutable state as `volatile` or use `AtomicReference` / `AtomicInteger` etc.

```java
// Bad: raw Thread
new Thread(() -> process(data)).start();

// Good: ExecutorService
ExecutorService executor = Executors.newFixedThreadPool(4);
executor.submit(() -> process(data));

// Best: virtual threads (Java 21+)
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    executor.submit(() -> process(data));
}

// Bad: synchronizing on non-final field
private Object lock = new Object(); // reassignable!
synchronized (lock) { ... }

// Good: final lock object
private final Object lock = new Object();
synchronized (lock) { ... }
```

---

## Design Principles

- **SHOULD** favor composition over inheritance — use interfaces and delegation
- **SHOULD** follow SOLID principles, especially Single Responsibility and Dependency Inversion
- **SHOULD** program to interfaces, not implementations (`List<T>` not `ArrayList<T>` in API signatures)
- **SHOULD NOT** define useless interfaces with only one implementation — add abstraction when a second implementation or mock is needed
- **MUST NOT** expose implementation details in public APIs — use access modifiers (`private`, package-private) as defaults, widen only when needed
- **SHOULD** use the Builder pattern for objects with many optional parameters (instead of telescoping constructors)
- **SHOULD** use enums instead of `int`/`String` constants — enums are type-safe and iterable

```java
// Bad: telescoping constructors
public User(String name) { ... }
public User(String name, int age) { ... }
public User(String name, int age, String email) { ... }

// Good: Builder pattern
User user = User.builder()
    .name("Alice")
    .age(30)
    .email("alice@example.com")
    .build();

// Bad: int constants
public static final int STATUS_ACTIVE = 1;
public static final int STATUS_INACTIVE = 2;

// Good: enum
public enum Status { ACTIVE, INACTIVE, PENDING }
```

---

## Performance

- **MUST NOT** optimize prematurely — profile first with JMH, VisualVM, or YourKit; "premature optimization is the root of all evil" (Knuth)
- **SHOULD** set initial capacity on `ArrayList` and `HashMap` when the size is known — avoids repeated resizing
- **SHOULD** avoid creating unnecessary objects in hot loops — reuse `StringBuilder`, use primitives over boxed types
- **SHOULD** use `BigDecimal` for monetary/financial calculations — never `float` or `double`
- **SHOULD** close streams and connections promptly — always with try-with-resources
- **SHOULD** prefer `EnumSet` and `EnumMap` over `HashSet`/`HashMap` when keys are enums — they are faster and use less memory

---

## Gotchas

These are non-obvious traps that agents commonly miss in Java:

- **`equals()` and `hashCode()` contract** — If you override `equals()`, you **MUST** override `hashCode()`. Violating this breaks `HashMap`, `HashSet`, and any hash-based collection. Use `Objects.hash()` or IDE generation.
- **`String` comparison with `==`** — Compares references, not values. Always use `.equals()`. The `==` check may work with string literals due to interning but breaks with `new String()` or runtime-constructed strings.
- **Autoboxing NPE** — Unboxing a `null` `Integer`/`Long`/etc. throws `NullPointerException`. Check for null before unboxing: `if (boxedValue != null) { int v = boxedValue; }`.
- **`ConcurrentModificationException`** — Modifying a collection while iterating with for-each. Use `Iterator.remove()`, `removeIf()`, or iterate over a copy.
- **`SimpleDateFormat` is not thread-safe** — Use `java.time.format.DateTimeFormatter` (immutable, thread-safe) instead (Java 8+).
- **`Optional.get()` without check** — Throws `NoSuchElementException`. Use `orElse()`, `orElseGet()`, or `orElseThrow()`.
- **Resource leaks** — Forgetting to close `InputStream`, `Connection`, `ResultSet`. Always use try-with-resources.
- **Checked exception swallowing** — Empty catch blocks hide errors. At minimum log the exception with stack trace.
- **`finalize()` is deprecated** — Removed in Java 18. Use `Cleaner` (Java 9+) or try-with-resources instead.
- **Double-checked locking without `volatile`** — The classic singleton pattern is broken without `volatile` on the instance field. Prefer enum singletons or `Holder` pattern.
- **`List.of()` / `Map.of()` are unmodifiable** (Java 9+) — Calling `.add()` or `.put()` throws `UnsupportedOperationException`. This is by design but catches newcomers off guard.

---

## Reference Files

Load these files **only when needed** for the specific task:

- **`references/language-rules.md`** — Load when writing or reviewing Java code; contains detailed rules with code examples for generics, lambdas, streams, records, sealed classes, and pattern matching.
- **`references/style-and-formatting.md`** — Load when formatting or structuring code; covers naming conventions in depth, Javadoc conventions, import ordering, code organization.
- **`references/concurrency-and-architecture.md`** — Load when designing services, working with ExecutorService/CompletableFuture/virtual threads, or reviewing system architecture, dependency injection, and testing patterns.
- **`evals/evals.json`** — Test cases for validating this skill's triggering and output quality.
