# Java Language Rules — Detailed Reference

Load this file when writing or reviewing Java code and you need detailed rules
with code examples for generics, lambdas, streams, records, sealed classes,
and pattern matching.

---

## Generics

### Bounded Type Parameters

Use bounded type parameters to restrict generic types and enable safe operations:

```java
// Upper bound: T must be Comparable
public <T extends Comparable<T>> T max(T a, T b) {
    return a.compareTo(b) >= 0 ? a : b;
}

// Multiple bounds: T must implement both interfaces
public <T extends Serializable & Comparable<T>> void process(T item) { ... }
```

### Wildcards

- Use `? extends T` (producer) when you only **read** from a collection
- Use `? super T` (consumer) when you only **write** to a collection
- Use `?` (unbounded) when you neither read nor write typed elements
- **PECS principle**: Producer Extends, Consumer Super (Effective Java, Item 31)

```java
// Producer: reading elements — use extends
public double sum(Collection<? extends Number> numbers) {
    return numbers.stream().mapToDouble(Number::doubleValue).sum();
}

// Consumer: writing elements — use super
public void addNumbers(Collection<? super Integer> dest) {
    dest.add(1);
    dest.add(2);
}
```

### Type Erasure Gotchas

- **MUST NOT** use `instanceof` with generic type parameters — `obj instanceof List<String>` does not compile
- **MUST NOT** create generic arrays — `new T[]` is illegal; use `List<T>` or `@SuppressWarnings` with `Array.newInstance()`
- **SHOULD** use `Class<T>` tokens for runtime type information when needed

```java
// Bad: won't compile
if (obj instanceof List<String>) { ... }

// Good: check raw type, then cast
if (obj instanceof List<?> list) {
    // safe — no generic check at runtime
}

// Bad: cannot create generic array
T[] array = new T[10]; // compile error

// Good: use List
List<T> items = new ArrayList<>(10);
```

---

## Lambda Expressions & Method References (Java 8+)

### Prefer Lambdas Over Anonymous Classes

```java
// Bad: verbose anonymous class
Comparator<String> comp = new Comparator<String>() {
    @Override
    public int compare(String a, String b) {
        return a.length() - b.length();
    }
};

// Good: lambda
Comparator<String> comp = (a, b) -> a.length() - b.length();

// Best: method reference where applicable
Comparator<String> comp = Comparator.comparingInt(String::length);
```

### Method Reference Types

| Type | Syntax | Lambda Equivalent |
|------|--------|-------------------|
| Static method | `Math::abs` | `x -> Math.abs(x)` |
| Instance method (bound) | `str::length` | `() -> str.length()` |
| Instance method (unbound) | `String::length` | `s -> s.length()` |
| Constructor | `ArrayList::new` | `() -> new ArrayList<>()` |

### Functional Interface Rules

- **SHOULD** use standard functional interfaces from `java.util.function` (`Predicate`, `Function`, `Consumer`, `Supplier`, `BiFunction`, etc.) before creating custom ones
- **MUST** annotate custom functional interfaces with `@FunctionalInterface` — enables compiler enforcement
- **SHOULD** keep lambdas short (1–3 lines); extract complex logic into named methods

```java
// Bad: custom interface when standard exists
interface StringMapper {
    String apply(String s);
}

// Good: use standard Function
Function<String, String> toUpper = String::toUpperCase;

// Good: custom functional interface with annotation
@FunctionalInterface
interface Validator<T> {
    boolean validate(T item);
}
```

---

## Stream API (Java 8+)

### When to Use Streams vs Loops

**Use streams when:**
- Transforming, filtering, or aggregating collections
- Combining multiple operations declaratively
- Parallelism might be beneficial (large datasets, CPU-bound operations)

**Use loops when:**
- Side effects are the primary purpose (logging, I/O)
- Early termination with complex conditions
- Readability is better with a loop (very simple iterations)

### Stream Best Practices

- **MUST NOT** reuse a stream after a terminal operation — streams are single-use
- **SHOULD NOT** use `parallel()` by default — only for CPU-bound work on large datasets; measure first
- **SHOULD** prefer `toList()` (Java 16+) over `collect(Collectors.toList())` — returns unmodifiable list
- **SHOULD NOT** use `Stream.of()` for large sequences — prefer `IntStream.range()` or collection `.stream()`
- **SHOULD** use `flatMap` to flatten nested collections

```java
// Filtering, mapping, collecting
List<String> activeEmails = users.stream()
    .filter(User::isActive)
    .map(User::getEmail)
    .filter(Objects::nonNull)
    .distinct()
    .sorted()
    .toList(); // Java 16+

// Reducing
int totalAge = users.stream()
    .mapToInt(User::getAge)
    .sum();

// Grouping
Map<Department, List<User>> byDept = users.stream()
    .collect(Collectors.groupingBy(User::getDepartment));

// FlatMap: flatten nested collections
List<Order> allOrders = customers.stream()
    .flatMap(c -> c.getOrders().stream())
    .toList();
```

### Optional with Streams

```java
// Find first matching element
Optional<User> admin = users.stream()
    .filter(u -> u.getRole() == Role.ADMIN)
    .findFirst();

// Chain Optional operations
String adminEmail = users.stream()
    .filter(u -> u.getRole() == Role.ADMIN)
    .findFirst()
    .map(User::getEmail)
    .orElse("no-admin@example.com");
```

---

## Records (Java 16+)

Records are transparent carriers for immutable data. The compiler generates
`equals()`, `hashCode()`, `toString()`, and accessor methods.

### Rules

- **SHOULD** use records for DTOs, value objects, and simple data carriers
- Records are implicitly `final` — cannot be extended
- Record components are implicitly `final` — cannot be reassigned
- **SHOULD** add validation in the compact constructor
- **MUST NOT** use records when you need mutable state or complex inheritance

```java
// Basic record
public record Point(double x, double y) {}

// Record with validation (compact constructor)
public record User(String name, int age) {
    public User {
        if (name == null || name.isBlank()) throw new IllegalArgumentException("Name required");
        if (age < 0) throw new IllegalArgumentException("Age must be non-negative");
    }
}

// Record with custom method
public record Range(int start, int end) {
    public Range {
        if (start > end) throw new IllegalArgumentException("start must be <= end");
    }

    public int length() { return end - start; }
    public boolean contains(int value) { return value >= start && value <= end; }
}

// Records can implement interfaces
public sealed interface Shape permits Circle, Rectangle {}
public record Circle(double radius) implements Shape {}
public record Rectangle(double width, double height) implements Shape {}
```

---

## Sealed Classes & Interfaces (Java 17+)

Sealed types restrict which classes can implement or extend them, enabling
exhaustive pattern matching.

```java
// Sealed interface with permitted implementations
public sealed interface Payment permits CreditCard, BankTransfer, Cash {}

public record CreditCard(String number, String expiry) implements Payment {}
public record BankTransfer(String iban) implements Payment {}
public record Cash(double amount) implements Payment {}

// Exhaustive switch (Java 21+ with pattern matching for switch)
public String describe(Payment payment) {
    return switch (payment) {
        case CreditCard cc -> "Card ending in " + cc.number().substring(cc.number().length() - 4);
        case BankTransfer bt -> "Bank transfer to " + bt.iban();
        case Cash c -> "Cash: $" + c.amount();
    };
}
```

### Rules

- **SHOULD** use sealed types when a fixed set of subtypes is known at compile time
- Permitted subtypes must be in the same package (or module)
- Permitted subtypes must be `final`, `sealed`, or `non-sealed`
- Sealed types enable exhaustive `switch` — compiler warns if a case is missing (Java 21+)

---

## Pattern Matching

### `instanceof` Pattern Matching (Java 16+)

Combines type check and cast into one expression:

```java
// Before Java 16
if (obj instanceof String) {
    String s = (String) obj;
    System.out.println(s.length());
}

// Java 16+
if (obj instanceof String s) {
    System.out.println(s.length());
}

// With negation — the pattern variable is in scope in the else branch
if (!(obj instanceof String s)) {
    return; // s not in scope here
}
// s is in scope here
```

### Switch Pattern Matching (Java 21+)

```java
// Pattern matching with switch
public double area(Shape shape) {
    return switch (shape) {
        case Circle c -> Math.PI * c.radius() * c.radius();
        case Rectangle r -> r.width() * r.height();
        case Triangle t -> {
            double s = (t.a() + t.b() + t.c()) / 2;
            yield Math.sqrt(s * (s - t.a()) * (s - t.b()) * (s - t.c()));
        }
    };
}

// Guarded patterns
public String classify(Object obj) {
    return switch (obj) {
        case Integer i when i > 0 -> "positive integer";
        case Integer i when i < 0 -> "negative integer";
        case Integer i -> "zero";
        case String s when s.isBlank() -> "blank string";
        case String s -> "string: " + s;
        case null -> "null";
        default -> "other: " + obj.getClass().getSimpleName();
    };
}
```

---

## Enums

### Rules

- **SHOULD** use enums for fixed sets of constants — never `int` or `String` constants
- **SHOULD** add fields and behavior to enums when needed
- **MUST NOT** depend on `ordinal()` for business logic — add an explicit field if order matters

```java
// Basic enum
public enum Status { ACTIVE, INACTIVE, PENDING }

// Enum with fields and behavior
public enum HttpStatus {
    OK(200, "OK"),
    NOT_FOUND(404, "Not Found"),
    INTERNAL_SERVER_ERROR(500, "Internal Server Error");

    private final int code;
    private final String message;

    HttpStatus(int code, String message) {
        this.code = code;
        this.message = message;
    }

    public int getCode() { return code; }
    public String getMessage() { return message; }

    public boolean isSuccess() { return code >= 200 && code < 300; }
}

// Enum implementing interface (strategy pattern)
public enum Operation {
    ADD { public double apply(double a, double b) { return a + b; } },
    SUB { public double apply(double a, double b) { return a - b; } },
    MUL { public double apply(double a, double b) { return a * b; } },
    DIV { public double apply(double a, double b) { return a / b; } };

    public abstract double apply(double a, double b);
}
```

---

## Annotations

### Common Annotations to Use

| Annotation | Purpose |
|-----------|---------|
| `@Override` | **MUST** use on every overriding method — catches typos at compile time |
| `@Deprecated(since="X", forRemoval=true)` | Mark obsolete APIs with migration guidance |
| `@FunctionalInterface` | Enforce single abstract method constraint |
| `@SuppressWarnings("unchecked")` | Use sparingly and with a comment explaining why |
| `@SafeVarargs` | On final/static methods with generic varargs |
| `@Serial` (Java 14+) | Mark serialization-related fields/methods |

### Rules

- **MUST** annotate every overriding method with `@Override` — this catches errors when the parent method signature changes
- **SHOULD NOT** suppress warnings without a comment explaining why
- **SHOULD** use `@Deprecated` with `since` and `forRemoval` attributes (Java 9+)

---

## Interfaces

### Default Methods (Java 8+)

- **SHOULD** use default methods to evolve interfaces without breaking implementations
- **MUST NOT** use default methods as a substitute for abstract classes with shared state
- When two interfaces provide conflicting default methods, the implementing class **MUST** override and resolve the conflict

### Static Methods in Interfaces (Java 8+)

```java
public interface Validator<T> {
    boolean isValid(T item);

    // Factory method
    static <T> Validator<T> of(Predicate<T> predicate) {
        return predicate::test;
    }

    // Combinator
    default Validator<T> and(Validator<T> other) {
        return item -> this.isValid(item) && other.isValid(item);
    }
}
```

### Private Methods in Interfaces (Java 9+)

Use private methods to share code between default methods without exposing it:

```java
public interface Logger {
    default void logInfo(String msg) { log("INFO", msg); }
    default void logError(String msg) { log("ERROR", msg); }

    private void log(String level, String msg) {
        System.out.printf("[%s] %s: %s%n", LocalDateTime.now(), level, msg);
    }
}
```
