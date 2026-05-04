# Scala Architecture & Concurrency — Detailed Reference

Load this file when designing services, working with Futures/Actors/Streams, or
reviewing system architecture and configuration management.

---

## Dependency Injection: Constructor Injection Over Cake

The Cake Pattern was once idiomatic Scala DI but is now considered an
anti-pattern in production codebases. Prefer plain constructor injection.

### Why Cake fails in practice

- Developers end up with enormous "component" traits that mix dozens of
  responsibilities — a structural coupling trap
- Testing requires mocking/stubbing every trait mixed in, even when only one
  dependency is relevant
- Singletons without lifecycle management are the silent default
- JVM initialization order becomes unpredictable with deep `self:` constraints

### The correct approach

```scala
// Bad: Cake pattern
trait UserServiceComponent {
  self: DBServiceComponent with CacheServiceComponent =>
  val userService = new UserService

  class UserService {
    def find(id: Long) = dbService.query(id)
  }
}

// Good: Constructor injection
class UserService(db: DBRepository, cache: Cache)(implicit ec: ExecutionContext) {
  def find(id: Long): Future[Option[User]] =
    cache.get(id).orElse(db.findById(id))
}
```

**Pain-driven development**: If your constructor has too many arguments, that's
a signal your class has too many responsibilities — fix the architecture, not the
symptoms.

---

## Configuration Management

### Rule: Never call `ConfigFactory.load()` inside a class body

Calling `ConfigFactory.load()` inside a class hard-codes the config source and
makes testing impossible without environment manipulation.

### Correct pattern: typed config case classes

```scala
// Define typed config model at the module level
case class HttpClientConfig(
  baseUrl: String,
  timeout: FiniteDuration,
  maxConnections: Int
)

case class AppConfig(
  httpClient: HttpClientConfig,
  db: DbConfig
)

// Parse once at the application root (main / DI wiring)
object AppConfig {
  def load(): AppConfig = load(ConfigFactory.load())

  def load(raw: Config): AppConfig = AppConfig(
    httpClient = HttpClientConfig(
      baseUrl        = raw.getString("http.baseUrl"),
      timeout        = raw.getDuration("http.timeout").toScala,
      maxConnections = raw.getInt("http.maxConnections")
    ),
    db = DbConfig(
      url      = raw.getString("db.url"),
      poolSize = raw.getInt("db.poolSize")
    )
  )
}

// Component receives only what it needs
class HttpClient(config: HttpClientConfig) { ... }
class DbRepository(config: DbConfig) { ... }
```

**Benefits**: Immutable, type-safe, easily constructed in tests with any values.

---

## Choosing an Async Abstraction

| Abstraction | Good for | Bad for |
|-------------|----------|---------|
| `Future[T]` | Single async result, simple pipelines | Streams, bidirectional comms |
| Akka Actors | Stateful components, bidirectional messaging, WebSocket | Simple async transforms |
| Akka Streams / FS2 / ZIO Streams | Back-pressured pipelines, large data flows | Bidirectional dialogs |
| Monix `Task` / ZIO | Referentially-transparent effects, resource management | Teams unfamiliar with FP |

### Future: do's and don'ts

```scala
// Good: already computed value
Future.successful(42)

// Bad: wrapping pure computation adds overhead
Future { 1 + 1 }

// Good: async I/O
def fetchUser(id: Long)(implicit ec: ExecutionContext): Future[User] =
  httpClient.get(s"/users/$id").map(decode[User])

// Bad: blocking on Future result (deadlock risk on bounded pools)
val user = Await.result(fetchUser(1), 5.seconds) // never in library code

// Good: keep context
fetchUser(1).flatMap(user => fetchOrders(user.id))

// Good: parallel execution
val (userF, ordersF) = (fetchUser(1), fetchOrders(1))
for { user <- userF; orders <- ordersF } yield UserOrders(user, orders)
```

### Akka Actors: do's and don'ts

```scala
// Good: stateful component with encapsulated mutable state
class CounterActor extends Actor {
  private var count = 0

  def receive: Receive = {
    case Increment      => count += 1
    case GetCount(repl) => repl ! count
  }
}

// Bad: leaking actor state in async closures
class BadActor extends Actor {
  private var state = Map.empty[String, Int]

  def receive: Receive = {
    case Update(k, v) =>
      Future {
        // WRONG: `state` access from a different thread
        state = state.updated(k, v)
      }
  }
}

// Good: use context.become for state transitions
class TrafficLight extends Actor {
  def receive: Receive = red

  val red: Receive = {
    case Next => context.become(green)
  }
  val green: Receive = {
    case Next => context.become(yellow)
  }
  val yellow: Receive = {
    case Next => context.become(red)
  }
}
```

**Akka actor rules**:
- Evolve actor state **only** in response to received messages
- Mutate state via `context.become`, not external futures
- Never capture `sender()` into a `Future` closure — capture it immediately: `val s = sender(); Future { ... }.foreach(s ! _)`
- Always implement supervision strategies for non-trivial actor hierarchies
- Do not use Akka FSM — prefer `context.become` directly; FSM is complex for little gain

---

## Thread Pool Management

### Application thread pool (CPU-bound work)

```scala
// Default ForkJoin — good for CPU-bound, async, reactive workloads
import scala.concurrent.ExecutionContext.Implicits.global

// Or configure explicitly in application.conf (Play / Akka)
// akka.actor.default-dispatcher.fork-join-executor.parallelism-max = 8
```

### I/O thread pool (blocking I/O)

```scala
import java.util.concurrent.{Executors, ThreadFactory}
import java.util.concurrent.atomic.AtomicLong
import scala.concurrent.ExecutionContext

private val ioThreadPool: ExecutionContext = {
  val factory = new ThreadFactory {
    private val counter = new AtomicLong(0)
    def newThread(r: Runnable): Thread = {
      val t = new Thread(r, s"io-pool-${counter.incrementAndGet()}")
      t.setDaemon(true)
      t
    }
  }
  ExecutionContext.fromExecutorService(Executors.newCachedThreadPool(factory))
}

// Use explicitly — never expose as an implicit
def readFile(path: String): Future[String] =
  Future(blocking(scala.io.Source.fromFile(path).mkString))(ioThreadPool)
```

### Blocking I/O marker

Always mark blocking calls so the ForkJoin pool can compensate by spawning
additional threads:

```scala
import scala.concurrent.blocking

Future {
  blocking {
    // Any blocking call: JDBC, file I/O, Thread.sleep (in tests), etc.
    jdbcConnection.prepareStatement(sql).executeQuery()
  }
}
```

Without `blocking { }`:
- The ForkJoin pool does not know a thread is blocked
- All threads may end up blocked simultaneously → deadlock
- The pool cannot expand to maintain progress

---

## Performance and the Garbage Collector

### Rule: measure before optimizing

Profile before touching any performance-sensitive code. Tools:
- **YourKit Profiler** (best for heap/CPU analysis)
- **Oracle VisualVM** (free, good enough for many cases)
- **JMH** (micro-benchmarking — add as a test dependency, never guess at micro-level)
- **ScalaMeter** (Scala-native benchmarking)
- **Dropwizard Metrics** (production metrics)

### Avoid allocations in hot paths

```scala
// Bad: creates a new Set on every element evaluation
collection.filter(Set(a, b, c).contains(_))

// Good: hoist the set creation
val validIds = Set(a, b, c)
collection.filter(validIds.contains)

// Bad: two traversals + intermediate List
collection.filter(isValid).map(transform)

// Good: single traversal via collect
collection.collect { case x if isValid(x) => transform(x) }

// Good: lazy — no intermediate allocation for large collections
collection.view.filter(isValid).map(transform).toList
```

### GC-friendly collection operations

- Use `Iterator` or `.view` for processing large collections when the full
  result is not needed immediately
- Avoid boxing primitives — use `Array[Int]` or `IntBuffer` in tight numeric
  loops rather than `List[Int]` (which boxes each `Int`)
- Be wary of closures capturing large objects — they extend GC roots

---

## Streaming and Back-Pressure

Use streaming libraries when:
- The data volume is unbounded or large enough to exceed memory
- The producer is faster than the consumer (back-pressure needed)
- You need windowing, time-based operators, or complex fan-out/fan-in

Common choices:
- **Akka Streams** — mature, well-integrated with Akka ecosystem
- **FS2** (Functional Streams for Scala) — purely functional, good with Cats Effect / ZIO
- **ZIO Streams** — built into ZIO, referentially transparent
- **Monix Observable** — reactive, composable, works with standard Future or Task

### Back-pressure principle

```
Producer ──[buffer]──► Consumer (slow)
                ▲
           back-pressure signal
```

When the consumer is slow, the buffer fills and the back-pressure signal tells
the producer to slow down. Libraries that do NOT implement back-pressure (e.g.,
raw Akka Actors or Rx without operators) can lead to unbounded queue growth and
OOM errors.

**Always prefer libraries with built-in back-pressure** (Akka Streams, FS2, ZIO
Streams) when processing data pipelines between components of different speeds.

---

## Scalability Patterns

### Single-producer / multi-consumer

Writes are serialized; reads are parallelizable. Structure your system so that
a single authoritative component owns writes while many can read concurrently
(CQRS, event sourcing, disruptor pattern).

### Avoid shared mutable state across threads

```scala
// Dangerous: shared mutable Map without synchronization
class Registry {
  private val map = scala.collection.mutable.Map.empty[String, Service]
  def register(name: String, svc: Service): Unit = map(name) = svc // data race!
}

// Safe: AtomicReference + immutable Map
import java.util.concurrent.atomic.AtomicReference
class Registry {
  private val map = new AtomicReference(Map.empty[String, Service])
  def register(name: String, svc: Service): Unit =
    map.updateAndGet(_ + (name -> svc))
  def lookup(name: String): Option[Service] = map.get().get(name)
}
```

### Do not synchronize reads

```scala
// Bad: synchronizing reads limits parallelism (Amdahl's law)
def fetchCached(key: String): Option[String] = synchronized { cache.get(key) }

// Good: reads from immutable snapshot need no synchronization
private val cache = new AtomicReference(Map.empty[String, String])
def fetchCached(key: String): Option[String] = cache.get().get(key)
```
