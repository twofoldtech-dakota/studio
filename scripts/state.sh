#!/usr/bin/env bash
#
# STUDIO State Management Utilities
# ================================
#
# This script provides helper functions for managing STUDIO cast state.
# It can be sourced by other scripts or used directly via subcommands.
#
# Usage:
#   ./state.sh init <cast_id> <goal>      Initialize a new cast
#   ./state.sh get <cast_id> [field]      Get cast state or specific field
#   ./state.sh set <cast_id> <field> <v>  Set a field in cast state
#   ./state.sh phase <cast_id> <phase>    Update cast phase
#   ./state.sh step <cast_id> <step_id>   Mark step as current
#   ./state.sh complete <cast_id> <step>  Mark step as complete
#   ./state.sh checkpoint <cast_id> <n>   Save checkpoint
#   ./state.sh list                       List all casts
#   ./state.sh clean [days]               Clean old casts (default: 7 days)
#
# State is stored in studio/casts/<cast_id>/
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-studio}"
CASTS_DIR="${STUDIO_DIR}/casts"

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

# Generate a cast ID
generate_cast_id() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    echo "cast_${timestamp}"
}

# Ensure the STUDIO directory structure exists
ensure_studio_dir() {
    mkdir -p "${STUDIO_DIR}"
    mkdir -p "${CASTS_DIR}"

    # Create config if it doesn't exist
    if [[ ! -f "${STUDIO_DIR}/config.json" ]]; then
        cat > "${STUDIO_DIR}/config.json" << 'EOF'
{
  "version": "1.0.0",
  "checkpoint_enabled": true,
  "tempering_required": true,
  "max_replan_attempts": 3,
  "verbose_output": false
}
EOF
    fi
}

# Initialize a new cast
cmd_init() {
    local cast_id="${1:-$(generate_cast_id)}"
    local goal="${2:-}"

    if [[ -z "$goal" ]]; then
        log_error "Goal is required: ./state.sh init <cast_id> <goal>"
        exit 1
    fi

    ensure_studio_dir

    local cast_dir="${CASTS_DIR}/${cast_id}"

    if [[ -d "$cast_dir" ]]; then
        log_error "Cast ${cast_id} already exists"
        exit 1
    fi

    mkdir -p "${cast_dir}"
    mkdir -p "${cast_dir}/temper_reports"

    # Create initial state
    local now
    now=$(date -Iseconds)

    cat > "${cast_dir}/state.json" << EOF
{
  "id": "${cast_id}",
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
  "temper_attempts": 0,
  "last_verdict": null,
  "checkpoints": []
}
EOF

    # Create empty forge log
    touch "${cast_dir}/forge_log.jsonl"

    log_success "Initialized cast: ${cast_id}"
    echo "${cast_id}"
}

# Get cast state or a specific field
cmd_get() {
    local cast_id="${1:-}"
    local field="${2:-}"

    if [[ -z "$cast_id" ]]; then
        log_error "Cast ID required: ./state.sh get <cast_id> [field]"
        exit 1
    fi

    local state_file="${CASTS_DIR}/${cast_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Cast ${cast_id} not found"
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

# Set a field in cast state
cmd_set() {
    local cast_id="${1:-}"
    local field="${2:-}"
    local value="${3:-}"

    if [[ -z "$cast_id" || -z "$field" ]]; then
        log_error "Usage: ./state.sh set <cast_id> <field> <value>"
        exit 1
    fi

    local state_file="${CASTS_DIR}/${cast_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Cast ${cast_id} not found"
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

    log_success "Set ${field}=${value} for cast ${cast_id}"
}

# Update cast phase
cmd_phase() {
    local cast_id="${1:-}"
    local phase="${2:-}"

    if [[ -z "$cast_id" || -z "$phase" ]]; then
        log_error "Usage: ./state.sh phase <cast_id> <phase>"
        exit 1
    fi

    local phase_num
    local status

    case "$phase" in
        blueprinting|1)
            phase_num=1
            status="blueprinting"
            ;;
        forging|2)
            phase_num=2
            status="forging"
            ;;
        tempering|3)
            phase_num=3
            status="tempering"
            ;;
        complete|4)
            phase_num=4
            status="complete"
            ;;
        *)
            log_error "Unknown phase: ${phase}"
            log_error "Valid phases: blueprinting, forging, tempering, complete (or 1-4)"
            exit 1
            ;;
    esac

    cmd_set "$cast_id" "phase" "$phase_num"
    cmd_set "$cast_id" "status" "$status"

    log_success "Cast ${cast_id} moved to phase: ${status}"
}

# Set current step
cmd_step() {
    local cast_id="${1:-}"
    local step_id="${2:-}"

    if [[ -z "$cast_id" || -z "$step_id" ]]; then
        log_error "Usage: ./state.sh step <cast_id> <step_id>"
        exit 1
    fi

    cmd_set "$cast_id" "current_step" "$step_id"
    log_success "Cast ${cast_id} current step: ${step_id}"
}

# Mark step as complete
cmd_complete() {
    local cast_id="${1:-}"
    local step_id="${2:-}"

    if [[ -z "$cast_id" || -z "$step_id" ]]; then
        log_error "Usage: ./state.sh complete <cast_id> <step_id>"
        exit 1
    fi

    local state_file="${CASTS_DIR}/${cast_id}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Cast ${cast_id} not found"
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

    log_success "Cast ${cast_id} completed step: ${step_id}"
}

# Save checkpoint
cmd_checkpoint() {
    local cast_id="${1:-}"
    local checkpoint_name="${2:-}"

    if [[ -z "$cast_id" || -z "$checkpoint_name" ]]; then
        log_error "Usage: ./state.sh checkpoint <cast_id> <checkpoint_name>"
        exit 1
    fi

    local cast_dir="${CASTS_DIR}/${cast_id}"
    local state_file="${cast_dir}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Cast ${cast_id} not found"
        exit 1
    fi

    # Create checkpoint file
    local now
    now=$(date -Iseconds)
    local checkpoint_file="${cast_dir}/checkpoint_${checkpoint_name}.json"

    cp "$state_file" "$checkpoint_file"

    if command -v jq &> /dev/null; then
        local tmp_file
        tmp_file=$(mktemp)
        jq ".checkpoints += [{\"name\": \"${checkpoint_name}\", \"timestamp\": \"${now}\"}] | .updated_at = \"${now}\"" "$state_file" > "$tmp_file"
        mv "$tmp_file" "$state_file"
    fi

    log_success "Checkpoint '${checkpoint_name}' saved for cast ${cast_id}"
}

# List all casts
cmd_list() {
    ensure_studio_dir

    echo "STUDIO CASTS"
    echo "───────────"
    echo ""

    if [[ ! -d "$CASTS_DIR" ]] || [[ -z "$(ls -A "$CASTS_DIR" 2>/dev/null)" ]]; then
        echo "No casts found."
        return 0
    fi

    printf "%-25s | %-12s | %-30s | %-10s\n" "ID" "Status" "Goal" "Steps"
    echo "─────────────────────────────────────────────────────────────────────────────────"

    for cast_dir in "${CASTS_DIR}"/*/; do
        if [[ -d "$cast_dir" ]]; then
            local state_file="${cast_dir}state.json"
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
                    id=$(basename "$cast_dir")
                    printf "%-25s | %-12s | %-30s | %-10s\n" "$id" "?" "?" "?"
                fi
            fi
        fi
    done
}

# Clean old casts
cmd_clean() {
    local days="${1:-7}"

    log_info "Cleaning casts older than ${days} days..."

    local count=0

    for cast_dir in "${CASTS_DIR}"/*/; do
        if [[ -d "$cast_dir" ]]; then
            local state_file="${cast_dir}state.json"
            if [[ -f "$state_file" ]]; then
                # Check if cast is old and complete
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
                        log_info "Removing old cast: $(basename "$cast_dir")"
                        rm -rf "$cast_dir"
                        ((count++))
                    fi
                fi
            fi
        fi
    done

    log_success "Cleaned ${count} old casts"
}

# Log a forge entry
cmd_log_forge() {
    local cast_id="${1:-}"
    local entry="${2:-}"

    if [[ -z "$cast_id" || -z "$entry" ]]; then
        log_error "Usage: ./state.sh log_forge <cast_id> <json_entry>"
        exit 1
    fi

    local log_file="${CASTS_DIR}/${cast_id}/forge_log.jsonl"

    if [[ ! -f "$log_file" ]]; then
        log_error "Cast ${cast_id} not found"
        exit 1
    fi

    echo "$entry" >> "$log_file"
    log_success "Logged forge entry for cast ${cast_id}"
}

# Show help
cmd_help() {
    cat << 'EOF'
STUDIO State Management Utilities
================================

Usage: ./state.sh <command> [arguments]

Commands:
  init <cast_id> <goal>       Initialize a new cast
  get <cast_id> [field]       Get cast state or specific field
  set <cast_id> <field> <v>   Set a field in cast state
  phase <cast_id> <phase>     Update cast phase (blueprinting|forging|tempering|complete)
  step <cast_id> <step_id>    Mark step as current
  complete <cast_id> <step>   Mark step as complete
  checkpoint <cast_id> <name> Save checkpoint
  log_forge <cast_id> <json>  Log a forge entry
  list                        List all casts
  clean [days]                Clean old casts (default: 7 days)
  help                        Show this help message

Environment Variables:
  STUDIO_DIR                   Base directory for STUDIO state (default: studio)

Examples:
  ./state.sh init cast_001 "Build user authentication"
  ./state.sh phase cast_001 forging
  ./state.sh step cast_001 step_3
  ./state.sh complete cast_001 step_3
  ./state.sh checkpoint cast_001 "core_complete"
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
        log_forge|log)
            cmd_log_forge "$@"
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
