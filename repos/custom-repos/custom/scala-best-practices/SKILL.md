---
name: scala-best-practices
description: >
  Use when writing, reviewing, or refactoring Scala code — including code
  reviews, Scala idioms (Option, Future, case classes, traits, implicits),
  null safety, error handling, immutability, type safety, concurrency
  (Future, thread pools, Actors), application architecture, and style
  questions. Triggers even when the user does not say "best practices" or
  "style guide." Applies to Scala 2.12, 2.13, and 3.x.
license: CC BY 4.0
metadata:
  author: custom
  version: "1.0"
  sources: "https://docs.scala-lang.org/style/, https://github.com/alexandru/scala-best-practices"
compatibility: Scala 2.12, 2.13, and 3.x
---

# Scala Best Practices Guide

Apply these rules when writing, reviewing, or refactoring Scala code. Rules are
labeled **MUST** (never violate) or **SHOULD** (strong preference, deviate only
with a documented reason).

For deeper detail on a specific topic, load the appropriate reference file (see
the **Reference Files** section at the bottom).

---

## Style & Formatting

- Use **2-space indentation** — never tabs
- Target **80–100 character line length** (follow project convention)
- Names:
  - Classes, traits, objects → `UpperCamelCase` (e.g., `UserService`)
  - Methods, vals, vars, parameters → `lowerCamelCase` (e.g., `fetchUser`)
  - Constants → `UpperCamelCase` (e.g., `MaxRetries`, `DefaultTimeout`)
  - Packages → `lowercase` dot-separated (e.g., `com.example.users`)
  - Type parameters → single uppercase letter (`A`, `B`) or descriptive (`Key`, `Value`)
- Public functions **SHOULD** have explicit return types — do not rely on inference for public APIs
- Use `scalafmt` or `scalariform` for automated formatting; configure once and commit the config

---

## Immutability (MUST)

- **MUST NOT** use `var` inside a `case class` — it breaks `equals` and `hashCode`
- **SHOULD** use immutable data structures by default (`List`, `Map`, `Set` from `scala.collection.immutable`)
- **SHOULD NOT** update a `var` using loops or conditions — use `foldLeft`, `map`, `filter`, or for-comprehensions
- **SHOULD NOT** use `var` as shared state — use `AtomicReference[T]` or STM if mutation is truly required

```scala
// Bad
var sum = 0
for (elem <- elements) sum += elem.value

// Good
val sum = elements.foldLeft(0)((acc, e) => acc + e.value)
// Even better — use the standard library
val sum = elements.map(_.value).sum
```

---

## Null Safety (MUST)

- **MUST NOT** use `null` — use `Option[T]` instead; the compiler enforces handling
- **MUST NOT** call `Option.get` — it throws `NoSuchElementException`, defeating the purpose
- **MUST NOT** call `Seq.head` on a potentially empty sequence — use `headOption`

```scala
// Bad
def greet(name: String): Unit =
  if (name != null) println(s"Hello, $name") else println("Hello, anon")

// Good
def greet(name: Option[String]): Unit =
  println(s"Hello, ${name.getOrElse("anon")}")

// Bad — can throw
val first = list.head

// Good
val first = list.headOption.getOrElse(defaultValue)
```

---

## Error Handling (MUST)

- **MUST NOT** throw exceptions for user-input validation or flow control — encode errors in the return type using `Either[Error, Result]`, `Try[T]`, or `Option[T]`
- **MUST NOT** catch `Throwable` — use `scala.util.control.NonFatal` to avoid swallowing fatal JVM errors (`OutOfMemoryError`, etc.)
- **MUST NOT** use magic values (e.g., `-1` for "not found") — use `Option` or an ADT

```scala
// Bad: exception for business logic
def parseAge(s: String): Int =
  if (s.toIntOption.isEmpty) throw new IllegalArgumentException(s"bad age: $s") // toIntOption: Scala 2.13+
  else s.toInt

// Good: encode failure in return type
// Note: String#toIntOption is Scala 2.13+; on Scala 2.12 use: Try(s.toInt).toOption.toRight(...)
def parseAge(s: String): Either[String, Int] =
  s.toIntOption.toRight(s"Invalid age: $s")

// Bad: catches fatal errors too
try { doSomething() } catch { case ex: Throwable => log(ex) }

// Good
import scala.util.control.NonFatal
try { doSomething() } catch { case NonFatal(ex) => log(ex) }
```

---

## Type Safety (MUST)

- **MUST NOT** use `return` — Scala is expression-oriented; `return` inside lambdas throws `NonLocalReturnException` (**Scala 3**: `return` is deprecated at the language level and triggers a compiler warning even outside lambdas)
- **SHOULD NOT** use `Any`, `AnyRef`, `isInstanceOf`, or `asInstanceOf` — model with sealed trait ADTs instead
- **SHOULD NOT** use Java's `Date` or `Calendar` — use `java.time` (JSR-310)
- **MUST** serialize dates as Unix timestamp (millis since epoch, UTC) or ISO 8601

```scala
// Bad: losing type safety
val json: Any = parse(input)
if (json.isInstanceOf[String]) doWithString(json.asInstanceOf[String])

// Good: sealed ADT
sealed trait JsValue
final case class JsString(v: String)  extends JsValue
final case class JsNumber(v: Double)  extends JsValue
final case class JsObject(m: Map[String, JsValue]) extends JsValue
case object JsNull extends JsValue
```

---

## Case Classes (MUST)

- Case classes **SHOULD** be `final` — extending a case class silently breaks `equals`/`hashCode`/`copy`
- **MUST NOT** put `var` fields in case classes
- **SHOULD NOT** define case classes nested inside other classes — breaks Java serialization (closes over `this`)

```scala
// Bad
case class User(name: String, var age: Int) // mutable = broken equals

// Bad
case class User(name: String) extends PersonLike // extending breaks equality

// Good
final case class User(name: String, age: Int)
```

---

## Traits & Objects (SHOULD)

- **SHOULD NOT** define useless traits that have only one implementation — avoid Java cargo-cult "interface for everything"
- **SHOULD NOT** declare abstract `var` members in traits — use `def`; callers can override as `val` or `var`
- **MUST NOT** include classes, traits, or objects inside `package objects` — exception: implicit value classes for the "pimp my library" pattern
- **SHOULD NOT** use `scala.App` — it uses deprecated `DelayedInit` (**Scala 2.12/2.13**); in **Scala 3**, prefer `@main def run(): Unit = ...` as the idiomatic entry point

```scala
// Bad: useless trait
trait PersonLike { def name: String; def age: Int }
case class Person(name: String, age: Int) extends PersonLike

// Good: if polymorphism not needed
final case class Person(name: String, age: Int)

// Bad: scala.App
object Main extends App { println("hello") }

// Good (Scala 2.12 / 2.13)
object Main { def main(args: Array[String]): Unit = println("hello") }

// Good (Scala 3)
@main def run(): Unit = println("hello")
```

---

## Collections Best Practices

Choose the right collection for the use case:

| Need | Use |
|------|-----|
| Prepend / head-tail access (O(1)) | `List` |
| Indexed random access | `Vector` |
| Append to end | `Vector` |
| FIFO queue | `Queue` |
| Membership test | `Set` |
| Ordered membership | `SortedSet` |
| Key-value lookup | `Map` |

- **SHOULD NOT** use `List` for indexed access or append (O(n))
- Avoid unnecessary traversals — chain `filter` and `map` into `collect` or use lazy views
- **SHOULD** only use head/tail decomposition on `List` (O(1)); other `Seq` types may be O(n)

---

## Concurrency (MUST)

- **MUST** use `scala.concurrent.blocking { }` around any blocking I/O inside a `Future` — signals the thread pool to expand
- **MUST NOT** wrap CPU-only operations in `Future { }` — it adds scheduling overhead with no gain; use `Future.successful(value)` for already-computed results
- **MUST NOT** hardcode `import scala.concurrent.ExecutionContext.Implicits.global` inside library code — pass `ExecutionContext` as an implicit parameter
- **SHOULD NOT** call `Await.result` or `Await.ready` except at application boundaries
- **SHOULD** use a dedicated thread pool for blocking I/O, separate from the app's CPU pool
- All public APIs **SHOULD** be thread-safe; document clearly if they are not

```scala
// Bad: tight coupling to global EC
import scala.concurrent.ExecutionContext.Implicits.global
def fetchUser(id: Long): Future[User] = ???

// Good: injectable EC
def fetchUser(id: Long)(implicit ec: ExecutionContext): Future[User] = ???

// Bad: blocking without marking
Future { db.query("SELECT ...") }

// Good
import scala.concurrent.blocking
Future { blocking { db.query("SELECT ...") } }
```

---

## Application Architecture

- **SHOULD NOT** use the Cake Pattern — it hides coupling and makes testing hard; prefer **constructor injection**
- **SHOULD NOT** call `ConfigFactory.load()` inside classes — inject a typed `Config` case class through the constructor
- **SHOULD NOT** apply performance optimizations without profiling first (use YourKit, VisualVM, JMH, or ScalaMeter)
- **SHOULD** be mindful of GC pressure — avoid unnecessary allocations in hot paths; use lazy views for chained collection transforms

```scala
// Bad: scattered config loading
class MyService {
  private val timeout = ConfigFactory.load().getDuration("service.timeout")
}

// Good: typed config injected
case class MyServiceConfig(timeout: FiniteDuration)
class MyService(config: MyServiceConfig) { ... }
```

---

## Gotchas

These are non-obvious traps specific to Scala that agents commonly miss:

- **`return` in a lambda** — Scala implements `return` inside anonymous functions via `NonLocalReturnException` at runtime. Never use `return`. (**Scala 3**: `return` is deprecated at the language level and emits a compiler warning even outside lambdas.)
- **Catching `Throwable`** — This catches `OutOfMemoryError` and `StackOverflowError`. The JVM may be in a non-recoverable state; catching these prevents the process from dying cleanly. Always use `NonFatal`.
- **`Option.get`** — Throws `NoSuchElementException`. It is not safer than `null`; it just moves the crash.
- **`Seq.head`** — Throws on an empty collection. Use `headOption`.
- **Extending case classes** — Breaks equality: `new Bar(1, 2) == new Bar(1, 3)` may return `true`. Always mark case classes `final`.
- **`var` in case class** — Breaks `hashCode`/`equals` contract. Mutable case classes cannot be reliably used as Map keys.
- **`Array` head/tail** — `tail` on `Array` is O(n); only use head/tail decomposition on `List`.
- **Nested case classes** — Serialization closes over `this` of the enclosing object, serializing everything. Keep case classes at the top level or companion object.
- **`scala.App`** — Uses `DelayedInit`, deprecated in Scala 2.12/2.13. Fields in the body become publicly accessible members. In **Scala 3**, use `@main def run(): Unit = ...` as the entry point.
- **Abstract `var` in trait** — Locks subclasses into using `var`. Use `def` to allow `val` or `var` overrides.
- **`ConfigFactory.load()` in class bodies** — Hard to override in tests, violates DI. Always inject configuration.

---

## Reference Files

Load these files **only when needed** for the specific task:

- **`references/language-rules.md`** — Load when writing or reviewing Scala code; contains detailed rules with code examples for functional patterns, ADTs, implicits, and pattern matching.
- **`references/style-guide.md`** — Load when formatting or structuring code; covers official Scala style guide details: indentation, declarations, Scaladoc, import ordering.
- **`references/architecture-concurrency.md`** — Load when designing services, working with Futures/Actors/Streams, or reviewing system architecture and config management.
- **`evals/evals.json`** — Test cases for validating this skill's triggering and output quality.
