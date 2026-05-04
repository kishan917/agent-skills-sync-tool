# Scala Language Rules — Detailed Reference

Load this file when writing or reviewing Scala code and you need detailed
examples or rationale beyond what is in `SKILL.md`.

---

## Functional Error Handling

### Use `Either[Error, Result]` for recoverable business errors

```scala
sealed trait AppError
case class ValidationError(msg: String) extends AppError
case class NotFoundError(id: Long)       extends AppError

def findUser(id: Long): Either[AppError, User] =
  userRepo.findById(id).toRight(NotFoundError(id))

// toIntOption is Scala 2.13+; on Scala 2.12 use: Try(s.toInt).toOption
def parseAge(s: String): Either[AppError, Int] =
  s.toIntOption
    .filter(_ > 0)
    .toRight(ValidationError(s"'$s' is not a valid positive age"))
```

### Use `Try[T]` when wrapping Java APIs that throw

```scala
import scala.util.{Try, Success, Failure}

def parseJson(s: String): Try[Json] = Try(Json.parse(s))

parseJson(input) match {
  case Success(json) => process(json)
  case Failure(ex)   => logger.warn(s"Parse failed: ${ex.getMessage}")
}
```

### Compose with `for`-comprehension

`Either` has been right-biased since **Scala 2.12**, so `for`-comprehension chains work natively on all supported versions (2.12, 2.13, 3.x).

```scala
def processRequest(raw: String): Either[AppError, Response] =
  for {
    json    <- parseJson(raw).toEither.left.map(e => ValidationError(e.getMessage))
    userId  <- json.field("userId").flatMap(_.asLong).toRight(ValidationError("missing userId"))
    user    <- findUser(userId)
  } yield buildResponse(user)
```

---

## Algebraic Data Types (ADTs)

Use sealed traits with `final case class` to model finite sets of possibilities.
The compiler warns on non-exhaustive pattern matches.

```scala
sealed trait PaymentStatus
final case class Paid(transactionId: String, at: java.time.Instant) extends PaymentStatus
final case class Failed(reason: String)                              extends PaymentStatus
case object Pending                                                   extends PaymentStatus

def describeStatus(s: PaymentStatus): String = s match {
  case Paid(id, at)  => s"Paid (txn $id at $at)"
  case Failed(reason) => s"Failed: $reason"
  case Pending        => "Awaiting payment"
}
// Compiler warns if you miss a branch — exhaustiveness checking is free safety
```

**Rule**: Prefer `sealed trait` + `final case class` over plain class hierarchies whenever
the set of subtypes is closed (known at compile time).

---

## Implicits Best Practices

### Pass `ExecutionContext` as an implicit in the second parameter list

```scala
// Correct — implicit in second group (Scala 2.12 / 2.13)
def fetchData(url: String)(implicit ec: ExecutionContext): Future[String] = ???

// Scala 3: use `using` keyword instead of `implicit`
def fetchData(url: String)(using ec: ExecutionContext): Future[String] = ???

// Wrong — implicit in first group can confuse callers (all versions)
def fetchData(implicit ec: ExecutionContext, url: String): Future[String] = ???
```

### Implicit conversions: use sparingly, prefer value classes

```scala
// Scala 2.12 / 2.13: implicit value class (zero allocation) for extension methods
package object syntax {
  implicit class RichString(val s: String) extends AnyVal {
    def toSlug: String = s.toLowerCase.replaceAll("\\s+", "-")
  }
}

// Scala 3: use `extension` methods instead — no wrapper class needed
extension (s: String)
  def toSlug: String = s.toLowerCase.replaceAll("\\s+", "-")

// Usage (both styles)
import com.example.syntax._
"Hello World".toSlug // => "hello-world"
```

### Avoid implicit conversions that silently change types

Implicit conversions between unrelated types cause confusing compile errors
far from the actual mistake. Prefer explicit conversion methods or extension
methods that widen without converting.

---

## Pattern Matching

### Always match exhaustively on sealed types

```scala
sealed trait Color
case object Red   extends Color
case object Green extends Color
case object Blue  extends Color

// Good — exhaustive, compiler validates
def hex(c: Color): String = c match {
  case Red   => "#FF0000"
  case Green => "#00FF00"
  case Blue  => "#0000FF"
}
```

### Use guards carefully — they break exhaustiveness checking

```scala
// This is NOT exhaustive even though it looks complete
x match {
  case n if n > 0  => "positive"
  case n if n < 0  => "negative"
  // n == 0 is silently unhandled — runtime MatchError
}

// Fix: add explicit case
x match {
  case n if n > 0 => "positive"
  case n if n < 0 => "negative"
  case _          => "zero"
}
```

### Prefer `collect` over `filter` + `map` + `get`

```scala
val items: List[Option[String]] = List(Some("a"), None, Some("b"))

// Bad
items.filter(_.isDefined).map(_.get)

// Good
items.collect { case Some(v) => v }
// or
items.flatten
```

---

## Collections Performance

| Operation | List | Vector | Array | Queue |
|-----------|------|--------|-------|-------|
| head      | O(1) | O(1)   | O(1)  | O(1)  |
| tail      | O(1) | O(log n)| O(n) | O(1)amort |
| apply(i)  | O(n) | O(log n)| O(1) | O(n)  |
| append    | O(n) | O(log n)| O(n) | O(1)amort |
| prepend   | O(1) | O(log n)| O(n) | O(n)  |

**Head/tail decomposition is only O(1) on `List`.**
Using `+:` extractor on `Array` or `Vector` creates a new collection on every call — O(n).

### Avoid repeated `filter`+`map` — use lazy views or `collect`

```scala
val data: List[Int] = (1 to 1_000_000).toList

// Bad: two passes + intermediate List allocation
data.filter(_ % 2 == 0).map(_ * 3)

// Good: single lazy pass
data.view.filter(_ % 2 == 0).map(_ * 3).toList

// Or with collect for combined filter+map
data.collect { case n if n % 2 == 0 => n * 3 }
```

---

## Concurrency — Detailed Patterns

### Blocking I/O: always use `blocking { }`

Scala's ForkJoin pool monitors `BlockContext` and spawns extra threads when it
sees `blocking { }`. Without it, all ForkJoin threads may block on I/O and
deadlock the pool.

```scala
import scala.concurrent.{Future, blocking, ExecutionContext}

def queryDb(sql: String)(implicit ec: ExecutionContext): Future[Seq[Row]] =
  Future {
    blocking {
      connection.executeQuery(sql) // JDBC is always blocking
    }
  }
```

### Dedicated I/O thread pool

```scala
import java.util.concurrent.Executors
import scala.concurrent.ExecutionContext

private val ioEc: ExecutionContext =
  ExecutionContext.fromExecutorService(Executors.newCachedThreadPool())

def readFile(path: String): Future[String] =
  Future { blocking { scala.io.Source.fromFile(path).mkString } }(ioEc)
```

Keep the I/O pool private — do not expose it as an implicit so it cannot
accidentally be used for CPU-bound work.

### Never block the app's main EC

```scala
// Bad: blocks the calling thread and a thread-pool thread
val result = Await.result(fetchData(), 5.seconds) // only acceptable in tests / main()

// Good: stay in Future context
fetchData().map(process).recover { case NonFatal(ex) => fallback(ex) }
```

### Atomic shared state

```scala
import java.util.concurrent.atomic.AtomicReference

class Cache[K, V] {
  private val store = new AtomicReference(Map.empty[K, V])

  def put(k: K, v: V): Unit =
    store.updateAndGet(_ + (k -> v))

  def get(k: K): Option[V] =
    store.get().get(k)
}
```

---

## Public API Design

### Always annotate public return types

```scala
// Bad — inferred type may be wider than intended
def buildRunnable(name: String) = new Runnable {
  def run(): Unit = println(name)
  def sayHello(): Unit = println(s"Hello, $name") // leaks into inferred type
}
// Inferred: Runnable { def sayHello(): Unit } — not what you want

// Good
def buildRunnable(name: String): Runnable = new Runnable {
  def run(): Unit = println(name)
  private def sayHello(): Unit = println(s"Hello, $name")
}
```

### Document async boundaries

For any component that communicates asynchronously, the Scaladoc comment MUST
describe:
- Ordering guarantees (do messages arrive in order?)
- Concurrency guarantees (is the callback called on a specific thread?)
- Failure behavior (what happens on timeout or error?)
- Back-pressure behavior (will slow consumers cause memory pressure?)

---

## Version-Specific API Notes

### Scala 2.13 additions (not available in 2.12)

| Feature | 2.12 alternative |
|---------|-----------------|
| `String#toIntOption`, `toLongOption`, `toDoubleOption` | `Try(s.toInt).toOption` |
| `LazyList` (replaces deprecated `Stream`) | Use `Stream` in 2.12 |
| `scala.util.Using` (resource management / `try-with-resources`) | Use `scala.io.Source` with `try/finally` |
| `@nowarn` suppression annotation | Not available; use `@unchecked` where applicable |
| New collections API (`View`, `ArraySeq` as default array wrapper) | Old `CanBuildFrom`-based API |

### Scala 3 additions (not available in 2.12 / 2.13)

All rules in this file apply to Scala 2.12, 2.13, and 3.x. The items below are
**Scala 3 additions** — prefer them when the project targets Scala 3.

- **`enum`** replaces `sealed trait` + `case object` for simple closed ADTs
- **`opaque type`** for zero-overhead domain wrappers instead of value classes
- **`given`/`using`** replaces `implicit val`/`implicit def` / `implicit` parameters
- **`extension`** methods replace implicit value class syntax cleanly
- **`export`** clause reduces boilerplate delegation patterns
- **`@main`** annotation replaces `def main(args: Array[String]): Unit`
- **`return`** is deprecated at the language level (compiler warning)
- **Union types** (`A | B`) and **intersection types** (`A & B`) for expressive type constraints
- **`derives`** clause for automatic type class instance derivation

```scala
// Scala 3: opaque type for type-safe IDs (zero runtime cost)
opaque type UserId = Long
object UserId:
  def apply(id: Long): UserId = id
  extension (id: UserId) def value: Long = id

// Scala 3: enum for ADTs (replaces sealed trait + case objects)
enum Color:
  case Red, Green, Blue

// Scala 3: given/using (replaces implicit)
given defaultLogger: Logger = Logger("app")
def log(msg: String)(using logger: Logger): Unit = logger.info(msg)
```
