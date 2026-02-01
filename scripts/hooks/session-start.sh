#!/usr/bin/env bash
#
# STUDIO Session Start Hook
# ========================
#
# Initializes STUDIO session by:
# - Creating necessary directories on-demand
# - Checking for resumable tasks
# - Loading Memory rule counts
#
# Exit codes:
#   0 - Always approve (this is informational)
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
TASKS_DIR="${STUDIO_DIR}/tasks"
RULES_DIR="${STUDIO_DIR}/rules"

# Create directories on-demand if they don't exist
ensure_directories() {
    # Only create if parent studio/ exists or if we're running from plugin
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        # We're running as a plugin - create directories on-demand
        mkdir -p "$TASKS_DIR" 2>/dev/null || true
        mkdir -p "$RULES_DIR" 2>/dev/null || true
    fi
}

# Check for resumable tasks
find_resumable_tasks() {
    local resumable=()

    if [[ -d "$TASKS_DIR" ]]; then
        for task_dir in "$TASKS_DIR"/task_*/; do
            if [[ -d "$task_dir" ]]; then
                local state_file="${task_dir}state.json"
                if [[ -f "$state_file" ]]; then
                    local status
                    status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

                    # Resumable if not complete/failed/aborted
                    case "$status" in
                        COMPLETE|FAILED|ABORTED) ;;
                        *)
                            local task_id
                            task_id=$(basename "$task_dir")
                            resumable+=("$task_id")
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
        for task in "${resumable[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                printf ','
            fi
            printf '"%s"' "$task"
        done
        printf ']'
    else
        printf '[]'
    fi
}

# Count Memory rules
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
    resumable=$(find_resumable_tasks)

    local rule_count
    rule_count=$(count_rules)

    local studio_available="true"
    if [[ ! -d "$STUDIO_DIR" ]] && [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        studio_available="false"
    fi

    # Output JSON response with additionalContext for Claude
    # Note: For SessionStart hooks, stdout becomes context for Claude
    cat <<EOF
{"additionalContext": "STUDIO session initialized. Available: ${studio_available}. Resumable tasks: ${resumable}. Memory rules loaded: ${rule_count}."}
EOF

    exit 0
}

main
