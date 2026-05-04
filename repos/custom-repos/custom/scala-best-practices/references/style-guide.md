# Official Scala Style Guide — Detailed Reference

Load this file when the task involves formatting, structuring, or reviewing the
style of Scala code. Based on the official guide at https://docs.scala-lang.org/style/.

---

## Indentation

- **2 spaces** per level — never tabs
- Continuation lines (line wrapping): align with the opening delimiter, or add
  4 spaces if no delimiter aligns cleanly

```scala
// Method with many arguments — align after opening paren
def myMethod(arg1: String,
             arg2: Int,
             arg3: Boolean): Unit = ???

// Or 4-space continuation if alignment is awkward
def myMethod(
    arg1: String,
    arg2: Int,
    arg3: Boolean): Unit = ???
```

### Line wrapping for method chains

Wrap before the `.` so each line starts with the operator:

```scala
// Good
val result = collection
  .filter(_.isValid)
  .map(_.transform)
  .toList

// Bad
val result = collection.filter(_.isValid).map(_.transform).toList // too long
```

---

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Class / Trait / Object | UpperCamelCase | `UserService`, `HttpClient` |
| Method / val / var | lowerCamelCase | `fetchUser`, `isValid` |
| Constants | UpperCamelCase | `MaxRetries`, `DefaultTimeout` |
| Package | lowercase, dot-separated | `com.example.users` |
| Type parameter (simple) | Single uppercase letter | `A`, `B`, `K`, `V` |
| Type parameter (descriptive) | UpperCamelCase | `Key`, `Value`, `Element` |
| Higher-kind type param | Prefix with `F` / `G` or descriptive | `F[_]`, `G[_, _]` |
| Annotations | UpperCamelCase | `@SerialVersionUID` |

### Methods: parentheses convention

- Methods with **no side effects**: omit parentheses
- Methods with **side effects**: include parentheses

```scala
// No side effect — query only
def length: Int = items.size

// Side effect — omit nothing
def clear(): Unit = items.clear()
```

### Accessors and mutators

Scala does not use JavaBean-style `getX`/`setX`:

```scala
// Bad (Java style)
def getName: String = _name
def setName(name: String): Unit = _name = name

// Good (Scala style)
def name: String = _name
def name_=(name: String): Unit = _name = name
```

### Symbolic method names

Use symbolic names only for mathematical or domain-specific operators that are
universally understood. Avoid arbitrary symbol operators in application code.

```scala
// OK — widely understood math operators
case class Vector2D(x: Double, y: Double) {
  def +(other: Vector2D): Vector2D = Vector2D(x + other.x, y + other.y)
}

// Bad — confusing arbitrary operators
class Processor {
  def >>(next: Processor): Processor = ???  // unclear intent
}
```

---

## Types

### Type inference

- Let the compiler infer local variable types when the type is obvious from context
- Always annotate **public method return types** (see rule 2.16)
- Annotate types when inference would produce a less useful or surprising type

```scala
// OK — inferred type is obvious
val name = "Alice"
val users = List(User("Alice"), User("Bob"))

// Required — public API
def findUser(id: Long): Option[User] = ???

// Required — inferred type would be ugly
def buildInstance(): MyInterface = new MyInterface { ... }
```

### Function types: prefer short form for arity-1

```scala
// Prefer
def process(f: Int => String): String = f(42)

// Over
def process(f: Function1[Int, String]): String = f(42)
```

### Structural types: avoid

Structural types (`{ def foo(): Unit }`) use reflection and are slow. Use
named traits or abstract classes instead.

---

## Declarations

### Class element ordering

Within a class or object, follow this order:

1. Fields (`val`, `var`)
2. Constructors (secondary constructors after primary)
3. Abstract methods
4. Concrete methods
5. Nested types (rarely — prefer top-level)

```scala
class UserService(repo: UserRepository)(implicit ec: ExecutionContext) {

  // 1. Fields
  private val cache = new ConcurrentHashMap[Long, User]()

  // 2. Public concrete methods
  def findById(id: Long): Future[Option[User]] = ???
  def save(user: User): Future[User] = ???

  // 3. Private helpers at the bottom
  private def validate(user: User): Either[String, User] = ???
}
```

### Method bodies

- Single-expression methods: use `=` without braces

```scala
def double(n: Int): Int = n * 2
```

- Multi-expression methods: use braces

```scala
def process(n: Int): Int = {
  val doubled = n * 2
  doubled + 1
}
```

### Method modifiers — ordering

`override protected abstract final def name`

```scala
override protected def fetchAll(): Future[List[T]] = ???
```

### Multiple parameter lists

Use multiple parameter lists for:
- Implicit/contextual parameters (always in the **last** group)
- Currying / partial application
- Type inference assistance

```scala
def foldLeft[A, B](as: List[A])(z: B)(f: (B, A) => B): B = ???

// Scala 2.12 / 2.13: `implicit` keyword
def log(message: String)(implicit logger: Logger): Unit = logger.info(message)

// Scala 3: `using` keyword replaces `implicit` for context parameters
def log(message: String)(using logger: Logger): Unit = logger.info(message)
```

### Function values / lambdas

- Use placeholder syntax `_` for simple single-use lambdas

```scala
list.map(_ * 2)
list.filter(_ > 0)
list.foreach(println)
```

- For multi-expression lambdas, use a named parameter and braces

```scala
list.map { item =>
  val processed = transform(item)
  validate(processed)
}
```

---

## Control Structures

### Curly braces: always use them for multi-line bodies

```scala
// Bad — relies on indentation
if (condition)
  doThis()
  doThat()  // NOT inside the if!

// Good
if (condition) {
  doThis()
  doThat()
}
```

Single-line `if`/`else` is OK without braces:

```scala
val label = if (n > 0) "positive" else "non-positive"
```

> **Scala 3**: optional significant indentation (Python-style) is available as an alternative to curly braces. In a codebase, choose one style and be consistent — do not mix brace and indentation syntax.

### Comprehensions: prefer `for` over nested `flatMap`

```scala
// Readable with for-comprehension
val result: Option[String] =
  for {
    user    <- findUser(id)
    profile <- findProfile(user.profileId)
  } yield profile.displayName

// Equivalent but less readable
findUser(id).flatMap(user => findProfile(user.profileId).map(_.displayName))
```

For multi-generator `for` comprehensions, always use braces and put each
generator on its own line.

### Pattern matching: one `case` per line

```scala
value match {
  case Some(n) if n > 0 => s"positive: $n"
  case Some(n)          => s"non-positive: $n"
  case None             => "empty"
}
```

---

## Method Invocation Style

### Arity-0: always use dot notation for non-operators

```scala
// Good
list.size
list.isEmpty

// Bad (postfix — requires `import scala.language.postfixOps` in Scala 2.12/2.13;
//      a compile error by default in Scala 3)
list size
```

### Arity-1: infix notation is OK only for operators and DSL methods

```scala
// Good — natural operator
1 + 2
list :+ element

// OK in DSL/test context
"foo" should equal ("foo")

// Bad in application code — confusing
user update newProfile
```

### Higher-order functions: always use dot notation

```scala
// Good
list.map(_.name)
list.filter(_.isActive)

// Bad (infix with lambda — confusing)
list map { _.name }
```

---

## Files

- One primary class/object per file; name the file after it
- Multiple closely related small classes/objects can share a file (e.g., ADT
  subtypes); in that case use lowercase first letter for the filename:
  `paymentStatus.scala` containing `Paid`, `Failed`, `Pending`
- Package structure **must match** directory structure (Java convention, enforced by scalac)

### Entry points

| Version | Idiomatic entry point |
|---------|----------------------|
| Scala 2.12 / 2.13 | `object Main { def main(args: Array[String]): Unit = ... }` |
| Scala 3 | `@main def run(): Unit = ...` (preferred) or `def main` also works |

`scala.App` works in all versions but is discouraged — see the `SKILL.md` Gotchas section.

---

## Scaladoc

### General style

- Use `/** ... */` for all public API documentation
- Start with a capital letter; end with a period
- Describe **what** the method does, not how

```scala
/**
 * Finds a user by their unique identifier.
 *
 * @param id the user's unique identifier
 * @return `Some(user)` if found, `None` if no user with that id exists
 */
def findById(id: Long): Future[Option[User]]
```

### Required Scaladoc tags

| Tag | When to use |
|-----|-------------|
| `@param` | Every parameter (for public methods) |
| `@return` | Non-`Unit` return values |
| `@throws` | If the method can throw (rare in idiomatic Scala) |
| `@tparam` | Type parameters on generic methods |
| `@see` | Related methods or external references |
| `@note` | Important caveats |
| `@example` | Usage examples for complex APIs |

### Classes and traits

- Document the class at the class level, not the constructor
- Describe what the class represents, its invariants, and any thread-safety properties

```scala
/**
 * Manages user sessions with automatic expiry.
 *
 * Thread-safe: all public methods may be called from multiple threads concurrently.
 *
 * @param ttl session time-to-live duration
 */
class SessionManager(ttl: FiniteDuration)(implicit clock: Clock) { ... }
```

### Packages

Add a `package.scala` with Scaladoc for the package when it has many public
types:

```scala
/**
 * Domain model for the users bounded context.
 *
 * Key types: [[User]], [[UserProfile]], [[UserRepository]]
 */
package object users
```

---

## Import Ordering

Group imports in this order, each group separated by a blank line:

1. Java standard library (`java.*`, `javax.*`)
2. Scala standard library (`scala.*`)
3. Third-party libraries (alphabetical within group)
4. Internal / project imports

```scala
import java.time.Instant
import java.util.UUID

import scala.concurrent.{ExecutionContext, Future}
import scala.util.control.NonFatal

import cats.data.EitherT
import io.circe.syntax._

import com.example.users.{User, UserRepository}
import com.example.common.Logging
```

Avoid wildcard imports (`import foo._`) in production code; they make it hard
to trace where names come from. Exceptions: `scala.language._` pragmas and
well-known DSLs (Akka HTTP routing DSL, ScalaTest matchers).
