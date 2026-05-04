# Java Concurrency & Architecture — Detailed Reference

Load this file when designing services, working with ExecutorService,
CompletableFuture, virtual threads, or reviewing system architecture,
dependency injection, and testing patterns.

---

## Thread Pools & Executors

### Choosing the Right Executor

| Use Case | Executor | Notes |
|----------|----------|-------|
| CPU-bound tasks | `Executors.newFixedThreadPool(N)` | N = number of CPU cores |
| I/O-bound tasks (pre-Java 21) | `Executors.newCachedThreadPool()` or custom pool | Unbounded but recycles idle threads |
| I/O-bound tasks (Java 21+) | `Executors.newVirtualThreadPerTaskExecutor()` | Lightweight; scales to millions of tasks |
| Scheduled tasks | `Executors.newScheduledThreadPool(N)` | For periodic/delayed execution |
| Single background thread | `Executors.newSingleThreadExecutor()` | Sequential task execution |

### Rules

- **MUST** always shut down executors — use try-with-resources (Java 19+) or `finally` block
- **MUST NOT** use `Executors.newFixedThreadPool()` with unbounded queues for untrusted input — can cause OOM
- **SHOULD** name threads for debugging — use a custom `ThreadFactory`

```java
// Good: named thread factory
ThreadFactory factory = Thread.ofPlatform()
    .name("worker-", 0)
    .factory();
ExecutorService executor = Executors.newFixedThreadPool(4, factory);

// Good: try-with-resources shutdown (Java 19+)
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    var future1 = executor.submit(() -> fetchUser(id));
    var future2 = executor.submit(() -> fetchOrders(id));
    // ...
}

// Good: manual shutdown (pre-Java 19)
ExecutorService executor = Executors.newFixedThreadPool(4);
try {
    // submit tasks
} finally {
    executor.shutdown();
    if (!executor.awaitTermination(30, TimeUnit.SECONDS)) {
        executor.shutdownNow();
    }
}
```

---

## CompletableFuture (Java 8+)

### Basic Patterns

```java
// Async execution
CompletableFuture<User> userFuture = CompletableFuture.supplyAsync(
    () -> userService.findById(id),
    executor // always pass explicit executor
);

// Chaining transformations
CompletableFuture<String> emailFuture = userFuture
    .thenApply(User::getEmail)
    .exceptionally(ex -> {
        log.error("Failed to fetch user", ex);
        return "fallback@example.com";
    });

// Combining two futures
CompletableFuture<OrderSummary> summary = userFuture
    .thenCombine(ordersFuture, (user, orders) -> new OrderSummary(user, orders));

// Waiting for all futures
CompletableFuture<Void> all = CompletableFuture.allOf(f1, f2, f3);
all.thenRun(() -> log.info("All tasks completed"));

// First to complete
CompletableFuture<String> fastest = CompletableFuture.anyOf(primary, fallback)
    .thenApply(result -> (String) result);
```

### Rules

- **MUST** always provide an explicit `Executor` to `supplyAsync()` / `runAsync()` — the default common `ForkJoinPool` is shared across the JVM
- **MUST** handle exceptions with `exceptionally()`, `handle()`, or `whenComplete()` — unhandled exceptions are silently swallowed
- **SHOULD** use `thenCompose()` for flat-mapping (chaining dependent async operations), not `thenApply()` which would produce `CompletableFuture<CompletableFuture<T>>`
- **MUST NOT** call `.get()` or `.join()` on the main thread in a web server — it blocks the request thread

```java
// Bad: nested futures
CompletableFuture<CompletableFuture<Order>> nested =
    userFuture.thenApply(user -> orderService.fetchOrders(user)); // returns CF<CF<Order>>

// Good: flat-mapped
CompletableFuture<Order> flat =
    userFuture.thenCompose(user -> orderService.fetchOrders(user)); // returns CF<Order>
```

---

## Virtual Threads (Java 21+)

Virtual threads are lightweight threads managed by the JVM. They are ideal for
I/O-bound tasks and allow writing simple blocking code without callback complexity.

### Rules

- **SHOULD** use virtual threads for I/O-bound work (HTTP calls, DB queries, file I/O)
- **MUST NOT** use virtual threads for CPU-bound computation — they share carrier threads and can cause starvation
- **MUST NOT** use `synchronized` for long operations inside virtual threads — it pins the carrier thread; use `ReentrantLock` instead
- **SHOULD** use structured concurrency (Java 21+ preview) for managing related tasks

```java
// Simple virtual thread
Thread.startVirtualThread(() -> {
    var result = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
    process(result);
});

// Virtual thread executor
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    List<Future<String>> futures = urls.stream()
        .map(url -> executor.submit(() -> fetch(url)))
        .toList();

    for (var future : futures) {
        System.out.println(future.get());
    }
}

// Bad: synchronized pins virtual thread to carrier
synchronized (lock) {
    db.query("SELECT ..."); // long blocking call — pins carrier
}

// Good: ReentrantLock with virtual threads
private final ReentrantLock lock = new ReentrantLock();
lock.lock();
try {
    db.query("SELECT ...");
} finally {
    lock.unlock();
}
```

### Structured Concurrency (Java 21+ Preview)

```java
// Structured concurrency — tasks are scoped to the try block
try (var scope = new StructuredTaskScope.ShutdownOnFailure()) {
    Subtask<User> userTask = scope.fork(() -> fetchUser(id));
    Subtask<List<Order>> ordersTask = scope.fork(() -> fetchOrders(id));

    scope.join();           // wait for all tasks
    scope.throwIfFailed();  // propagate exceptions

    return new UserDashboard(userTask.get(), ordersTask.get());
}
```

---

## Synchronization Patterns

### Immutable Objects (Preferred)

The safest concurrency strategy: share only immutable objects. No synchronization needed.

```java
// Thread-safe by design — all fields final, no setters
public record Config(String host, int port, Duration timeout) {}
```

### Atomic Variables

For simple shared counters and references:

```java
private final AtomicInteger requestCount = new AtomicInteger(0);
private final AtomicReference<Config> currentConfig = new AtomicReference<>(defaultConfig);

// Atomic increment
requestCount.incrementAndGet();

// Compare-and-swap
currentConfig.compareAndSet(oldConfig, newConfig);
```

### Thread-Safe Collections

| Collection | Thread-Safe Alternative |
|-----------|------------------------|
| `HashMap` | `ConcurrentHashMap` |
| `ArrayList` | `CopyOnWriteArrayList` (read-heavy) or `Collections.synchronizedList()` |
| `HashSet` | `ConcurrentHashMap.newKeySet()` or `CopyOnWriteArraySet` |
| `TreeMap` | `ConcurrentSkipListMap` |
| `LinkedList` (queue) | `ConcurrentLinkedQueue` or `LinkedBlockingQueue` |

---

## Application Architecture

### Dependency Injection

- **MUST** use constructor injection for required dependencies — fields are `final`, object is valid after construction
- **SHOULD NOT** use field injection (`@Autowired` on fields) — makes testing hard, hides dependencies
- **SHOULD** use interfaces for dependencies when multiple implementations or mocking is needed

```java
// Bad: field injection
@Service
public class UserService {
    @Autowired
    private UserRepository repository; // not final, hidden dependency
}

// Good: constructor injection
@Service
public class UserService {
    private final UserRepository repository;
    private final EmailService emailService;

    // Spring auto-wires single constructor (no @Autowired needed since Spring 4.3)
    public UserService(UserRepository repository, EmailService emailService) {
        this.repository = Objects.requireNonNull(repository);
        this.emailService = Objects.requireNonNull(emailService);
    }
}
```

### Layered Architecture

Standard layers for Java web applications:

| Layer | Responsibility | Naming Convention |
|-------|---------------|-------------------|
| Controller / Resource | HTTP handling, request/response mapping | `UserController`, `OrderResource` |
| Service | Business logic, transaction boundaries | `UserService`, `OrderProcessor` |
| Repository / DAO | Data access, queries | `UserRepository`, `OrderDao` |
| DTO / Request / Response | Data transfer between layers | `UserDto`, `CreateUserRequest` |
| Entity / Model | Domain objects, database mapping | `User`, `Order` |
| Mapper / Converter | Object transformation between layers | `UserMapper`, `OrderConverter` |

### Rules

- **MUST** keep controllers thin — delegate to services
- **MUST NOT** put business logic in controllers or repositories
- **SHOULD** use DTOs for API boundaries — never expose JPA entities directly
- **SHOULD** validate input at the controller layer (Bean Validation `@Valid`)

---

## Testing Patterns

### Unit Testing

- **SHOULD** use JUnit 5 (`org.junit.jupiter`) — JUnit 4 is legacy
- **SHOULD** use Mockito for mocking dependencies
- **SHOULD** follow the Arrange-Act-Assert (AAA) pattern
- **SHOULD** use descriptive test method names: `shouldReturnEmptyWhenUserNotFound`
- **MUST NOT** test implementation details — test behavior

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository repository;

    @InjectMocks
    private UserService service;

    @Test
    void shouldReturnUserWhenFound() {
        // Arrange
        var expected = new User(1L, "Alice", 30);
        when(repository.findById(1L)).thenReturn(Optional.of(expected));

        // Act
        var result = service.findById(1L);

        // Assert
        assertThat(result).isPresent().contains(expected);
        verify(repository).findById(1L);
    }

    @Test
    void shouldReturnEmptyWhenUserNotFound() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        var result = service.findById(99L);

        assertThat(result).isEmpty();
    }
}
```

### Assertions

- **SHOULD** prefer AssertJ (`assertThat`) over JUnit assertions — fluent, more readable
- **SHOULD** assert one concept per test
- **MUST NOT** use `assertTrue(a.equals(b))` — use `assertEquals(a, b)` or `assertThat(a).isEqualTo(b)`

### Integration Testing

- **SHOULD** use `@SpringBootTest` for Spring integration tests
- **SHOULD** use Testcontainers for database/messaging integration tests
- **SHOULD** keep integration tests separate from unit tests (different source set or naming convention)

```java
@SpringBootTest
@Testcontainers
class UserRepositoryIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository repository;

    @Test
    void shouldPersistAndRetrieveUser() {
        var user = new User("Alice", 30);
        repository.save(user);

        var found = repository.findByName("Alice");
        assertThat(found).isPresent();
        assertThat(found.get().getAge()).isEqualTo(30);
    }
}
```

---

## Configuration Management

- **MUST NOT** hardcode configuration values — use external configuration (properties, YAML, env vars)
- **SHOULD** use typed configuration classes instead of raw `@Value` annotations

```java
// Bad: scattered @Value
@Service
public class EmailService {
    @Value("${email.smtp.host}") private String host;
    @Value("${email.smtp.port}") private int port;
    @Value("${email.smtp.timeout}") private Duration timeout;
}

// Good: typed configuration (Spring Boot)
@ConfigurationProperties(prefix = "email.smtp")
public record SmtpConfig(String host, int port, Duration timeout) {}

@Service
public class EmailService {
    private final SmtpConfig config;

    public EmailService(SmtpConfig config) {
        this.config = config;
    }
}
```

---

## Security Essentials

- **MUST NOT** concatenate user input into SQL — use parameterized queries / prepared statements
- **MUST NOT** log sensitive data (passwords, tokens, PII) — mask or omit
- **MUST** validate and sanitize all external input at system boundaries
- **SHOULD** use BCrypt or Argon2 for password hashing — never MD5 or SHA for passwords
- **SHOULD** store secrets in environment variables or a secrets manager — never in source code or config files committed to VCS

```java
// Bad: SQL injection vulnerability
String query = "SELECT * FROM users WHERE name = '" + userInput + "'";

// Good: parameterized query
PreparedStatement stmt = conn.prepareStatement("SELECT * FROM users WHERE name = ?");
stmt.setString(1, userInput);

// Good: Spring Data JPA (parameterized by default)
@Query("SELECT u FROM User u WHERE u.name = :name")
Optional<User> findByName(@Param("name") String name);
```
