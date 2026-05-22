#!/usr/bin/env bash
# Structural lint for all SKILL.md files — no LLM, no cost, instant

set -euo pipefail

SKILLS_DIR="$(cd "$(dirname "$0")/../skills" && pwd)"
RESULTS_FILE="/tmp/skill-lint-results.md"
PASS=0
FAIL=0
OUTPUT=""

check() {
  local skill="$1"
  local desc="$2"
  local result="$3"  # "pass" or "fail"
  if [ "$result" = "pass" ]; then
    OUTPUT+="  ✅ $desc\n"
    PASS=$((PASS + 1))
  else
    OUTPUT+="  ❌ $desc\n"
    FAIL=$((FAIL + 1))
  fi
}

lint_skill() {
  local skill_dir="$1"
  local skill_name
  skill_name=$(basename "$skill_dir")
  local skill_file="$skill_dir/SKILL.md"
  local refs_dir="$skill_dir/references"

  OUTPUT+="\n### $skill_name\n"

  # 1. SKILL.md exists
  [ -f "$skill_file" ] && check "$skill_name" "SKILL.md exists" "pass" || { check "$skill_name" "SKILL.md exists" "fail"; return; }

  # 2. No ${SKILL_ROOT} placeholder
  if grep -q '\${SKILL_ROOT}' "$skill_file"; then
    check "$skill_name" "No \${SKILL_ROOT} placeholder" "fail"
  else
    check "$skill_name" "No \${SKILL_ROOT} placeholder" "pass"
  fi

  # 3. If <wrapper-path> used in snippets, instruction to replace it must exist
  if grep -q '<wrapper-path>' "$skill_file"; then
    if grep -q 'Replace all.*wrapper-path\|wrapper-path.*actual.*path' "$skill_file"; then
      check "$skill_name" "<wrapper-path> has replacement instruction" "pass"
    else
      check "$skill_name" "<wrapper-path> has replacement instruction" "fail"
    fi
  fi

  # 4. Step 0 Load Project Memory present
  if grep -q 'Load Project Memory' "$skill_file"; then
    check "$skill_name" "Step 0 — Load Project Memory present" "pass"
  else
    check "$skill_name" "Step 0 — Load Project Memory present" "fail"
  fi

  # 5. Save Project Memory present
  if grep -q 'Save Project Memory' "$skill_file"; then
    check "$skill_name" "Save Project Memory section present" "pass"
  else
    check "$skill_name" "Save Project Memory section present" "fail"
  fi

  # 6. .pulse/ gitignore instruction present
  if grep -q '\.pulse/' "$skill_file"; then
    check "$skill_name" ".pulse/ gitignore instruction present" "pass"
  else
    check "$skill_name" ".pulse/ gitignore instruction present" "fail"
  fi

  # 7. Upgrade flow present
  if grep -q 'npm show' "$skill_file"; then
    check "$skill_name" "Upgrade flow with version check present" "pass"
  else
    check "$skill_name" "Upgrade flow with version check present" "fail"
  fi

  # 8. Fallback chain present
  if grep -q 'Fallback chain' "$skill_file"; then
    check "$skill_name" "At least one fallback chain present" "pass"
  else
    check "$skill_name" "At least one fallback chain present" "fail"
  fi

  # 9. Troubleshooting section present
  if grep -q '## Troubleshooting' "$skill_file"; then
    check "$skill_name" "Troubleshooting section present" "pass"
  else
    check "$skill_name" "Troubleshooting section present" "fail"
  fi

  # 10. All ./references/*.md links resolve to real files
  if [ -d "$refs_dir" ]; then
    while IFS= read -r ref; do
      ref_file="$skill_dir/$ref"
      if [ -f "$ref_file" ]; then
        check "$skill_name" "Reference exists: $ref" "pass"
      else
        check "$skill_name" "Reference exists: $ref" "fail"
      fi
    done < <(grep -o '\./references/[a-z-]*\.md' "$skill_file" | sort -u)
  fi

  # 11. Frontmatter has name + description
  if grep -q '^name:' "$skill_file" && grep -q '^description:' "$skill_file"; then
    check "$skill_name" "Frontmatter has name + description" "pass"
  else
    check "$skill_name" "Frontmatter has name + description" "fail"
  fi
}

# Run lint on all skills with SKILL.md (skip setup router — minimal by design)
for dir in "$SKILLS_DIR"/*/; do
  skill_name=$(basename "$dir")
  [ "$skill_name" = "setup" ] && continue
  [ -f "$dir/SKILL.md" ] && lint_skill "$dir"
done

# Write results
{
  echo "## Skill Lint Results"
  echo ""
  echo "| | Count |"
  echo "|---|---|"
  echo "| ✅ Pass | $PASS |"
  echo "| ❌ Fail | $FAIL |"
  echo ""
  echo -e "$OUTPUT"
} > "$RESULTS_FILE"

cat "$RESULTS_FILE"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "❌ $FAIL check(s) failed. See above."
  exit 1
else
  echo ""
  echo "✅ All $PASS checks passed."
fi
