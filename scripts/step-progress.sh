#!/usr/bin/env bash
# ============================================================================
# step-progress.sh - Build Step Progress Tracker
# ============================================================================
# Tracks completed steps during build for resume functionality.
# Stores progress in .studio/tasks/<task_id>/progress.json
#
# Usage:
#   ./scripts/step-progress.sh init <task_id>              # Initialize progress
#   ./scripts/step-progress.sh complete <task_id> <step_id> # Mark step complete
#   ./scripts/step-progress.sh status <task_id>            # Get progress status
#   ./scripts/step-progress.sh next <task_id>              # Get next step to execute
#   ./scripts/step-progress.sh reset <task_id>             # Reset all progress
#   ./scripts/step-progress.sh is-complete <task_id> <step_id>  # Check if step done
#
# Exit codes:
#   0 - Success / Step is complete (for is-complete)
#   1 - Step not complete (for is-complete) / Error
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
step-progress.sh - Build Step Progress Tracker

USAGE:
    ./scripts/step-progress.sh init <task_id>               # Initialize tracking
    ./scripts/step-progress.sh complete <task_id> <step_id> # Mark step complete
    ./scripts/step-progress.sh status <task_id>             # Show progress
    ./scripts/step-progress.sh next <task_id>               # Get next step ID
    ./scripts/step-progress.sh reset <task_id>              # Reset progress
    ./scripts/step-progress.sh is-complete <task_id> <step_id>  # Check step

OPTIONS:
    --force    With reset, skip confirmation
    --json     Output JSON format
    --help     Show this help

EXAMPLES:
    # Start tracking progress for a task
    ./scripts/step-progress.sh init task_20240215_auth

    # Mark step as complete
    ./scripts/step-progress.sh complete task_20240215_auth step_1

    # Check if should skip step (for resume)
    if ./scripts/step-progress.sh is-complete task_20240215_auth step_1; then
        echo "Skipping step_1 (already complete)"
    fi

    # Get next step to execute
    NEXT_STEP=$(./scripts/step-progress.sh next task_20240215_auth)
EOF
}

# ============================================================================
# PROGRESS FILE MANAGEMENT
# ============================================================================

get_progress_file() {
    local task_id="$1"
    echo "${STUDIO_DIR}/tasks/${task_id}/progress.json"
}

ensure_progress_file() {
    local task_id="$1"
    local progress_file
    progress_file=$(get_progress_file "$task_id")
    
    if [[ ! -f "$progress_file" ]]; then
        # Initialize from plan.json if it exists
        local plan_file="${STUDIO_DIR}/tasks/${task_id}/plan.json"
        local steps=()
        
        if [[ -f "$plan_file" ]]; then
            # Extract step IDs from plan
            steps=$(jq -c '[.steps[].id]' "$plan_file" 2>/dev/null || echo '[]')
        else
            steps='[]'
        fi
        
        local now
        now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        
        mkdir -p "$(dirname "$progress_file")"
        cat > "$progress_file" << EOF
{
  "task_id": "$task_id",
  "initialized_at": "$now",
  "updated_at": "$now",
  "steps": $steps,
  "completed_steps": [],
  "failed_steps": [],
  "current_step": null,
  "status": "pending"
}
EOF
    fi
    
    echo "$progress_file"
}

# ============================================================================
# COMMANDS
# ============================================================================

# Initialize progress tracking
cmd_init() {
    local task_id="${1:-}"
    
    if [[ -z "$task_id" ]]; then
        echo "Error: task_id required" >&2
        exit 1
    fi
    
    local progress_file
    progress_file=$(ensure_progress_file "$task_id")
    
    # Reset if already exists
    local plan_file="${STUDIO_DIR}/tasks/${task_id}/plan.json"
    local steps='[]'
    
    if [[ -f "$plan_file" ]]; then
        steps=$(jq -c '[.steps[].id]' "$plan_file" 2>/dev/null || echo '[]')
    fi
    
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    jq --arg now "$now" --argjson steps "$steps" \
        '.initialized_at = $now | .updated_at = $now | .steps = $steps | .completed_steps = [] | .failed_steps = [] | .current_step = null | .status = "pending"' \
        "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
    
    echo "{\"ok\": true, \"task_id\": \"$task_id\", \"total_steps\": $(echo "$steps" | jq 'length')}"
}

# Mark step as complete
cmd_complete() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    
    if [[ -z "$task_id" || -z "$step_id" ]]; then
        echo "Error: task_id and step_id required" >&2
        exit 1
    fi
    
    local progress_file
    progress_file=$(ensure_progress_file "$task_id")
    
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Add to completed_steps if not already there
    jq --arg step_id "$step_id" --arg now "$now" \
        'if (.completed_steps | index($step_id)) then . else .completed_steps += [$step_id] end | .updated_at = $now | .current_step = $step_id' \
        "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
    
    # Check if all steps complete
    local total completed
    total=$(jq '.steps | length' "$progress_file")
    completed=$(jq '.completed_steps | length' "$progress_file")
    
    if [[ "$completed" -eq "$total" && "$total" -gt 0 ]]; then
        jq '.status = "complete"' "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
    else
        jq '.status = "in_progress"' "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
    fi
    
    echo "{\"ok\": true, \"step_id\": \"$step_id\", \"completed\": $completed, \"total\": $total}"
}

# Mark step as failed
cmd_fail() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    local error="${3:-unknown error}"
    
    if [[ -z "$task_id" || -z "$step_id" ]]; then
        echo "Error: task_id and step_id required" >&2
        exit 1
    fi
    
    local progress_file
    progress_file=$(ensure_progress_file "$task_id")
    
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    jq --arg step_id "$step_id" --arg now "$now" --arg error "$error" \
        '.failed_steps += [{"step_id": $step_id, "error": $error, "at": $now}] | .updated_at = $now | .status = "failed" | .current_step = $step_id' \
        "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
    
    echo "{\"ok\": true, \"step_id\": \"$step_id\", \"status\": \"failed\"}"
}

# Get progress status
cmd_status() {
    local task_id="${1:-}"
    local json_only="${2:-false}"
    
    if [[ -z "$task_id" ]]; then
        echo "Error: task_id required" >&2
        exit 1
    fi
    
    local progress_file
    progress_file=$(ensure_progress_file "$task_id")
    
    local total completed failed status
    total=$(jq '.steps | length' "$progress_file")
    completed=$(jq '.completed_steps | length' "$progress_file")
    failed=$(jq '.failed_steps | length' "$progress_file")
    status=$(jq -r '.status' "$progress_file")
    
    if [[ "$json_only" == "true" ]]; then
        jq '{task_id: .task_id, status: .status, total_steps: (.steps | length), completed: (.completed_steps | length), failed: (.failed_steps | length), completed_steps: .completed_steps, current_step: .current_step}' "$progress_file"
    else
        echo -e "${BLUE}Task:${NC} $task_id"
        echo -e "${BLUE}Status:${NC} $status"
        echo -e "${BLUE}Progress:${NC} $completed / $total steps complete"
        if [[ "$failed" -gt 0 ]]; then
            echo -e "${YELLOW}Failed:${NC} $failed steps"
        fi
        
        # Show which steps are done
        echo ""
        echo "Steps:"
        jq -r '.steps[] as $s | if (.completed_steps | index($s)) then "  ✓ \($s)" else "  ○ \($s)" end' "$progress_file"
    fi
}

# Get next step to execute
cmd_next() {
    local task_id="${1:-}"
    
    if [[ -z "$task_id" ]]; then
        echo "Error: task_id required" >&2
        exit 1
    fi
    
    local progress_file
    progress_file=$(ensure_progress_file "$task_id")
    
    # Find first step not in completed_steps
    local next_step
    next_step=$(jq -r '.steps as $all | .completed_steps as $done | ($all - $done)[0] // empty' "$progress_file")
    
    if [[ -z "$next_step" ]]; then
        echo ""  # All done
        exit 0
    fi
    
    echo "$next_step"
}

# Check if step is complete
cmd_is_complete() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    
    if [[ -z "$task_id" || -z "$step_id" ]]; then
        echo "Error: task_id and step_id required" >&2
        exit 1
    fi
    
    local progress_file
    progress_file=$(ensure_progress_file "$task_id")
    
    local is_done
    is_done=$(jq --arg step_id "$step_id" '.completed_steps | index($step_id) != null' "$progress_file")
    
    if [[ "$is_done" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Reset progress
cmd_reset() {
    local task_id="${1:-}"
    local force="${2:-false}"
    
    if [[ -z "$task_id" ]]; then
        echo "Error: task_id required" >&2
        exit 1
    fi
    
    local progress_file
    progress_file=$(get_progress_file "$task_id")
    
    if [[ -f "$progress_file" && "$force" != "true" ]]; then
        echo "Warning: This will reset all progress for $task_id"
        read -p "Continue? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted"
            exit 0
        fi
    fi
    
    cmd_init "$task_id"
    echo "{\"ok\": true, \"task_id\": \"$task_id\", \"action\": \"reset\"}"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local cmd="${1:-}"
    shift || true
    
    case "$cmd" in
        init)
            cmd_init "$@"
            ;;
        complete)
            cmd_complete "$@"
            ;;
        fail)
            cmd_fail "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        next)
            cmd_next "$@"
            ;;
        is-complete)
            cmd_is_complete "$@"
            ;;
        reset)
            local force="false"
            local task_id=""
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --force) force="true"; shift ;;
                    *) task_id="$1"; shift ;;
                esac
            done
            cmd_reset "$task_id" "$force"
            ;;
        --help|-h|help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            show_help
            exit 1
            ;;
    esac
}

main "$@"
