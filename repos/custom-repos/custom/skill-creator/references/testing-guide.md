# Testing Guide Reference

How to test skills and iterate on improvements.

## Test Case Design

### Writing Test Prompts

Create 2-3 realistic test prompts — what a real user would actually say.
Not abstract requests, but concrete, specific prompts with detail:

```json
{
  "skill_name": "create-connector",
  "evals": [
    {
      "id": 1,
      "prompt": "I need to build a REST API connector to pull customer data from Salesforce. We use OAuth2 and need to map their Contact object to our internal customer schema. The API has rate limits of 100 req/min.",
      "expected_output": "Connector with OAuth2 auth, field mapping config, rate limiter",
      "files": []
    },
    {
      "id": 2,
      "prompt": "set up a db connector for our postgres warehouse, it has 3 tables - users, orders, products. need incremental sync based on updated_at column",
      "expected_output": "DB connector with incremental sync logic, schema for 3 tables",
      "files": []
    }
  ]
}
```

**Good test prompts:**
- Have file paths, personal context, specifics (column names, URLs, company names)
- Mix of lengths — some verbose, some terse
- Some lowercase, abbreviations, typos, casual speech
- Cover different use cases the skill handles
- Include edge cases, not just happy paths

**Bad test prompts:**
- "Create a connector" (too vague)
- "Build an integration" (no specifics)
- Generic requests that any agent could handle without the skill

### Trigger Testing

For testing whether the description triggers correctly:

**Should-trigger queries (8-10):**
- Different phrasings of the same intent
- Cases where the user doesn't name the skill but clearly needs it
- Uncommon use cases the skill should handle
- Cases that compete with other skills but this one should win

**Should-not-trigger queries (8-10):**
- Near-misses: share keywords but need something different
- Adjacent domains with ambiguous phrasing
- Queries that touch on the skill's domain but in the wrong context

The most valuable negative tests are near-misses, not obviously irrelevant
queries. "Write a fibonacci function" as a negative test for a connector
skill teaches nothing.

## Testing Methodology

### With Subagents (Claude Code, etc.)

If your platform supports subagents, run tests in parallel:

1. **With-skill run:** Give the subagent the skill + test prompt, save outputs
2. **Baseline run:** Same prompt, no skill, save outputs
3. Compare results side-by-side

Launch with-skill and baseline runs simultaneously (don't batch).

### Without Subagents (Copilot, Claude.ai, etc.)

Run tests sequentially:
1. Read the skill's SKILL.md
2. Follow its instructions to complete each test prompt
3. Present results to the user inline
4. Skip baseline runs — focus on qualitative feedback

### Inline Testing (Simplest)

For quick validation:
1. Share the test prompt with the AI agent
2. Watch how it uses (or doesn't use) the skill
3. Note what went wrong or what was missing
4. Iterate immediately

## Assertion Design

Draft assertions while tests are running. Good assertions are:
- **Objectively verifiable** — can be checked by script or clear criteria
- **Descriptively named** — someone reading results immediately understands them
- **Non-trivial** — would fail WITHOUT the skill (discriminating)

```json
{
  "assertions": [
    {
      "name": "auth-config-present",
      "check": "Output contains authentication configuration file",
      "type": "file_exists"
    },
    {
      "name": "rate-limiter-configured",
      "check": "Rate limiting is configured with the specified limit",
      "type": "content_check"
    },
    {
      "name": "schema-mapping-complete",
      "check": "All source fields are mapped to target fields",
      "type": "content_check"
    }
  ]
}
```

**Skip assertions for subjective skills** (writing style, design quality) —
use human judgment instead.

## Grading

After runs complete:

1. **Check each assertion** against the outputs
   - For scriptable checks, write and run a script (faster, reusable)
   - For judgment calls, evaluate inline
2. **Record results:**
```json
{
  "eval_id": 1,
  "assertions": [
    {"name": "auth-config-present", "passed": true, "evidence": "Found oauth2.config.json"},
    {"name": "rate-limiter-configured", "passed": false, "evidence": "No rate limiting in output"}
  ]
}
```

## Improvement Philosophy

After reviewing results:

1. **Generalize from feedback.** The skill will be used across many different
   prompts. Don't overfit to the test cases. Rather than fiddly, specific fixes,
   try different metaphors or recommend different patterns.

2. **Keep the skill lean.** Remove instructions that don't pull their weight.
   Read the test transcripts — if the skill makes the agent waste time on
   unproductive steps, remove those parts.

3. **Explain the why.** Transmit understanding, not just rules. If you find
   yourself writing ALWAYS or NEVER in caps, reframe as reasoning.

4. **Look for repeated work.** If all test runs independently wrote the same
   helper script, bundle it in `scripts/`. Save every future invocation from
   reinventing the wheel.

5. **Write a draft, then improve.** Don't ship the first version. Write it,
   look at it fresh, then refine.

## The Iteration Loop

1. Apply improvements to the skill
2. Rerun all test cases
3. Review new results with the user
4. Repeat until:
   - The user says they're happy
   - All feedback is empty (everything looks good)
   - No meaningful progress is being made

Keep test results organized:
```
skill-name-workspace/
├── iteration-1/
│   ├── eval-1/
│   │   ├── with_skill/outputs/
│   │   └── without_skill/outputs/
│   └── eval-2/
│       └── ...
├── iteration-2/
│   └── ...
└── evals.json
```

## Testing Different Skill Types

| Skill Type | What to Test | Success Criteria |
|------------|-------------|-----------------|
| **Discipline-enforcing** (TDD, validation) | Pressure scenarios, combined stresses | Agent follows rule under maximum pressure |
| **Technique** (how-to guides) | Application + edge cases + missing info | Agent successfully applies technique to new scenarios |
| **Pattern** (mental models) | Recognition + application + counter-examples | Agent correctly identifies when/how to apply |
| **Reference** (docs/APIs) | Retrieval + application + gap testing | Agent finds and correctly uses reference info |
| **Orchestrator** (routes to sub-skills) | All paths + path selection accuracy | Agent picks correct sub-skill for each scenario |
