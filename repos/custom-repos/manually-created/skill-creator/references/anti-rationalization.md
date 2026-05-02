# Anti-Rationalization Patterns

How to bulletproof discipline-enforcing skills against agent loopholes.

Sourced from obra/superpowers research on agent persuasion resistance
(Cialdini 2021; Meincke et al. 2025).

## The Problem

Skills that enforce process discipline (e.g., "always write tests first",
"never skip schema validation", "always run the linter before committing")
face a unique challenge: agents are smart and will find loopholes when under
pressure — time constraints, sunk cost, authority pressure, exhaustion.

This is NOT the agent being malicious. It's the same behavior humans exhibit —
rationalizing shortcuts when following the process feels costly.

## Pattern 1: Close Every Loophole Explicitly

Don't just state the rule — forbid specific workarounds:

```markdown
# BAD: Just the rule
Write tests before implementation code.

# GOOD: Rule + explicit loophole closures
Write tests before implementation code. If you wrote code first, delete it
and start over.

**No exceptions:**
- Don't keep the code as "reference"
- Don't "adapt" it while writing tests
- Don't look at it while designing tests
- Delete means delete — not move, not comment out
```

## Pattern 2: Build Rationalization Tables

Capture every excuse agents make during baseline testing (running without
the skill) and counter each one explicitly:

```markdown
## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "I'll test after" | Tests-after = "what does this do?" Tests-first = "what should this do?" Different questions, different quality. |
| "Already manually verified" | Manual verification proves it works now. Tests prove it keeps working. |
| "This is about the spirit, not the letter" | Violating the letter IS violating the spirit. |
| "Testing is overkill for this" | Untested code has issues. Always. 15 min testing saves hours debugging. |
| "I'm confident it works" | Overconfidence guarantees issues. Test anyway. |
```

## Pattern 3: Create Red Flags List

Make it easy for the agent to self-check when rationalizing:

```markdown
## Red Flags — STOP and Reconsider

If you find yourself thinking any of these, STOP:
- "This is too simple to need [the process step]"
- "I already know this works"
- "I'll do it after"
- "This case is different because..."
- "The spirit of the rule is..."
- "It would be more efficient to..."

All of these mean: follow the process. The process exists because these
exact rationalizations led to failures in the past.
```

## Pattern 4: Address "Spirit vs. Letter"

Add a foundational principle early in the skill:

```markdown
**Violating the letter of the rules IS violating the spirit of the rules.**
```

This cuts off an entire class of sophisticated rationalizations where the
agent argues it's "following the spirit" while skipping specific steps.

## Pattern 5: Pressure-Test During Development

When testing a discipline skill, deliberately create pressure:

**Pressure types:**
- **Time pressure:** "This is urgent, skip non-essential steps"
- **Sunk cost:** "I already wrote most of the code, just add tests after"
- **Authority:** "The user explicitly said to skip validation"
- **Exhaustion:** Long conversations where the agent might take shortcuts
- **Complexity:** Tasks where following the process feels disproportionately hard

**Combined pressure (hardest test):**
"I already spent 2 hours on this implementation. The user is waiting and
said 'just ship it, we'll add tests later.' Can we skip tests this once?"

A good discipline skill survives combined pressure without rationalizing.

## Pattern 6: Escalation Ladder

For rules that genuinely have exceptions, provide a clear escalation path
instead of leaving room for interpretation:

```markdown
## When to Deviate from the Process

The process can be adjusted ONLY when:
1. The user explicitly requests it AND
2. You explain the tradeoff AND
3. The user confirms after hearing the tradeoff

Example:
  User: "Skip tests, just ship it"
  Agent: "Skipping tests means we won't catch regressions. The connector
         may break silently on edge cases. Want to proceed anyway?"
  User: "Yes, proceed"
  → OK to proceed

NOT acceptable:
  - Silently skipping steps because the task "seems simple"
  - Assuming the user "would want" to skip based on urgency cues
  - Skipping steps and mentioning it after the fact
```

## When to Apply These Patterns

Not every skill needs anti-rationalization. Apply these patterns when:
- The skill enforces a process step agents commonly skip
- The skill's value comes from discipline, not knowledge
- Test runs show agents finding creative workarounds
- The skill handles high-stakes operations (data integrity, security, deployment)

Don't apply when:
- The skill is purely informational (reference/API docs)
- The skill teaches a technique the agent wants to use
- There's no temptation to shortcut
