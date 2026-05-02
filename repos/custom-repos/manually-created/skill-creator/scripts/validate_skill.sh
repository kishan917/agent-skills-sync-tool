#!/usr/bin/env bash
# validate_skill.sh — Validate skill structure, frontmatter, and naming
# Usage: ./validate_skill.sh <path-to-skill-folder>
#
# Checks:
#   - SKILL.md exists
#   - YAML frontmatter has name and description
#   - Name matches directory name
#   - Name follows naming rules (lowercase, hyphens, <64 chars)
#   - Description is not a TODO placeholder
#   - SKILL.md body is under 500 lines
#   - No extraneous documentation files
#   - Referenced files exist

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-skill-folder>"
  exit 1
fi

SKILL_DIR="$1"
ERRORS=0
WARNINGS=0

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; ERRORS=$((ERRORS + 1)); }
warn() { echo "  ⚠ $1"; WARNINGS=$((WARNINGS + 1)); }

echo "Validating skill: $SKILL_DIR"
echo ""

# --- Check SKILL.md exists ---
if [[ ! -f "$SKILL_DIR/SKILL.md" ]]; then
  fail "SKILL.md not found in $SKILL_DIR"
  echo ""
  echo "Result: FAILED ($ERRORS errors)"
  exit 1
fi
pass "SKILL.md exists"

# --- Extract frontmatter ---
SKILL_FILE="$SKILL_DIR/SKILL.md"

# Check for frontmatter delimiters
FIRST_LINE=$(head -1 "$SKILL_FILE")
if [[ "$FIRST_LINE" != "---" ]]; then
  fail "SKILL.md must start with YAML frontmatter (---)"
  echo ""
  echo "Result: FAILED ($ERRORS errors)"
  exit 1
fi
pass "Frontmatter delimiter found"

# Extract frontmatter content (between first and second ---)
FRONTMATTER=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$SKILL_FILE")

# --- Check name field ---
SKILL_NAME=$(echo "$FRONTMATTER" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')
if [[ -z "$SKILL_NAME" ]]; then
  fail "Missing 'name' field in frontmatter"
else
  pass "name field present: $SKILL_NAME"

  # Check name format
  if [[ ! "$SKILL_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    fail "Name must be lowercase letters, digits, and hyphens only: '$SKILL_NAME'"
  else
    pass "Name format valid"
  fi

  # Check name length
  if [[ ${#SKILL_NAME} -gt 64 ]]; then
    fail "Name must be under 64 characters (got ${#SKILL_NAME})"
  else
    pass "Name length OK (${#SKILL_NAME} chars)"
  fi

  # Check name matches directory
  DIR_NAME=$(basename "$SKILL_DIR")
  if [[ "$SKILL_NAME" != "$DIR_NAME" ]]; then
    warn "Name '$SKILL_NAME' doesn't match directory name '$DIR_NAME'"
  else
    pass "Name matches directory"
  fi
fi

# --- Check description field ---
DESC=$(echo "$FRONTMATTER" | grep -E '^description:' | head -1 | sed 's/^description:[[:space:]]*//')
if [[ -z "$DESC" ]]; then
  # Check for multi-line description (using > or |)
  DESC_MARKER=$(echo "$FRONTMATTER" | grep -E '^description:' | head -1)
  if [[ -z "$DESC_MARKER" ]]; then
    fail "Missing 'description' field in frontmatter"
  else
    pass "description field present (multi-line)"
  fi
else
  pass "description field present"
fi

# Check for TODO in description
if echo "$FRONTMATTER" | grep -qi "TODO"; then
  fail "Frontmatter contains TODO placeholder — fill in real values"
fi

# --- Check for extraneous fields ---
EXTRA_FIELDS=$(echo "$FRONTMATTER" | grep -E '^[a-z_-]+:' | grep -vE '^(name|description|metadata):' | sed 's/:.*//' || true)
if [[ -n "$EXTRA_FIELDS" ]]; then
  warn "Non-standard frontmatter fields: $EXTRA_FIELDS (only name and description are universal)"
fi

# --- Check body length ---
BODY_START=$(awk '/^---$/{n++} n==2{print NR; exit}' "$SKILL_FILE")
if [[ -n "$BODY_START" ]]; then
  TOTAL_LINES=$(wc -l < "$SKILL_FILE")
  BODY_LINES=$((TOTAL_LINES - BODY_START))

  if [[ $BODY_LINES -gt 500 ]]; then
    warn "SKILL.md body is $BODY_LINES lines (target: under 500). Consider splitting into reference files."
  else
    pass "Body length OK ($BODY_LINES lines)"
  fi
fi

# --- Check for extraneous docs ---
BANNED_FILES=("README.md" "INSTALLATION_GUIDE.md" "CHANGELOG.md" "QUICK_REFERENCE.md" "SETUP.md")
for f in "${BANNED_FILES[@]}"; do
  if [[ -f "$SKILL_DIR/$f" ]]; then
    warn "Found $f — skills should not contain auxiliary documentation files"
  fi
done

# --- Check referenced files exist ---
REFS=$(grep -oE 'references/[a-zA-Z0-9_./-]+' "$SKILL_FILE" 2>/dev/null || true)
for ref in $REFS; do
  if [[ ! -f "$SKILL_DIR/$ref" ]]; then
    warn "Referenced file not found: $ref"
  fi
done

SCRIPTS=$(grep -oE 'scripts/[a-zA-Z0-9_./-]+' "$SKILL_FILE" 2>/dev/null || true)
for script in $SCRIPTS; do
  if [[ ! -f "$SKILL_DIR/$script" ]]; then
    warn "Referenced script not found: $script"
  fi
done

# --- Summary ---
echo ""
if [[ $ERRORS -gt 0 ]]; then
  echo "Result: FAILED ($ERRORS errors, $WARNINGS warnings)"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo "Result: PASSED with $WARNINGS warnings"
  exit 0
else
  echo "Result: PASSED — skill looks good!"
  exit 0
fi
