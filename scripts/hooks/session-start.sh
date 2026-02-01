#!/usr/bin/env bash
#
# STUDIO Session Start Hook
# ========================
#
# Initializes STUDIO session by:
# - Creating necessary directories on-demand
# - Checking for resumable casts
# - Loading Scribe rule counts
#
# Exit codes:
#   0 - Always approve (this is informational)
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
CASTS_DIR="${STUDIO_DIR}/casts"
RULES_DIR="${STUDIO_DIR}/rules"

# Create directories on-demand if they don't exist
ensure_directories() {
    # Only create if parent studio/ exists or if we're running from plugin
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        # We're running as a plugin - create directories on-demand
        mkdir -p "$CASTS_DIR" 2>/dev/null || true
        mkdir -p "$RULES_DIR" 2>/dev/null || true
    fi
}

# Check for resumable casts
find_resumable_casts() {
    local resumable=()

    if [[ -d "$CASTS_DIR" ]]; then
        for cast_dir in "$CASTS_DIR"/cast_*/; do
            if [[ -d "$cast_dir" ]]; then
                local state_file="${cast_dir}state.json"
                if [[ -f "$state_file" ]]; then
                    local status
                    status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

                    # Resumable if not complete/failed/aborted
                    case "$status" in
                        COMPLETE|FAILED|ABORTED) ;;
                        *)
                            local cast_id
                            cast_id=$(basename "$cast_dir")
                            resumable+=("$cast_id")
                            ;;
                    esac
                fi
            fi
        done
    fi

    # Output as JSON array
    if [[ ${#resumable[@]} -gt 0 ]]; then
        printf '['
        local first=true
        for cast in "${resumable[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                printf ','
            fi
            printf '"%s"' "$cast"
        done
        printf ']'
    else
        printf '[]'
    fi
}

# Count Scribe rules
count_rules() {
    local count=0

    if [[ -d "$RULES_DIR" ]]; then
        for rule_file in "$RULES_DIR"/*.md; do
            if [[ -f "$rule_file" ]]; then
                # Count non-empty lines starting with "- " (rules are bullet points)
                local file_count
                file_count=$(grep -c '^- ' "$rule_file" 2>/dev/null || echo 0)
                count=$((count + file_count))
            fi
        done
    fi

    echo "$count"
}

# Main
main() {
    ensure_directories

    local resumable
    resumable=$(find_resumable_casts)

    local rule_count
    rule_count=$(count_rules)

    local studio_available="true"
    if [[ ! -d "$STUDIO_DIR" ]] && [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        studio_available="false"
    fi

    # Output JSON response with additionalContext for Claude
    # Note: For SessionStart hooks, stdout becomes context for Claude
    cat <<EOF
{"additionalContext": "STUDIO session initialized. Available: ${studio_available}. Resumable casts: ${resumable}. Scribe rules loaded: ${rule_count}."}
EOF

    exit 0
}

main
