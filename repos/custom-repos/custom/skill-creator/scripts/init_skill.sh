#!/usr/bin/env bash
# init_skill.sh — Scaffold a new skill directory with template files
# Usage: ./init_skill.sh <skill-name> [output-directory]
#
# Example:
#   ./init_skill.sh create-connector ./my-skills
#   ./init_skill.sh validate-schema  (creates in current directory)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <skill-name> [output-directory]"
  echo ""
  echo "Arguments:"
  echo "  skill-name       Lowercase, hyphens only (e.g., create-connector)"
  echo "  output-directory Where to create the skill (default: current directory)"
  exit 1
fi

SKILL_NAME="$1"
OUTPUT_DIR="${2:-.}"

# Validate skill name
if [[ ! "$SKILL_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "ERROR: Skill name must be lowercase letters, digits, and hyphens only."
  echo "       Must start and end with a letter or digit."
  echo "       Got: '$SKILL_NAME'"
  exit 1
fi

if [[ ${#SKILL_NAME} -gt 64 ]]; then
  echo "ERROR: Skill name must be under 64 characters. Got: ${#SKILL_NAME}"
  exit 1
fi

SKILL_DIR="$OUTPUT_DIR/$SKILL_NAME"

if [[ -d "$SKILL_DIR" ]]; then
  echo "ERROR: Directory already exists: $SKILL_DIR"
  echo "       Delete it first or choose a different name."
  exit 1
fi

echo "Creating skill: $SKILL_NAME"
echo "Location: $SKILL_DIR"
echo ""

# Create directory structure
mkdir -p "$SKILL_DIR"/{scripts,references,assets}

# Create SKILL.md template
cat > "$SKILL_DIR/SKILL.md" << 'TEMPLATE_END'
---
name: SKILL_NAME_PLACEHOLDER
description: >
  TODO: Describe what this skill does and when to use it.
  Include specific triggering conditions — phrases, file types, task types.
  Be slightly pushy — agents under-trigger by default.
  Do NOT summarize the workflow here, only describe WHEN to trigger.
---

# SKILL_NAME_PLACEHOLDER

TODO: Brief overview — what this skill does, core principle in 1-2 sentences.

## Process

TODO: Step-by-step instructions in imperative form.
Explain the WHY behind each step, not just the WHAT.

1. First step
2. Second step
3. Third step

## Output Format

TODO: Define explicit templates if consistency matters.

## Common Mistakes

TODO: What goes wrong + fixes.

## References

- `references/` — TODO: List reference files with guidance on when to read each

## Scripts

- `scripts/` — TODO: List bundled scripts with usage instructions
TEMPLATE_END

# Replace placeholder with actual skill name
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s/SKILL_NAME_PLACEHOLDER/$SKILL_NAME/g" "$SKILL_DIR/SKILL.md"
else
  sed -i "s/SKILL_NAME_PLACEHOLDER/$SKILL_NAME/g" "$SKILL_DIR/SKILL.md"
fi

# Create placeholder reference
cat > "$SKILL_DIR/references/.gitkeep" << 'EOF'
EOF

# Create placeholder script
cat > "$SKILL_DIR/scripts/.gitkeep" << 'EOF'
EOF

# Create placeholder asset
cat > "$SKILL_DIR/assets/.gitkeep" << 'EOF'
EOF

echo "Skill scaffolded successfully!"
echo ""
echo "Structure:"
find "$SKILL_DIR" -type f | sort | while read -r f; do
  echo "  $f"
done
echo ""
echo "Next steps:"
echo "  1. Edit $SKILL_DIR/SKILL.md — fill in the TODOs"
echo "  2. Add reference files to $SKILL_DIR/references/"
echo "  3. Add scripts to $SKILL_DIR/scripts/"
echo "  4. Run validate_skill.sh to check before deploying"
