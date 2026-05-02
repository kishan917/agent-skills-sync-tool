---
description: 'Scala 2.13 programming language coding conventions and best practices for functional programming, type safety, and production code quality.'
applyTo: '**/*.scala, **/build.sbt, **/build.sc'
---

**Target runtime:** Scala 2.13.x on JVM 11+
**Audience:** AI coding agents and human reviewers
**Goal:** Produce idiomatic, performant, maintainable Scala code — deterministically.

## Table of Contents
1. [File & Naming Conventions](#1-file--naming-conventions)
2. [Formatting](#2-formatting)
3. [Imports](#3-imports)
4. [Type System & Generics](#4-type-system--generics)
5. [Object-Oriented Design](#5-object-oriented-design)
6. [Functional Idioms](#6-functional-idioms)
7. [Error Handling](#7-error-handling)
8. [Performance](#8-performance)
9. [Redundancy Elimination & DRY](#9-redundancy-elimination--dry)
10. [Extracting Common Behaviour](#10-extracting-common-behaviour)
11. [Concurrency](#11-concurrency)
12. [Documentation](#12-documentation)
13. [Testing](#13-testing)
14. [Project Layout (Maven)](#14-project-layout-maven)
15. [Anti-Patterns — Do Not](#15-anti-patterns--do-not)
16. [Pre-Commit Checklist](#16-pre-commit-checklist)

## 1. File & Naming Conventions
### 1.1 File Names
- **One** top-level class / trait / object per file; name the file after it: `UserService.scala`.
- Package objects → `package.scala`.
- A sealed ADT and all its cases may live in one file, named after the root type.

### 1.2 Identifier Conventions

| Kind | Style | Example |
| --- | --- | --- |
| Classes / Traits / Objects | `UpperCamelCase` | `OrderRepository` |
| Methods / Values / Variables | `lowerCamelCase` | `findById` |
| Constants (`final val` / `val` in object) | `UpperCamelCase` | `MaxRetries`, `DefaultTimeout` |
| Type Parameters | Single uppercase letter or short `UpperCamelCase` | `A`, `F`, `Elem`, `Req` |
| Packages | All lowercase, no underscores | `com.acme.billing` |
| Acronyms (≥ 3 chars) | Capitalise first letter only | `HttpClient`, `JsonCodec` |

### 1.3 Special Naming Rules
- **Booleans:** `isEmpty`, `isValid`, `hasErrors` — never `getIsValid`.
- **Factories** in companions: `apply`, `from`, `of`, `empty`, `default`.
- **Private helpers:** rely on `private` visibility; avoid `_` prefixes.
- **Type aliases:** `UpperCamelCase`, placed in a package object or companion.

## 2. Formatting

### 2.1 Indentation & Width
- **2-space** indent. No tabs. Ever.
- Soft limit **100 columns**; hard limit **120 columns**.

### 2.2 Braces & Blocks

```scala
// Single-expression — no braces
def double(n: Int): Int = n * 2

// Multi-expression — opening brace on same line
def process(input: String): Result = {
val sanitized = sanitize(input)
transform(sanitized)
}
```

Always use braces for if/else when either branch is multi-line.
Single-line if without braces is OK only when both branches are short expressions:

```scala
val label = if (count == 1) "item" else "items"
```

### 2.3 Blank Lines

| Where | Count |
| --- | --- |
| Between method definitions | 1 |
| Before companion object after the class | 2 |
| Between logical sections inside a class | 1 |
| End of file | Single trailing newline, no blank line |

### 2.4 Parameter Lists

When a method or constructor has 3+ parameters, place each on its own line:

```scala
final case class Order(
id: OrderId,
customerId: CustomerId,
items: List[LineItem],
placedAt: Instant
)

def createOrder(
customerId: CustomerId,
items: List[LineItem],
discount: Option[Discount] = None
)(implicit ec: ExecutionContext): Future[Order] = ...
```

### 2.5 Method Chaining

```scala
users
  .filter(_.isActive)
  .sortBy(_.name)
  .map(_.email)
  .distinct
```

One call per line when the chain exceeds 2 calls.
Indent continuation by 2 spaces from the initial expression.

## 3. Imports

### 3.1 Order & Grouping

```scala
// 1. Java / javax
import java.time.Instant
import java.util.UUID

// 2. Scala standard library
import scala.collection.mutable
import scala.concurrent.{ExecutionContext, Future}

// 3. Third-party libraries
import cats.effect.IO
import io.circe.syntax._
import org.json4s.native.Serialization

// 4. Project imports
import com.acme.domain.User
```

Blank line between each group.
Curly-brace grouping for multiple imports from the same package.

### 3.2 Rules

| ✅ Do | ❌ Don't |
| --- | --- |
| `scala.jdk.CollectionConverters._` | `scala.collection.JavaConverters._` (deprecated) |
| Explicit imports in production code | Wildcard `_` imports (exception: test files, ADT case imports) |
| Fully-qualified package roots | Relative imports |

## 4. Type System & Generics

### 4.1 When to Annotate Types

| Context | Annotate? |
| --- | --- |
| Public / protected method return types | Always |
| Implicit definitions | Always |
| Public val / var | Always |
| Local val / var (obvious type) | Omit |
| Private methods (obvious type) | Omit |
| Lambda parameters (inferable) | Omit |

```scala
// Public — annotated
def findUser(id: UserId): Option[User] = repo.lookup(id)

// Local — inferred
val count = users.size

// Lambda — inferred
users.filter(u => u.isActive)
```

### 4.2 Generics — Naming & Constraints

Use descriptive single-letter or short names for type parameters:

| Letter | Convention |
| --- | --- |
| `A`, `B` | Generic payload / element |
| `F[_]` | Effect / wrapper type |
| `K`, `V` | Key / Value in maps |
| `T` | General "thing" (use sparingly; prefer `A`) |
| `Req`, `Res` | When the domain meaning adds clarity |

### 4.3 Variance

```scala
// Covariant output (producers)
sealed trait Result[+A]

// Contravariant input (consumers)
trait JsonWriter[-A] {
def write(value: A): String
}

// Invariant when the type is both read and written
final class Ref[A](private var value: A)
```

Declare variance annotations on sealed ADTs and pure interfaces.
Use invariance when the container is mutable or reads and writes A.
Use `+` (covariant) for "output" types, `-` (contravariant) for "input" types.

### 4.4 Upper & Lower Bounds

```scala
// Upper bound — A must be a subtype of Serializable
def serialize[A <: Serializable](value: A): Array[Byte] = ...

// Lower bound — useful for covariant types that need to widen
sealed trait Option[+A] {
  def getOrElse[B >: A](default: => B): B
}
```

Prefer upper bounds (`<:`) to constrain generic inputs.
Prefer context bounds over implicit parameter lists when a single typeclass is required:

```scala
// Good — context bound
def toJson[A: JsonEncoder](value: A): String = ...

// Equivalent but more verbose
def toJson[A](value: A)(implicit enc: JsonEncoder[A]): String = ...
```

### 4.5 Type Aliases & Opaque Types

```scala
// Use type aliases to simplify complex signatures
type UserId = String
type Result[A] = Either[AppError, A]

// Place in companion or package object
object Types {
  type ServiceResponse[A] = Future[Either[ServiceError, A]]
}
```

Use type aliases to improve readability, not to obscure.
For newtypes / tagged types in 2.13, consider value classes or a lightweight library.

### 4.6 Avoid Over-Abstraction

```scala
// Too abstract — reader needs to mentally resolve 4 type params
def process[F[_]: Monad, A: Decoder, B: Encoder, E: Show](
input: F[A]
)(handler: A => Either[E, B]): F[B]

// Better — constrain to the level your callers actually need
def processOrder(input: Future[RawOrder])(
implicit ec: ExecutionContext
): Future[ProcessedOrder]
```

Generalise when you have ≥ 2 concrete call sites that would benefit.
Don't parameterise pre-emptively — concrete first, abstract later.

### 4.7 Manifest and ClassTag

Never use `Manifest` (deprecated). Use `ClassTag` or `TypeTag` when runtime type information is needed.
Pass `ClassTag` as a context bound:

```scala
def newArray[A: ClassTag](size: Int): Array[A] = new Array[A](size)
```

## 5. Object-Oriented Design

### 5.1 Classes

```scala
final case class User(
  id: UserId,
  name: String,
  email: Email,
  createdAt: Instant
)
```

Prefer `case class` for data / value types.
Mark classes `final` unless explicitly designed for extension.
Use `sealed` for ADT root types.

### 5.2 Traits

```scala
trait UserRepository {
  def findById(id: UserId): Option[User]
  def save(user: User): Unit
}
```

Use traits for interfaces and mixins.
Avoid mutable state in traits.
Prefer composition over deep linearisation chains.

### 5.3 Companion Objects

```scala
final case class Money(amount: BigDecimal, currency: Currency)

object Money {
val Zero: Money = Money(BigDecimal(0), Currency.USD)

def fromCents(cents: Long, currency: Currency): Money =
Money(BigDecimal(cents) / 100, currency)

implicit val ordering: Ordering[Money] = Ordering.by(_.amount)
}
```

Place factories, constants, and implicits in the companion.

### 5.4 Sealed ADTs

```scala
sealed trait PaymentStatus
object PaymentStatus {
  case object Pending                            extends PaymentStatus
  case object Completed                          extends PaymentStatus
  final case class Failed(reason: String)        extends PaymentStatus
  final case class Refunded(amount: BigDecimal)  extends PaymentStatus
}
```

Nest cases inside the companion for a clean namespace.
Exhaustive matching is enforced by the compiler — no wildcard needed.

### 5.5 Value Classes

```scala
final case class UserId(value: String) extends AnyVal
```

Use for zero-cost wrappers that prevent type confusion.
Restrictions: single `val` parameter, no other fields, limited nesting.

## 6. Functional Idioms

### 6.1 Option

```scala
// Good
user.map(_.name).getOrElse("Anonymous")
user.fold("Anonymous")(_.name)

// Bad — defeats the purpose
if (user.isDefined) user.get.name else "Anonymous"
```

Never call `.get` on `Option` in production code.

### 6.2 Either (Right-Biased in 2.13)

```scala
def parse(input: String): Either[ParseError, Config] = ...

for {
config <- parse(raw)
valid  <- validate(config)
} yield valid
```

Left = error channel. Right = success channel.

### 6.3 Collections

| Need | Use |
| --- | --- |
| General purpose, sequential | `List` |
| Indexed random access | `Vector` |
| Unique elements | `Set` |
| Key-value lookup | `Map` |
| Mutable (local scope only) | `mutable.Buffer`, `mutable.Map` — always qualified |

```scala
// Lazy intermediate transformations on large collections
val result = largeList.view.filter(p).map(f).toList
```

Default to immutable collections (the default import in 2.13).
For Java interop: `scala.jdk.CollectionConverters._`.

### 6.4 For-Comprehensions

```scala
for {
user  <- findUser(id)
order <- latestOrder(user)
if order.total > threshold
} yield Summary(user.name, order.total)
```

Use when chaining ≥ 2 `flatMap`/`map`/`withFilter` calls.

### 6.5 Avoid Null

Never return `null`.
Wrap Java interop immediately: `Option(javaMethod())`.

### 6.6 Partial Functions & collect

```scala
// Preferred — filter + transform in one pass
items.collect { case Item(name, price) if price > 0 => name }
```

## 7. Error Handling

### 7.1 Decision Matrix

| Scenario | Type |
| --- | --- |
| Absence of a value | `Option[A]` |
| Expected, recoverable failure | `Either[E, A]` |
| Wrapping code that throws | `Try[A]` |
| Validation with error accumulation | Cats `Validated` or manual `List[Error]` |
| Truly fatal / irrecoverable | Let the exception propagate |

### 7.2 Try

```scala
import scala.util.{Try, Success, Failure}

Try(parseJson(raw)) match {
case Success(json) => process(json)
case Failure(ex)   => logAndFallback(ex)
}

// Convert to Either for pure pipelines
Try(dangerousOp()).toEither.left.map(AppError.fromThrowable)
```

### 7.3 Exception Discipline

```scala
import scala.util.control.NonFatal

try riskyOperation()
catch { case NonFatal(ex) => handleGracefully(ex) }
```

Never use exceptions for control flow.
Never catch `Throwable` or `Error`.
Catch `NonFatal` only at boundary layers.

## 8. Performance

### 8.1 Collection Choice & Complexity

| Operation | List | Vector | Array | mutable.ArrayBuffer |
| --- | --- | --- | --- | --- |
| Prepend | O(1) | ~O(1) | O(n) | O(n) |
| Append | O(n) | ~O(1) | O(n) | Amortised O(1) |
| Random access | O(n) | ~O(1) | O(1) | O(1) |
| Iteration | Excellent | Good | Best | Good |

Choose the right collection for the dominant operation.
Use `Array` or `ArraySeq` for hot inner loops where allocation cost matters.

### 8.2 Lazy Evaluation & Views

```scala
// Bad — creates 2 intermediate collections
val result = hugeList.filter(expensive).map(transform).take(10)

// Good — single pass, short-circuits at 10 elements
val result = hugeList.view.filter(expensive).map(transform).take(10).toList

// Also good — LazyList for potentially infinite sequences
val fibs: LazyList[BigInt] = BigInt(0) #:: BigInt(1) #:: fibs.zip(fibs.tail).map { case (a, b) => a + b }
```

Use `.view` for chained transformations where you don't need all intermediate results.
Use `LazyList` (replaces deprecated `Stream`) for deferred/infinite sequences.
Use `Iterator` when you consume elements exactly once.

### 8.3 Avoid Unnecessary Allocations

```scala
// Bad — creates a tuple and immediately destructures
users.map(u => (u.id, u.name)).toMap

// Good — same result, same allocation, but be aware of it
users.iterator.map(u => u.id -> u.name).toMap

// Bad — string concatenation in a loop
var s = ""
for (item <- items) s += item.toString  // O(n²)

// Good
val s = items.mkString
// or
val sb = new StringBuilder
items.foreach(sb.append)
```

### 8.4 Tail Recursion

```scala
import scala.annotation.tailrec

@tailrec
def gcd(a: Int, b: Int): Int =
if (b == 0) a else gcd(b, a % b)
```

Always annotate with `@tailrec` so the compiler verifies the optimisation.
Prefer tail recursion or collection operations over mutable while loops.

### 8.5 Memoisation & Caching

```scala
// Lazy val for one-time expensive init
lazy val config: AppConfig = loadConfig()

// For repeated lookups, use a Map or a caching library
private val cache: mutable.Map[Key, Value] = mutable.Map.empty

def lookup(key: Key): Value =
  cache.getOrElseUpdate(key, computeExpensive(key))
```

Use `lazy val` for deferred single-shot initialization.
Use explicit caching structures for repeated lookups; document eviction policy.

### 8.6 Concurrency Performance

```scala
// Bad — sequential execution disguised as parallel
for {
a <- fetchA()   // starts here
b <- fetchB()   // waits for a to complete
} yield combine(a, b)

// Good — start both futures before the for-comprehension
val futA = fetchA()
val futB = fetchB()
for {
a <- futA
b <- futB
} yield combine(a, b)
```

### 8.7 Boxing & Specialisation

Be aware that generic code over primitives (`Int`, `Long`, `Double`) causes boxing.
For performance-critical numeric code, prefer `Array[Int]` over `List[Int]`.
Consider `@specialized` on hot-path generic methods (use sparingly — increases bytecode size).

### 8.8 Benchmarking Discipline

Never optimise without measurement.
Use JMH (`sbt-jmh` or the Maven plugin) for micro-benchmarks.
Profile with `async-profiler` or YourKit for macro-level analysis.

## 9. Redundancy Elimination & DRY

### 9.1 Principles
Don't Repeat Yourself — but don't abstract prematurely either.
Extract a shared abstraction only when you have ≥ 2 concrete instances of the same pattern.
Distinguish between incidental duplication (same code by coincidence) and essential duplication (same business rule in two places). Only eliminate the latter.

### 9.2 Constants over Magic Values

```scala
// Bad
if (retries > 3) fail()
Thread.sleep(5000)

// Good
private val MaxRetries = 3
private val RetryDelayMs = 5000L

if (retries > MaxRetries) fail()
Thread.sleep(RetryDelayMs)
```

### 9.3 Shared Utility Methods

```scala
// Bad — same JSON parsing logic repeated in 5 classes
val mapper = new ObjectMapper()
mapper.registerModule(DefaultScalaModule)
val result = mapper.readValue(input, classOf[Foo])

// Good — centralise in a utility trait or object
object JsonSupport {
private val Mapper: ObjectMapper = {
val m = new ObjectMapper()
m.registerModule(DefaultScalaModule)
m
}

def parse[A: ClassTag](input: String)(implicit ct: ClassTag[A]): A =
Mapper.readValue(input, ct.runtimeClass.asInstanceOf[Class[A]])
}
```

### 9.4 Eliminate Redundant Wrapper Code

```scala
// Redundant — wrapping a single delegation
def getItems(): List[Item] = {
  val result = repository.findAll()
  result
}

// Clean
def getItems(): List[Item] = repository.findAll()
```

### 9.5 Default Parameters over Overloads

```scala
// Bad — 3 overloads
def connect(host: String): Connection = connect(host, 8080, 5000)
def connect(host: String, port: Int): Connection = connect(host, port, 5000)
def connect(host: String, port: Int, timeoutMs: Int): Connection = ...

// Good — single method with defaults
def connect(
host: String,
port: Int = 8080,
timeoutMs: Int = 5000
): Connection = ...
```

### 9.6 Type Aliases for Complex Signatures

```scala
// Before — repeated complex type
def process(input: Future[Either[AppError, RawData]]): Future[Either[AppError, ProcessedData]]
def validate(input: Future[Either[AppError, RawData]]): Future[Either[AppError, ValidData]]

// After
type ServiceResult[A] = Future[Either[AppError, A]]

def process(input: ServiceResult[RawData]): ServiceResult[ProcessedData]
def validate(input: ServiceResult[RawData]): ServiceResult[ValidData]
```

## 10. Extracting Common Behaviour

### 10.1 The Template Method via Abstract Classes

When multiple classes share structure but differ in specifics, extract a base:

```scala
abstract class BaseProcessor[I, O](implicit mfI: Manifest[I]) {

protected val logger: Logger = LoggerFactory.getLogger(getClass)

def name: String

def process(input: I): O

final def execute(raw: String): String = {
logger.info(s"[$name] Processing input")
val input  = deserialize[I](raw)
val output = process(input)
serialize(output)
}

protected def deserialize[A: Manifest](s: String): A = Serialization.read[A](s)
protected def serialize[A <: AnyRef](a: A): String = Serialization.write(a)
}
```

Mark the template method `final` to prevent accidental overrides.
Keep the abstract hooks (e.g., `process`) minimal and well-documented.

### 10.2 Traits for Cross-Cutting Concerns

```scala
trait Logging {
  protected lazy val logger: Logger = LoggerFactory.getLogger(getClass)
}

trait Timed { self: Logging =>
  def timed[A](label: String)(block: => A): A = {
    val start = System.nanoTime()
    val result = block
    val elapsed = (System.nanoTime() - start) / 1e6
    logger.debug(f"[$label] completed in $elapsed%.2f ms")
    result
  }
}

class OrderService extends Logging with Timed {
  def placeOrder(order: Order): Confirmation = timed("placeOrder") {
    // business logic
  }
}
```

Use self-type annotations (`self: Logging =>`) to express dependencies between traits.
Keep traits small and single-purpose.

### 10.3 Typeclass Pattern for Ad-Hoc Polymorphism

When you need the same behaviour across unrelated types without modifying them:

```scala
// 1. Define the typeclass
trait JsonEncoder[A] {
def encode(value: A): String
}

// 2. Provide instances in companions or an implicits object
object JsonEncoder {
implicit val stringEncoder: JsonEncoder[String] =
(value: String) => s""""$value""""

implicit val intEncoder: JsonEncoder[Int] =
(value: Int) => value.toString

implicit def listEncoder[A](implicit enc: JsonEncoder[A]): JsonEncoder[List[A]] =
(values: List[A]) => values.map(enc.encode).mkString("[", ",", "]")
}

// 3. Use via context bounds
def toJson[A: JsonEncoder](value: A): String =
implicitly[JsonEncoder[A]].encode(value)
```

Prefer typeclasses over inheritance when the abstraction crosses unrelated type hierarchies.
Keep instances in the companion object of the typeclass or the type for implicit resolution.

### 10.4 Higher-Order Functions to Remove Boilerplate

```scala
// Before — repeated resource management pattern
def readFile(path: String): String = {
  val source = Source.fromFile(path)
  try source.mkString
  finally source.close()
}

def readUrl(url: String): String = {
  val source = Source.fromURL(url)
  try source.mkString
  finally source.close()
}

// After — extracted common pattern
def withSource[A](source: => Source)(f: Source => A): A = {
  val s = source
  try f(s)
  finally s.close()
}

def readFile(path: String): String = withSource(Source.fromFile(path))(_.mkString)
def readUrl(url: String): String  = withSource(Source.fromURL(url))(_.mkString)
```

### 10.5 Cake Pattern vs. Constructor Injection

| Approach | When to Use |
| --- | --- |
| Constructor injection | Default choice; simple, testable, explicit |
| Cake pattern (self-types + traits) | Only when you need compile-time DI without a framework |
| Implicits / Reader monad | Functional codebases where DI is threaded through effects |

```scala
// Preferred — constructor injection
class UserService(repo: UserRepository, notifier: Notifier) {
def register(user: User): Either[AppError, User] = ...
}
```

### 10.6 Extraction Decision Flowchart

```
Is the code duplicated in ≥ 2 places?
├── No  → Leave it. Don't abstract speculatively.
└── Yes → Is the duplication structural (same shape, different types)?
    ├── Yes → Use generics / typeclasses / higher-order functions.
    └── No  → Is it the same business logic?
        ├── Yes → Extract into a shared method / service / trait.
        └── No  → It's incidental duplication. Leave it.
```

## 11. Concurrency

### 11.1 Future

```scala
import scala.concurrent.{Future, ExecutionContext}

def fetchUser(id: UserId)(implicit ec: ExecutionContext): Future[User] =
Future(blockingCall(id))
```

Always pass `ExecutionContext` as an implicit parameter.
Use `Future.successful` / `Future.failed` for already-known values (avoids scheduling overhead).
Combine with for-comprehensions for sequential composition.
Use `Future.sequence` / `Future.traverse` for parallel composition.

### 11.2 Blocking I/O

```scala
import scala.concurrent.blocking

Future {
  blocking {
    // JDBC call, file I/O, etc.
    heavyBlockingOperation()
  }
}
```

Wrap blocking I/O in `blocking { ... }` when using the default `ForkJoinPool`.
Better: use a dedicated fixed-thread-pool `ExecutionContext` for blocking work.

## 12. Documentation

### 12.1 Scaladoc

```scala
/**
 * Finds a user by their unique identifier.
 *
 * Performs a case-insensitive lookup in the primary data store.
 * Falls back to the cache if the primary store is unavailable.
 *
 * @param id the unique user identifier
 * @return the user if found, [[None]] otherwise
 * @throws DatabaseException if both primary and fallback fail
 */
def findById(id: UserId): Option[User]
```

All public API members must have Scaladoc.
First sentence = concise summary (displayed by IDEs).
Use `[[TypeName]]` for cross-references.

### 12.2 Inline Comments

```scala
// Retry up to 3 times because the downstream service is flaky under load
val result = retry(MaxRetries)(fetchData())
```

Explain **why**, not **what**.
Remove commented-out code — use version control instead.

## 13. Testing

### 13.1 Structure

```scala
import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.should.Matchers

class UserServiceSpec extends AnyFlatSpec with Matchers {

  "UserService.findById" should "return the user when it exists" in {
    // Arrange
    val repo = new InMemoryUserRepository(existingUser)
    val service = new UserService(repo)

    // Act
    val result = service.findById(existingUser.id)

    // Assert
    result shouldBe Some(existingUser)
  }

  it should "return None for an unknown id" in {
    val repo = new InMemoryUserRepository()
    val service = new UserService(repo)

    service.findById(UserId("unknown")) shouldBe None
  }
}
```

File naming: `*Spec.scala` or `*Test.scala`.
One logical assertion per test.
Tests read as specifications.

### 13.2 Test Doubles

Prefer hand-written fakes over mocking frameworks for clarity and type safety.
Use mocking libraries only for verifying interactions when fakes are impractical.

### 13.3 Performance Tests

Keep them in a separate source set or tag them (`@Slow`).
Use JMH for micro-benchmarks; integration tests for end-to-end latency.

## 14. Project Layout (Maven)

```
src/
├── main/
│   ├── scala/
│   │   └── com/acme/project/
│   │       ├── domain/          # Case classes, ADTs, value types
│   │       ├── service/         # Business logic
│   │       ├── repository/      # Data access traits & implementations
│   │       ├── api/             # HTTP / gRPC entry points
│   │       └── util/            # Shared utilities (JSON, logging, etc.)
│   └── resources/
│       └── application.yaml
└── test/
    ├── scala/
    │   └── com/acme/project/
    │       ├── service/         # Unit tests mirror main structure
    │       └── integration/     # Integration tests
    └── resources/
```

## 15. Anti-Patterns — Do Not

| ❌ Don't | ✅ Do Instead |
| --- | --- |
| `null` | `Option`, `Either` |
| `.get` on `Option` / `Try` | `getOrElse`, `fold`, pattern match |
| `return` keyword | Expression-oriented style |
| Wildcard imports in production | Explicit imports |
| `var` at class level | Immutable `val`s; `copy` on case classes |
| `Any` / `AnyRef` parameter types | Proper generics or ADTs |
| Deeply nested if/else | Pattern matching or `Either` chaining |
| `isInstanceOf` / `asInstanceOf` | Pattern matching |
| Mutable default collections | Immutable (default in 2.13) |
| `JavaConverters` (deprecated) | `scala.jdk.CollectionConverters` |
| Procedure syntax `def foo() { }` | `def foo(): Unit = { }` |
| `Manifest` | `ClassTag` / `TypeTag` |
| `Stream` (deprecated) | `LazyList` |
| Copy-pasting code blocks | Extract shared method / trait / typeclass |
| Premature micro-optimisation | Benchmark first, optimise where measured |
| God objects with 20+ methods | Split into focused, single-responsibility units |
| Over-abstraction with 4+ type params | Start concrete; generalise when needed |

## 16. Pre-Commit Checklist

Before finalising generated code, verify every item:

- [ ] All public members have explicit return types
- [ ] No `null`, `return`, `.get`, or `asInstanceOf`
- [ ] Imports grouped and ordered: Java → Scala → 3rd-party → project
- [ ] 2-space indentation, ≤ 120 columns
- [ ] Case classes are `final`; ADT roots are `sealed`
- [ ] `var` is used only in local scope with clear justification
- [ ] Error handling uses `Option` / `Either` / `Try` appropriately
- [ ] Scaladoc present on all public APIs
- [ ] No deprecated APIs (`JavaConverters`, `Stream`, `Manifest`, procedure syntax)
- [ ] No duplicated logic — common behaviour extracted into shared abstractions
- [ ] Generics use proper variance, bounds, and context bounds
- [ ] Performance-sensitive paths use appropriate collections and `.view` / `Iterator`
- [ ] Tail-recursive methods annotated with `@tailrec`
- [ ] Tests follow Arrange–Act–Assert and read as specifications
- [ ] No magic numbers or strings — use named constants

---

*Based on the Official Scala Style Guide, expanded with performance, generics, redundancy, and extraction best practices for Scala 2.13 production code.*