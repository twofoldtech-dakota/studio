#!/usr/bin/env bash
#
# STUDIO Error Classifier Hook
# ============================
#
# Classifies errors and provides contextual, actionable messages.
# Called by PostToolUseFailure hook.
#
# Input: JSON with tool_name, error, stderr, stdout
# Output: JSON with additionalContext for Claude
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_ROOT="${SCRIPT_DIR}/../.."
PATTERNS_FILE="${STUDIO_ROOT}/data/error-patterns.json"
OUTPUT_SCRIPT="${SCRIPT_DIR}/../output.sh"

# Read hook input from stdin
INPUT=$(cat)

# Extract error information
ERROR_MSG=$(echo "$INPUT" | jq -r '.error // .stderr // .stdout // ""' 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null)

# Exit silently if no error message
if [[ -z "$ERROR_MSG" ]] || [[ "$ERROR_MSG" == "null" ]]; then
    exit 0
fi

# Check if patterns file exists
if [[ ! -f "$PATTERNS_FILE" ]]; then
    echo '{"additionalContext": "Error patterns file not found. Cannot classify error."}' >&2
    exit 0
fi

# Function to escape string for JSON
json_escape() {
    printf '%s' "$1" | jq -Rs .
}

# Function to substitute capture groups in fix messages
substitute_captures() {
    local template="$1"
    shift
    local result="$template"
    local i=1
    for capture in "$@"; do
        result="${result//\$$i/$capture}"
        ((i++))
    done
    echo "$result"
}

# Try to match error against patterns
match_error() {
    local error="$1"

    # Get patterns array
    local patterns
    patterns=$(jq -r '.patterns' "$PATTERNS_FILE")
    local num_patterns
    num_patterns=$(echo "$patterns" | jq 'length')

    for ((i=0; i<num_patterns; i++)); do
        local pattern
        pattern=$(echo "$patterns" | jq -r ".[$i]")

        local match_regex
        match_regex=$(echo "$pattern" | jq -r '.match')

        # Try to match (using grep with PCRE if available, otherwise ERE)
        local captures
        if captures=$(echo "$error" | grep -oP "$match_regex" 2>/dev/null | head -1); then
            # Extract capture groups
            local capture1 capture2 capture3
            capture1=$(echo "$error" | sed -nE "s/.*${match_regex}.*/\1/p" 2>/dev/null | head -1)
            capture2=$(echo "$error" | sed -nE "s/.*${match_regex}.*/\2/p" 2>/dev/null | head -1)
            capture3=$(echo "$error" | sed -nE "s/.*${match_regex}.*/\3/p" 2>/dev/null | head -1)

            local error_type why auto_fix
            error_type=$(echo "$pattern" | jq -r '.type')
            why=$(echo "$pattern" | jq -r '.why')
            auto_fix=$(echo "$pattern" | jq -r '.auto_fix // empty')

            # Substitute captures in messages
            why="${why//\$1/$capture1}"
            why="${why//\$2/$capture2}"
            why="${why//\$3/$capture3}"

            if [[ -n "$auto_fix" ]]; then
                auto_fix="${auto_fix//\$1/$capture1}"
                auto_fix="${auto_fix//\$2/$capture2}"
                auto_fix="${auto_fix//\$3/$capture3}"
            fi

            # Get fix array as newline-separated list
            local fix_list
            fix_list=$(echo "$pattern" | jq -r '.fix[]' | while read -r line; do
                line="${line//\$1/$capture1}"
                line="${line//\$2/$capture2}"
                line="${line//\$3/$capture3}"
                echo "  - $line"
            done)

            # Output structured response
            cat <<EOF
{
  "matched": true,
  "error_type": $(json_escape "$error_type"),
  "why": $(json_escape "$why"),
  "fix": $(json_escape "$fix_list"),
  "auto_fix": $(json_escape "${auto_fix:-}"),
  "category": $(echo "$pattern" | jq '.category'),
  "additionalContext": "ERROR CLASSIFIED

Type: $error_type
Tool: $TOOL_NAME

Why: $why

How to fix:
$fix_list
$(if [[ -n "$auto_fix" ]]; then echo "
Auto-fix available: $auto_fix
Ask the user if they want to run the auto-fix command."; fi)"
}
EOF
            return 0
        fi
    done

    # No match found
    cat <<EOF
{
  "matched": false,
  "additionalContext": "Error occurred in $TOOL_NAME but could not be automatically classified.

Raw error:
$error

Analyze this error and provide actionable suggestions to the user."
}
EOF
}

# Main
RESULT=$(match_error "$ERROR_MSG")

# Output the result
echo "$RESULT"

# Also display visual error box if we have a match and output.sh exists
if [[ -x "$OUTPUT_SCRIPT" ]]; then
    matched=$(echo "$RESULT" | jq -r '.matched // false')
    if [[ "$matched" == "true" ]]; then
        error_type=$(echo "$RESULT" | jq -r '.error_type')
        why=$(echo "$RESULT" | jq -r '.why')
        fix=$(echo "$RESULT" | jq -r '.fix')
        auto_fix=$(echo "$RESULT" | jq -r '.auto_fix // empty')

        "$OUTPUT_SCRIPT" error_box "$error_type" "$why" "$fix" "$auto_fix" >&2
    fi
fi

exit 0
