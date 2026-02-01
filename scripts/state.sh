#!/usr/bin/env bash
#
# STUDIO State Management Utilities
# ================================
#
# This script provides helper functions for managing STUDIO task state.
# It can be sourced by other scripts or used directly via subcommands.
#
# Usage:
#   ./state.sh init <task_id> <goal>      Initialize a new task
#   ./state.sh get <task_id> [field]      Get task state or specific field
#   ./state.sh set <task_id> <field> <v>  Set a field in task state
#   ./state.sh phase <task_id> <phase>    Update task phase
#   ./state.sh step <task_id> <step_id>   Mark step as current
#   ./state.sh complete <task_id> <step>  Mark step as complete
#   ./state.sh checkpoint <task_id> <n>   Save checkpoint
#   ./state.sh list                       List all tasks
#   ./state.sh clean [days]               Clean old tasks (default: 7 days)
#
# State is stored in studio/tasks/<task_id>/
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-studio}"
TASKS_DIR="${STUDIO_DIR}/tasks"

# Colors for output (if terminal supports them)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging functions
log_info() {
    echo -e "${BLUE}[STUDIO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[STUDIO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[STUDIO]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[STUDIO]${NC} $*" >&2
}

# Generate a task ID
generate_task_id() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    echo "task_${timestamp}"
}

# Ensure the STUDIO directory structure exists
ensure_studio_dir() {
    mkdir -p "${STUDIO_DIR}"
    mkdir -p "${TASKS_DIR}"

    # Create config if it doesn't exist
    if [[ ! -f "${STUDIO_DIR}/config.json" ]]; then
        cat > "${STUDIO_DIR}/config.json" << 'EOF'
{
  "version": "1.0.0",
  "checkpoint_enabled": true,
  "verifying_required": true,
  "max_replan_attempts": 3,
  "verbose_output": false
}
EOF
    fi
}

# Initialize a new task
cmd_init() {
    local task_id="${1:-$(generate_task_id)}"
    local goal="${2:-}"

    if [[ -z "$goal" ]]; then
        log_error "Goal is required: ./state.sh init <task_id> <goal>"
        exit 1
    fi

    ensure_studio_dir

    local task_dir="${TASKS_DIR}/${task_id}"

    if [[ -d "$task_dir" ]]; then
        log_error "Task ${task_id} already exists"
        exit 1
    fi

    mkdir -p "${task_dir}"
    mkdir -p "${task_dir}/verify_reports"

    # Create initial state
    local now
    now=$(date -Iseconds)

    cat > "${task_dir}/state.json" << EOF
{
  "id": "${task_id}",
  "goal": "${goal}",
  "status": "initializing",
  "phase": 0,
  "started_at": "${now}",
  "updated_at": "${now}",
  "completed_at": null,
  "current_step": null,
  "completed_steps": [],
  "failed_steps": [],
  "skipped_steps": [],
  "replan_count": 0,
  "verify_attempts": 0,
  "last_verdict": null,
  "checkpoints": []
}
EOF

    # Create empty build log
    touch "${task_dir}/build_log.jsonl"

    log_success "Initialized task: ${task_id}"
    echo "${task_id}"
}

# Get task state or a specific field
cmd_get() {
    local task_id="${1:-}"
    local field="${2:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Task ID required: ./state.sh get <task_id> [field]"
        exit 1
    fi

    local state_file="${TASKS_DIR}/${task_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Task ${task_id} not found"
        exit 1
    fi

    if [[ -z "$field" ]]; then
        cat "$state_file"
    else
        # Use jq if available, otherwise use grep/sed
        if command -v jq &> /dev/null; then
            jq -r ".${field}" "$state_file"
        else
            grep "\"${field}\"" "$state_file" | sed 's/.*: *"\?\([^",}]*\)"\?.*/\1/'
        fi
    fi
}

# Set a field in task state
cmd_set() {
    local task_id="${1:-}"
    local field="${2:-}"
    local value="${3:-}"

    if [[ -z "$task_id" || -z "$field" ]]; then
        log_error "Usage: ./state.sh set <task_id> <field> <value>"
        exit 1
    fi

    local state_file="${TASKS_DIR}/${task_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Task ${task_id} not found"
        exit 1
    fi

    local now
    now=$(date -Iseconds)

    if command -v jq &> /dev/null; then
        # Use jq for proper JSON manipulation
        local tmp_file
        tmp_file=$(mktemp)

        # Determine if value is a string or other type
        if [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" == "true" ]] || [[ "$value" == "false" ]] || [[ "$value" == "null" ]]; then
            jq ".${field} = ${value} | .updated_at = \"${now}\"" "$state_file" > "$tmp_file"
        else
            jq ".${field} = \"${value}\" | .updated_at = \"${now}\"" "$state_file" > "$tmp_file"
        fi

        mv "$tmp_file" "$state_file"
    else
        log_warn "jq not available, using basic sed (may not handle all cases)"
        sed -i "s/\"${field}\": *\"[^\"]*\"/\"${field}\": \"${value}\"/" "$state_file"
        sed -i "s/\"updated_at\": *\"[^\"]*\"/\"updated_at\": \"${now}\"/" "$state_file"
    fi

    log_success "Set ${field}=${value} for task ${task_id}"
}

# Update task phase
cmd_phase() {
    local task_id="${1:-}"
    local phase="${2:-}"

    if [[ -z "$task_id" || -z "$phase" ]]; then
        log_error "Usage: ./state.sh phase <task_id> <phase>"
        exit 1
    fi

    local phase_num
    local status

    case "$phase" in
        planing|1)
            phase_num=1
            status="planing"
            ;;
        building|2)
            phase_num=2
            status="building"
            ;;
        verifying|3)
            phase_num=3
            status="verifying"
            ;;
        complete|4)
            phase_num=4
            status="complete"
            ;;
        *)
            log_error "Unknown phase: ${phase}"
            log_error "Valid phases: planing, building, verifying, complete (or 1-4)"
            exit 1
            ;;
    esac

    cmd_set "$task_id" "phase" "$phase_num"
    cmd_set "$task_id" "status" "$status"

    log_success "Task ${task_id} moved to phase: ${status}"
}

# Set current step
cmd_step() {
    local task_id="${1:-}"
    local step_id="${2:-}"

    if [[ -z "$task_id" || -z "$step_id" ]]; then
        log_error "Usage: ./state.sh step <task_id> <step_id>"
        exit 1
    fi

    cmd_set "$task_id" "current_step" "$step_id"
    log_success "Task ${task_id} current step: ${step_id}"
}

# Mark step as complete
cmd_complete() {
    local task_id="${1:-}"
    local step_id="${2:-}"

    if [[ -z "$task_id" || -z "$step_id" ]]; then
        log_error "Usage: ./state.sh complete <task_id> <step_id>"
        exit 1
    fi

    local state_file="${TASKS_DIR}/${task_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Task ${task_id} not found"
        exit 1
    fi

    local now
    now=$(date -Iseconds)

    if command -v jq &> /dev/null; then
        local tmp_file
        tmp_file=$(mktemp)
        jq ".completed_steps += [\"${step_id}\"] | .updated_at = \"${now}\"" "$state_file" > "$tmp_file"
        mv "$tmp_file" "$state_file"
    else
        log_error "jq required for array manipulation"
        exit 1
    fi

    log_success "Task ${task_id} completed step: ${step_id}"
}

# Save checkpoint
cmd_checkpoint() {
    local task_id="${1:-}"
    local checkpoint_name="${2:-}"

    if [[ -z "$task_id" || -z "$checkpoint_name" ]]; then
        log_error "Usage: ./state.sh checkpoint <task_id> <checkpoint_name>"
        exit 1
    fi

    local task_dir="${TASKS_DIR}/${task_id}"
    local state_file="${task_dir}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Task ${task_id} not found"
        exit 1
    fi

    # Create checkpoint file
    local now
    now=$(date -Iseconds)
    local checkpoint_file="${task_dir}/checkpoint_${checkpoint_name}.json"

    cp "$state_file" "$checkpoint_file"

    if command -v jq &> /dev/null; then
        local tmp_file
        tmp_file=$(mktemp)
        jq ".checkpoints += [{\"name\": \"${checkpoint_name}\", \"timestamp\": \"${now}\"}] | .updated_at = \"${now}\"" "$state_file" > "$tmp_file"
        mv "$tmp_file" "$state_file"
    fi

    log_success "Checkpoint '${checkpoint_name}' saved for task ${task_id}"
}

# List all tasks
cmd_list() {
    ensure_studio_dir

    echo "STUDIO TASKS"
    echo "───────────"
    echo ""

    if [[ ! -d "$TASKS_DIR" ]] || [[ -z "$(ls -A "$TASKS_DIR" 2>/dev/null)" ]]; then
        echo "No tasks found."
        return 0
    fi

    printf "%-25s | %-12s | %-30s | %-10s\n" "ID" "Status" "Goal" "Steps"
    echo "─────────────────────────────────────────────────────────────────────────────────"

    for task_dir in "${TASKS_DIR}"/*/; do
        if [[ -d "$task_dir" ]]; then
            local state_file="${task_dir}state.json"
            if [[ -f "$state_file" ]]; then
                if command -v jq &> /dev/null; then
                    local id status goal completed
                    id=$(jq -r '.id' "$state_file")
                    status=$(jq -r '.status' "$state_file")
                    goal=$(jq -r '.goal' "$state_file" | cut -c1-28)
                    completed=$(jq -r '.completed_steps | length' "$state_file")
                    printf "%-25s | %-12s | %-30s | %s\n" "$id" "$status" "$goal" "$completed"
                else
                    local id
                    id=$(basename "$task_dir")
                    printf "%-25s | %-12s | %-30s | %-10s\n" "$id" "?" "?" "?"
                fi
            fi
        fi
    done
}

# Clean old tasks
cmd_clean() {
    local days="${1:-7}"

    log_info "Cleaning tasks older than ${days} days..."

    local count=0

    for task_dir in "${TASKS_DIR}"/*/; do
        if [[ -d "$task_dir" ]]; then
            local state_file="${task_dir}state.json"
            if [[ -f "$state_file" ]]; then
                # Check if task is old and complete
                local mtime
                mtime=$(stat -c %Y "$state_file" 2>/dev/null || stat -f %m "$state_file" 2>/dev/null)
                local now
                now=$(date +%s)
                local age_days=$(( (now - mtime) / 86400 ))

                if [[ $age_days -gt $days ]]; then
                    local status
                    if command -v jq &> /dev/null; then
                        status=$(jq -r '.status' "$state_file")
                    else
                        status="unknown"
                    fi

                    if [[ "$status" == "complete" ]] || [[ "$status" == "aborted" ]]; then
                        log_info "Removing old task: $(basename "$task_dir")"
                        rm -rf "$task_dir"
                        ((count++))
                    fi
                fi
            fi
        fi
    done

    log_success "Cleaned ${count} old tasks"
}

# Log a build entry
cmd_log_build() {
    local task_id="${1:-}"
    local entry="${2:-}"

    if [[ -z "$task_id" || -z "$entry" ]]; then
        log_error "Usage: ./state.sh log_build <task_id> <json_entry>"
        exit 1
    fi

    local log_file="${TASKS_DIR}/${task_id}/build_log.jsonl"

    if [[ ! -f "$log_file" ]]; then
        log_error "Task ${task_id} not found"
        exit 1
    fi

    echo "$entry" >> "$log_file"
    log_success "Logged build entry for task ${task_id}"
}

# Show help
cmd_help() {
    cat << 'EOF'
STUDIO State Management Utilities
================================

Usage: ./state.sh <command> [arguments]

Commands:
  init <task_id> <goal>       Initialize a new task
  get <task_id> [field]       Get task state or specific field
  set <task_id> <field> <v>   Set a field in task state
  phase <task_id> <phase>     Update task phase (planing|building|verifying|complete)
  step <task_id> <step_id>    Mark step as current
  complete <task_id> <step>   Mark step as complete
  checkpoint <task_id> <name> Save checkpoint
  log_build <task_id> <json>  Log a build entry
  list                        List all tasks
  clean [days]                Clean old tasks (default: 7 days)
  help                        Show this help message

Environment Variables:
  STUDIO_DIR                   Base directory for STUDIO state (default: studio)

Examples:
  ./state.sh init task_001 "Build user authentication"
  ./state.sh phase task_001 building
  ./state.sh step task_001 step_3
  ./state.sh complete task_001 step_3
  ./state.sh checkpoint task_001 "core_complete"
  ./state.sh list

EOF
}

# Main dispatch
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init)
            cmd_init "$@"
            ;;
        get)
            cmd_get "$@"
            ;;
        set)
            cmd_set "$@"
            ;;
        phase)
            cmd_phase "$@"
            ;;
        step)
            cmd_step "$@"
            ;;
        complete)
            cmd_complete "$@"
            ;;
        checkpoint)
            cmd_checkpoint "$@"
            ;;
        log_build|log)
            cmd_log_build "$@"
            ;;
        list|ls)
            cmd_list "$@"
            ;;
        clean)
            cmd_clean "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            log_error "Unknown command: ${cmd}"
            cmd_help
            exit 1
            ;;
    esac
}

# Run main if script is executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
