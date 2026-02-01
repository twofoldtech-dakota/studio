#!/usr/bin/env bash
#
# STUDIO Session Start Hook
# ========================
#
# Initializes STUDIO session by:
# - Creating necessary directories on-demand
# - Checking for resumable tasks with detailed info
# - Displaying auto-resume prompt for incomplete builds
# - Loading Memory rule counts
#
# Exit codes:
#   0 - Always approve (this is informational)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-studio}"
TASKS_DIR="${STUDIO_DIR}/tasks"
PROJECTS_DIR="${STUDIO_DIR}/projects"
RULES_DIR="${STUDIO_DIR}/rules"
MEMORY_DIR="${STUDIO_DIR}/memory"
OUTPUT_SCRIPT="${SCRIPT_DIR}/../output.sh"

# Create directories on-demand if they don't exist
ensure_directories() {
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        mkdir -p "$TASKS_DIR" 2>/dev/null || true
        mkdir -p "$PROJECTS_DIR" 2>/dev/null || true
        mkdir -p "$RULES_DIR" 2>/dev/null || true
        mkdir -p "$MEMORY_DIR" 2>/dev/null || true
    fi
}

# Calculate time ago string
time_ago() {
    local timestamp="$1"
    local now=$(date +%s)
    local then

    # Try to parse the timestamp
    if then=$(date -d "$timestamp" +%s 2>/dev/null); then
        :
    elif then=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp%.*}" +%s 2>/dev/null); then
        :
    else
        echo "unknown"
        return
    fi

    local diff=$((now - then))
    local minutes=$((diff / 60))
    local hours=$((diff / 3600))
    local days=$((diff / 86400))

    if [[ $days -gt 0 ]]; then
        echo "${days} day(s) ago"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours} hour(s) ago"
    elif [[ $minutes -gt 0 ]]; then
        echo "${minutes} minute(s) ago"
    else
        echo "just now"
    fi
}

# Find incomplete tasks with detailed information
find_incomplete_tasks() {
    local tasks=()

    # Check projects directory first (new structure)
    if [[ -d "$PROJECTS_DIR" ]]; then
        for manifest in "$PROJECTS_DIR"/*/tasks/*/manifest.json; do
            if [[ -f "$manifest" ]]; then
                local status
                status=$(jq -r '.status // "unknown"' "$manifest" 2>/dev/null)

                # Skip completed/failed/aborted
                case "$status" in
                    COMPLETE|FAILED|ABORTED|complete|failed|aborted) continue ;;
                esac

                local task_id goal step total updated
                task_id=$(jq -r '.id // "unknown"' "$manifest" 2>/dev/null)
                goal=$(jq -r '.goal // "Unknown goal"' "$manifest" 2>/dev/null)
                step=$(jq -r '.progress.current_step // .current_step // 0' "$manifest" 2>/dev/null)
                total=$(jq -r '.progress.total_steps // (.steps | length) // "?"' "$manifest" 2>/dev/null)
                updated=$(jq -r '.updated_at // ""' "$manifest" 2>/dev/null)

                local last_activity="unknown"
                if [[ -n "$updated" ]] && [[ "$updated" != "null" ]]; then
                    last_activity=$(time_ago "$updated")
                fi

                tasks+=("{\"id\":\"$task_id\",\"goal\":\"${goal:0:50}\",\"status\":\"$status\",\"step\":\"$step\",\"total\":\"$total\",\"last_activity\":\"$last_activity\",\"manifest\":\"$manifest\"}")
            fi
        done
    fi

    # Also check legacy tasks directory
    if [[ -d "$TASKS_DIR" ]]; then
        for task_dir in "$TASKS_DIR"/task_*/; do
            if [[ -d "$task_dir" ]]; then
                local state_file="${task_dir}state.json"
                if [[ -f "$state_file" ]]; then
                    local status
                    status=$(jq -r '.status // "unknown"' "$state_file" 2>/dev/null)

                    case "$status" in
                        COMPLETE|FAILED|ABORTED|complete|failed|aborted) continue ;;
                    esac

                    local task_id goal step total updated
                    task_id=$(jq -r '.id // "unknown"' "$state_file" 2>/dev/null)
                    goal=$(jq -r '.goal // "Unknown goal"' "$state_file" 2>/dev/null)
                    step=$(jq -r '.current_step // 0' "$state_file" 2>/dev/null)
                    total=$(jq -r '.completed_steps | length' "$state_file" 2>/dev/null)
                    updated=$(jq -r '.updated_at // ""' "$state_file" 2>/dev/null)

                    local last_activity="unknown"
                    if [[ -n "$updated" ]] && [[ "$updated" != "null" ]]; then
                        last_activity=$(time_ago "$updated")
                    fi

                    tasks+=("{\"id\":\"$task_id\",\"goal\":\"${goal:0:50}\",\"status\":\"$status\",\"step\":\"$step\",\"total\":\"$total\",\"last_activity\":\"$last_activity\"}")
                fi
            fi
        done
    fi

    # Output as JSON array
    if [[ ${#tasks[@]} -gt 0 ]]; then
        printf '['
        local first=true
        for task in "${tasks[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                printf ','
            fi
            printf '%s' "$task"
        done
        printf ']'
    else
        printf '[]'
    fi
}

# Count Memory rules
count_rules() {
    local count=0

    # Check new memory directory
    if [[ -d "$MEMORY_DIR" ]]; then
        for rule_file in "$MEMORY_DIR"/*.md; do
            if [[ -f "$rule_file" ]]; then
                local file_count
                file_count=$(grep -c '^- ' "$rule_file" 2>/dev/null || echo 0)
                count=$((count + file_count))
            fi
        done
    fi

    # Also check legacy rules directory
    if [[ -d "$RULES_DIR" ]]; then
        for rule_file in "$RULES_DIR"/*.md; do
            if [[ -f "$rule_file" ]]; then
                local file_count
                file_count=$(grep -c '^- ' "$rule_file" 2>/dev/null || echo 0)
                count=$((count + file_count))
            fi
        done
    fi

    echo "$count"
}

# Generate resume prompt for Claude
generate_resume_prompt() {
    local tasks_json="$1"
    local count=$(echo "$tasks_json" | jq 'length')

    if [[ "$count" -eq 0 ]]; then
        return
    fi

    # Get the most recent incomplete task
    local task=$(echo "$tasks_json" | jq -r '.[0]')
    local task_id=$(echo "$task" | jq -r '.id')
    local goal=$(echo "$task" | jq -r '.goal')
    local status=$(echo "$task" | jq -r '.status')
    local step=$(echo "$task" | jq -r '.step')
    local total=$(echo "$task" | jq -r '.total')
    local last_activity=$(echo "$task" | jq -r '.last_activity')

    cat <<EOF

INCOMPLETE BUILD FOUND

A previous build was not completed. Here are the details:

ID:     $task_id
Goal:   $goal
Status: $status at step $step/$total
Last:   $last_activity

Options for the user:
  [r] Resume this build: /build resume
  [a] Abort this build:  /build abort
  [n] Start a new build: /build <goal>

Ask the user what they would like to do with this incomplete build.
EOF

    # If more than one incomplete task
    if [[ "$count" -gt 1 ]]; then
        cat <<EOF

Note: There are $count incomplete tasks total. Use '/build list' to see all.
EOF
    fi
}

# Main
main() {
    ensure_directories

    local incomplete_tasks
    incomplete_tasks=$(find_incomplete_tasks)

    local task_count
    task_count=$(echo "$incomplete_tasks" | jq 'length' 2>/dev/null || echo 0)

    local rule_count
    rule_count=$(count_rules)

    local studio_available="true"
    if [[ ! -d "$STUDIO_DIR" ]] && [[ -z "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        studio_available="false"
    fi

    # Generate the context for Claude
    local resume_prompt=""
    if [[ "$task_count" -gt 0 ]]; then
        resume_prompt=$(generate_resume_prompt "$incomplete_tasks")
    fi

    # Output JSON response with additionalContext for Claude
    if [[ "$task_count" -gt 0 ]]; then
        cat <<EOF
{"additionalContext": "STUDIO session initialized.
Available: ${studio_available}
Memory rules loaded: ${rule_count}
${resume_prompt}"}
EOF
    else
        cat <<EOF
{"additionalContext": "STUDIO session initialized. Available: ${studio_available}. Memory rules loaded: ${rule_count}. No incomplete tasks found."}
EOF
    fi

    exit 0
}

main
