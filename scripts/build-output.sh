#!/usr/bin/env bash
#
# STUDIO Build Output Manager
# ===========================
#
# Manages the consolidated build-output.json file that enables task resumption.
# This file tracks per-step and per-micro-action execution status, validation
# results, retry history, and provides explicit resume point information.
#
# Usage:
#   ./build-output.sh init <task_id>                       Initialize from plan.json
#   ./build-output.sh get <task_id> [jq_path]              Get build output or field
#   ./build-output.sh step <task_id> <step_id> <status>    Update step status
#   ./build-output.sh micro <task_id> <step_id> <seq> <status> [output_json]
#   ./build-output.sh validate <task_id> <step_id> <idx> <status> [actual_output]
#   ./build-output.sh retry <task_id> <step_id> <outcome> [error] [fix_applied]
#   ./build-output.sh artifact <task_id> <step_id> <path> <type> [checksum]
#   ./build-output.sh quality-gate <task_id> <verdict> <checks_json>
#   ./build-output.sh resume-point <task_id>               Calculate and update resume point
#   ./build-output.sh can-resume <task_id>                 Check if build can be resumed
#   ./build-output.sh summary <task_id>                    Human-readable summary
#   ./build-output.sh help                                 Show this help
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-studio}"
TASKS_DIR="${STUDIO_DIR}/tasks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Logging
log_info() { echo -e "${BLUE}[build-output]${NC} $*"; }
log_success() { echo -e "${GREEN}[build-output]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[build-output]${NC} $*" >&2; }
log_error() { echo -e "${RED}[build-output]${NC} $*" >&2; }

# Get current ISO timestamp
now_iso() {
    date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S%z
}

# Resolve task directory
get_task_dir() {
    local task_id="$1"
    echo "${TASKS_DIR}/${task_id}"
}

# Get build-output.json path
get_build_output_path() {
    local task_id="$1"
    echo "$(get_task_dir "$task_id")/build-output.json"
}

# Get plan.json path
get_plan_path() {
    local task_id="$1"
    echo "$(get_task_dir "$task_id")/plan.json"
}

# Safe jq update - reads file, applies filter, writes back
jq_update() {
    local file="$1"
    local filter="$2"
    local tmp_file
    tmp_file=$(mktemp)

    if jq "$filter" "$file" > "$tmp_file"; then
        mv "$tmp_file" "$file"
    else
        rm -f "$tmp_file"
        log_error "Failed to update JSON"
        return 1
    fi
}

# ============================================================================
# INIT COMMAND - Initialize build-output.json from plan.json
# ============================================================================
cmd_init() {
    local task_id="${1:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Usage: ./build-output.sh init <task_id>"
        exit 1
    fi

    local plan_file
    plan_file=$(get_plan_path "$task_id")
    local output_file
    output_file=$(get_build_output_path "$task_id")

    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        exit 1
    fi

    local now
    now=$(now_iso)

    # Transform plan.json to build-output.json
    jq --arg now "$now" '
    {
        version: "1.0.0",
        task_id: .task_id,
        plan_id: .id,
        goal: .goal,
        status: "pending",
        resume_point: {
            can_resume: true,
            next_step_id: (.steps[0].id // null),
            next_micro_action_sequence: null,
            last_completed_step: null,
            last_checkpoint: null,
            halt_reason: null,
            resume_instructions: null
        },
        steps: [.steps[] | {
            id: .id,
            name: .name,
            status: "pending",
            depends_on: (.depends_on // []),
            started_at: null,
            completed_at: null,
            duration_ms: null,
            micro_actions: [(.micro_actions // [])[] | {
                sequence: .sequence,
                tool: .tool,
                purpose: .purpose,
                status: "pending",
                started_at: null,
                completed_at: null,
                duration_ms: null,
                input: {
                    command: (.command // null),
                    file_path: (.file_path // null),
                    content_preview: (if .content then (.content | tostring | .[0:500]) else null end)
                },
                output: null
            }],
            validations: [(.success_criteria // [])[] | {
                criterion: .criterion,
                validation_command: .validation_command,
                expected_output: .expected_output,
                status: "pending",
                actual_output: null,
                executed_at: null,
                on_failure_action: (.on_failure // "retry")
            }],
            retry_history: [],
            artifacts_produced: [],
            errors: [],
            observations: [],
            skip_reason: null
        }],
        execution_summary: {
            total_steps: (.steps | length),
            completed_steps: 0,
            failed_steps: 0,
            skipped_steps: 0,
            pending_steps: (.steps | length),
            in_progress_steps: 0,
            total_retries: 0,
            quality_gate_verdict: null,
            duration_ms: null
        },
        quality_gate_results: null,
        artifacts: {
            created: [],
            modified: [],
            deleted: []
        },
        checkpoints: [],
        timestamps: {
            created_at: $now,
            updated_at: $now,
            started_at: null,
            completed_at: null,
            paused_at: null
        },
        embedded_context_hash: null
    }' "$plan_file" > "$output_file"

    log_success "Initialized build-output.json for task $task_id"
    echo "$output_file"
}

# ============================================================================
# GET COMMAND - Read build output or specific field
# ============================================================================
cmd_get() {
    local task_id="${1:-}"
    local jq_path="${2:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Usage: ./build-output.sh get <task_id> [jq_path]"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")

    if [[ ! -f "$output_file" ]]; then
        log_error "Build output not found: $output_file"
        exit 1
    fi

    if [[ -z "$jq_path" ]]; then
        cat "$output_file"
    else
        jq -r "$jq_path" "$output_file"
    fi
}

# ============================================================================
# STEP COMMAND - Update step status
# ============================================================================
cmd_step() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    local status="${3:-}"

    if [[ -z "$task_id" || -z "$step_id" || -z "$status" ]]; then
        log_error "Usage: ./build-output.sh step <task_id> <step_id> <status>"
        log_error "Status: pending|in_progress|completed|failed|skipped"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")

    if [[ ! -f "$output_file" ]]; then
        log_error "Build output not found: $output_file"
        exit 1
    fi

    local now
    now=$(now_iso)

    # Update step status and timestamps
    case "$status" in
        in_progress)
            jq_update "$output_file" --arg step_id "$step_id" --arg now "$now" '
                (.steps[] | select(.id == $step_id)) |= (
                    .status = "in_progress" |
                    .started_at = (if .started_at == null then $now else .started_at end)
                ) |
                .status = "in_progress" |
                .timestamps.updated_at = $now |
                .timestamps.started_at = (if .timestamps.started_at == null then $now else .timestamps.started_at end)
            '
            ;;
        completed)
            jq_update "$output_file" --arg step_id "$step_id" --arg now "$now" '
                (.steps[] | select(.id == $step_id)) |= (
                    .status = "completed" |
                    .completed_at = $now |
                    .duration_ms = (
                        if .started_at then
                            ((($now | fromdateiso8601) - (.started_at | fromdateiso8601)) * 1000 | floor)
                        else null end
                    )
                ) |
                .timestamps.updated_at = $now
            '
            ;;
        failed)
            jq_update "$output_file" --arg step_id "$step_id" --arg now "$now" '
                (.steps[] | select(.id == $step_id)) |= (
                    .status = "failed" |
                    .completed_at = $now
                ) |
                .timestamps.updated_at = $now
            '
            ;;
        skipped)
            jq_update "$output_file" --arg step_id "$step_id" --arg now "$now" '
                (.steps[] | select(.id == $step_id)) |= (
                    .status = "skipped" |
                    .completed_at = $now
                ) |
                .timestamps.updated_at = $now
            '
            ;;
        pending)
            jq_update "$output_file" --arg step_id "$step_id" --arg now "$now" '
                (.steps[] | select(.id == $step_id)) |= .status = "pending" |
                .timestamps.updated_at = $now
            '
            ;;
        *)
            log_error "Invalid status: $status"
            exit 1
            ;;
    esac

    # Recalculate execution summary
    cmd_recalculate_summary "$task_id"

    # Update resume point
    cmd_resume_point "$task_id" > /dev/null

    log_success "Step $step_id status: $status"
}

# ============================================================================
# MICRO COMMAND - Update micro-action status
# ============================================================================
cmd_micro() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    local sequence="${3:-}"
    local status="${4:-}"
    local output_json="${5:-}"

    if [[ -z "$task_id" || -z "$step_id" || -z "$sequence" || -z "$status" ]]; then
        log_error "Usage: ./build-output.sh micro <task_id> <step_id> <sequence> <status> [output_json]"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    # Build the jq filter based on status
    local filter
    case "$status" in
        in_progress)
            filter='(.steps[] | select(.id == $step_id) | .micro_actions[] | select(.sequence == ($seq | tonumber))) |= (
                .status = "in_progress" |
                .started_at = (if .started_at == null then $now else .started_at end)
            ) | .timestamps.updated_at = $now'
            ;;
        completed)
            if [[ -n "$output_json" ]]; then
                filter='(.steps[] | select(.id == $step_id) | .micro_actions[] | select(.sequence == ($seq | tonumber))) |= (
                    .status = "completed" |
                    .completed_at = $now |
                    .output = ($output | fromjson) |
                    .duration_ms = (if .started_at then ((($now | fromdateiso8601) - (.started_at | fromdateiso8601)) * 1000 | floor) else null end)
                ) | .timestamps.updated_at = $now'
            else
                filter='(.steps[] | select(.id == $step_id) | .micro_actions[] | select(.sequence == ($seq | tonumber))) |= (
                    .status = "completed" |
                    .completed_at = $now |
                    .duration_ms = (if .started_at then ((($now | fromdateiso8601) - (.started_at | fromdateiso8601)) * 1000 | floor) else null end)
                ) | .timestamps.updated_at = $now'
            fi
            ;;
        failed)
            if [[ -n "$output_json" ]]; then
                filter='(.steps[] | select(.id == $step_id) | .micro_actions[] | select(.sequence == ($seq | tonumber))) |= (
                    .status = "failed" |
                    .completed_at = $now |
                    .output = ($output | fromjson)
                ) | .timestamps.updated_at = $now'
            else
                filter='(.steps[] | select(.id == $step_id) | .micro_actions[] | select(.sequence == ($seq | tonumber))) |= (
                    .status = "failed" |
                    .completed_at = $now
                ) | .timestamps.updated_at = $now'
            fi
            ;;
        *)
            filter='(.steps[] | select(.id == $step_id) | .micro_actions[] | select(.sequence == ($seq | tonumber))) |= .status = $status | .timestamps.updated_at = $now'
            ;;
    esac

    jq_update "$output_file" --arg step_id "$step_id" --arg seq "$sequence" --arg status "$status" --arg now "$now" --arg output "${output_json:-}" "$filter"

    # Update resume point
    cmd_resume_point "$task_id" > /dev/null

    log_success "Micro-action $step_id:$sequence status: $status"
}

# ============================================================================
# VALIDATE COMMAND - Record validation result
# ============================================================================
cmd_validate() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    local criterion_idx="${3:-}"
    local status="${4:-}"
    local actual_output="${5:-}"

    if [[ -z "$task_id" || -z "$step_id" || -z "$criterion_idx" || -z "$status" ]]; then
        log_error "Usage: ./build-output.sh validate <task_id> <step_id> <criterion_index> <status> [actual_output]"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    jq_update "$output_file" --arg step_id "$step_id" --argjson idx "$criterion_idx" --arg status "$status" --arg now "$now" --arg actual "${actual_output:-}" '
        (.steps[] | select(.id == $step_id) | .validations[$idx]) |= (
            .status = $status |
            .executed_at = $now |
            .actual_output = (if $actual != "" then $actual else null end)
        ) |
        .timestamps.updated_at = $now
    '

    log_success "Validation $step_id[$criterion_idx] status: $status"
}

# ============================================================================
# RETRY COMMAND - Record retry attempt
# ============================================================================
cmd_retry() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    local outcome="${3:-}"
    local error="${4:-}"
    local fix_applied="${5:-}"

    if [[ -z "$task_id" || -z "$step_id" || -z "$outcome" ]]; then
        log_error "Usage: ./build-output.sh retry <task_id> <step_id> <outcome> [error] [fix_applied]"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    jq_update "$output_file" --arg step_id "$step_id" --arg outcome "$outcome" --arg now "$now" --arg error "${error:-}" --arg fix "${fix_applied:-}" '
        (.steps[] | select(.id == $step_id)) |= (
            .retry_history += [{
                attempt: ((.retry_history | length) + 1),
                timestamp: $now,
                outcome: $outcome,
                error: (if $error != "" then $error else null end),
                fix_applied: (if $fix != "" then $fix else null end)
            }]
        ) |
        .execution_summary.total_retries += 1 |
        .timestamps.updated_at = $now
    '

    log_success "Recorded retry for $step_id: $outcome"
}

# ============================================================================
# ARTIFACT COMMAND - Track artifact
# ============================================================================
cmd_artifact() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    local path="${3:-}"
    local type="${4:-}"  # created|modified|deleted
    local checksum="${5:-}"

    if [[ -z "$task_id" || -z "$step_id" || -z "$path" || -z "$type" ]]; then
        log_error "Usage: ./build-output.sh artifact <task_id> <step_id> <path> <type> [checksum]"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    # Get file size if file exists
    local size_bytes=0
    if [[ -f "$path" ]]; then
        size_bytes=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || echo 0)
    fi

    case "$type" in
        created)
            jq_update "$output_file" --arg step_id "$step_id" --arg path "$path" --arg now "$now" --argjson size "$size_bytes" --arg checksum "${checksum:-}" '
                .artifacts.created += [{
                    path: $path,
                    step_id: $step_id,
                    timestamp: $now,
                    size_bytes: $size,
                    checksum: (if $checksum != "" then $checksum else null end)
                }] |
                (.steps[] | select(.id == $step_id)).artifacts_produced += [$path] |
                .timestamps.updated_at = $now
            '
            ;;
        modified)
            jq_update "$output_file" --arg step_id "$step_id" --arg path "$path" --arg now "$now" --argjson size "$size_bytes" --arg checksum "${checksum:-}" '
                .artifacts.modified += [{
                    path: $path,
                    step_id: $step_id,
                    timestamp: $now,
                    size_bytes: $size,
                    checksum: (if $checksum != "" then $checksum else null end)
                }] |
                (.steps[] | select(.id == $step_id)).artifacts_produced += [$path] |
                .timestamps.updated_at = $now
            '
            ;;
        deleted)
            jq_update "$output_file" --arg step_id "$step_id" --arg path "$path" --arg now "$now" '
                .artifacts.deleted += [{
                    path: $path,
                    step_id: $step_id,
                    deleted_at: $now
                }] |
                .timestamps.updated_at = $now
            '
            ;;
        *)
            log_error "Invalid artifact type: $type (use: created|modified|deleted)"
            exit 1
            ;;
    esac

    log_success "Tracked artifact: $path ($type)"
}

# ============================================================================
# QUALITY-GATE COMMAND - Record quality gate results
# ============================================================================
cmd_quality_gate() {
    local task_id="${1:-}"
    local verdict="${2:-}"
    local checks_json="${3:-}"

    if [[ -z "$task_id" || -z "$verdict" ]]; then
        log_error "Usage: ./build-output.sh quality-gate <task_id> <verdict> [checks_json]"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    if [[ -n "$checks_json" ]]; then
        jq_update "$output_file" --arg verdict "$verdict" --arg now "$now" --argjson checks "$checks_json" '
            .quality_gate_results = {
                executed_at: $now,
                verdict: $verdict,
                checks: $checks
            } |
            .execution_summary.quality_gate_verdict = $verdict |
            .status = (if $verdict == "STRONG" or $verdict == "SOUND" then "completed" else "failed" end) |
            .timestamps.updated_at = $now |
            .timestamps.completed_at = $now
        '
    else
        jq_update "$output_file" --arg verdict "$verdict" --arg now "$now" '
            .quality_gate_results = {
                executed_at: $now,
                verdict: $verdict,
                checks: []
            } |
            .execution_summary.quality_gate_verdict = $verdict |
            .status = (if $verdict == "STRONG" or $verdict == "SOUND" then "completed" else "failed" end) |
            .timestamps.updated_at = $now |
            .timestamps.completed_at = $now
        '
    fi

    # Update resume point
    cmd_resume_point "$task_id" > /dev/null

    log_success "Quality gate verdict: $verdict"
}

# ============================================================================
# RESUME-POINT COMMAND - Calculate and update resume point
# ============================================================================
cmd_resume_point() {
    local task_id="${1:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Usage: ./build-output.sh resume-point <task_id>"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    # Calculate resume point from current state
    jq_update "$output_file" --arg now "$now" '
        # Find first non-completed step
        .resume_point.next_step_id = (
            [.steps[] | select(.status != "completed" and .status != "skipped")] | first | .id // null
        ) |

        # Find next micro-action within that step
        .resume_point.next_micro_action_sequence = (
            if .resume_point.next_step_id then
                [.steps[] | select(.id == .resume_point.next_step_id) | .micro_actions[] | select(.status != "completed" and .status != "skipped")] | first | .sequence // null
            else null end
        ) |

        # Find last completed step
        .resume_point.last_completed_step = (
            [.steps[] | select(.status == "completed")] | last | .id // null
        ) |

        # Determine if can resume
        .resume_point.can_resume = (
            .status != "completed" and
            .status != "aborted" and
            (.resume_point.next_step_id != null or .status == "awaiting_quality_gate")
        ) |

        # Set halt reason if failed/halted
        .resume_point.halt_reason = (
            if .status == "failed" or .status == "halted" then
                ([.steps[] | select(.status == "failed") | .errors[0].message] | first // "Step failed")
            else .resume_point.halt_reason end
        ) |

        .timestamps.updated_at = $now
    '

    # Output the resume point
    jq '.resume_point' "$output_file"
}

# ============================================================================
# CAN-RESUME COMMAND - Check if build can be resumed
# ============================================================================
cmd_can_resume() {
    local task_id="${1:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Usage: ./build-output.sh can-resume <task_id>"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")

    if [[ ! -f "$output_file" ]]; then
        echo '{"can_resume": false, "reason": "Build output not found"}'
        exit 0
    fi

    jq '{
        can_resume: .resume_point.can_resume,
        reason: (
            if .status == "completed" then "Build already completed"
            elif .status == "aborted" then "Build was aborted"
            elif .resume_point.next_step_id == null then "No pending steps"
            elif .resume_point.can_resume then "Ready to resume from " + .resume_point.next_step_id
            else .resume_point.halt_reason // "Unknown reason"
            end
        ),
        next_step_id: .resume_point.next_step_id,
        next_micro_action_sequence: .resume_point.next_micro_action_sequence,
        resume_instructions: .resume_point.resume_instructions
    }' "$output_file"
}

# ============================================================================
# RECALCULATE SUMMARY - Update execution summary counts
# ============================================================================
cmd_recalculate_summary() {
    local task_id="${1:-}"

    if [[ -z "$task_id" ]]; then
        return 0
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")

    jq_update "$output_file" '
        .execution_summary.completed_steps = [.steps[] | select(.status == "completed")] | length |
        .execution_summary.failed_steps = [.steps[] | select(.status == "failed")] | length |
        .execution_summary.skipped_steps = [.steps[] | select(.status == "skipped")] | length |
        .execution_summary.pending_steps = [.steps[] | select(.status == "pending")] | length |
        .execution_summary.in_progress_steps = [.steps[] | select(.status == "in_progress")] | length
    '
}

# ============================================================================
# SUMMARY COMMAND - Human-readable summary
# ============================================================================
cmd_summary() {
    local task_id="${1:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Usage: ./build-output.sh summary <task_id>"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")

    if [[ ! -f "$output_file" ]]; then
        log_error "Build output not found: $output_file"
        exit 1
    fi

    # Read key values
    local status goal total completed failed pending
    status=$(jq -r '.status' "$output_file")
    goal=$(jq -r '.goal' "$output_file")
    total=$(jq -r '.execution_summary.total_steps' "$output_file")
    completed=$(jq -r '.execution_summary.completed_steps' "$output_file")
    failed=$(jq -r '.execution_summary.failed_steps' "$output_file")
    pending=$(jq -r '.execution_summary.pending_steps' "$output_file")

    echo ""
    echo -e "${BOLD}BUILD OUTPUT SUMMARY${NC}"
    echo "════════════════════════════════════════════════════════"
    echo -e "${CYAN}Task:${NC}   $task_id"
    echo -e "${CYAN}Goal:${NC}   $goal"
    echo -e "${CYAN}Status:${NC} $status"
    echo ""

    # Progress bar
    local pct=0
    if [[ "$total" -gt 0 ]]; then
        pct=$(( (completed * 100) / total ))
    fi
    local filled=$(( pct / 5 ))
    local empty=$(( 20 - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    echo -e "${CYAN}Progress:${NC} [$bar] $pct% ($completed/$total steps)"
    echo ""
    echo -e "${GREEN}Completed:${NC} $completed  ${RED}Failed:${NC} $failed  ${YELLOW}Pending:${NC} $pending"
    echo ""

    # Resume info
    local can_resume next_step
    can_resume=$(jq -r '.resume_point.can_resume' "$output_file")
    next_step=$(jq -r '.resume_point.next_step_id // "none"' "$output_file")

    if [[ "$can_resume" == "true" ]]; then
        echo -e "${GREEN}Can Resume:${NC} Yes"
        echo -e "${CYAN}Next Step:${NC}  $next_step"
    else
        local halt_reason
        halt_reason=$(jq -r '.resume_point.halt_reason // "N/A"' "$output_file")
        echo -e "${RED}Can Resume:${NC} No"
        echo -e "${CYAN}Reason:${NC}     $halt_reason"
    fi

    echo "════════════════════════════════════════════════════════"
    echo ""
}

# ============================================================================
# ERROR COMMAND - Record error for a step
# ============================================================================
cmd_error() {
    local task_id="${1:-}"
    local step_id="${2:-}"
    local message="${3:-}"
    local error_type="${4:-}"
    local recoverable="${5:-true}"

    if [[ -z "$task_id" || -z "$step_id" || -z "$message" ]]; then
        log_error "Usage: ./build-output.sh error <task_id> <step_id> <message> [type] [recoverable]"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    jq_update "$output_file" --arg step_id "$step_id" --arg msg "$message" --arg type "${error_type:-unknown}" --argjson recoverable "$recoverable" --arg now "$now" '
        (.steps[] | select(.id == $step_id)).errors += [{
            message: $msg,
            type: $type,
            timestamp: $now,
            recoverable: $recoverable,
            recovery_attempted: false,
            recovery_outcome: null
        }] |
        .timestamps.updated_at = $now
    '

    log_success "Recorded error for $step_id"
}

# ============================================================================
# STATUS COMMAND - Update overall build status
# ============================================================================
cmd_status() {
    local task_id="${1:-}"
    local new_status="${2:-}"

    if [[ -z "$task_id" || -z "$new_status" ]]; then
        log_error "Usage: ./build-output.sh status <task_id> <status>"
        exit 1
    fi

    local output_file
    output_file=$(get_build_output_path "$task_id")
    local now
    now=$(now_iso)

    jq_update "$output_file" --arg status "$new_status" --arg now "$now" '
        .status = $status |
        .timestamps.updated_at = $now |
        (if $status == "completed" or $status == "failed" or $status == "aborted" then
            .timestamps.completed_at = $now
        else . end) |
        (if $status == "paused" then
            .timestamps.paused_at = $now
        else . end)
    '

    # Update resume point
    cmd_resume_point "$task_id" > /dev/null

    log_success "Build status: $new_status"
}

# ============================================================================
# HELP COMMAND
# ============================================================================
cmd_help() {
    cat << 'EOF'
STUDIO Build Output Manager
===========================

Manages the consolidated build-output.json file that enables task resumption.

Usage: ./build-output.sh <command> [arguments]

Commands:
  init <task_id>                              Initialize from plan.json
  get <task_id> [jq_path]                     Get build output or specific field
  status <task_id> <status>                   Update overall build status
  step <task_id> <step_id> <status>           Update step status
  micro <task_id> <step_id> <seq> <status>    Update micro-action status
  validate <task_id> <step_id> <idx> <status> Record validation result
  retry <task_id> <step_id> <outcome>         Record retry attempt
  artifact <task_id> <step_id> <path> <type>  Track artifact
  error <task_id> <step_id> <message>         Record error
  quality-gate <task_id> <verdict>            Record quality gate result
  resume-point <task_id>                      Calculate resume point
  can-resume <task_id>                        Check if resumable
  summary <task_id>                           Human-readable summary
  help                                        Show this help

Status Values:
  Build:       pending|in_progress|paused|awaiting_quality_gate|completed|failed|halted|aborted
  Step:        pending|in_progress|completed|failed|skipped
  Micro:       pending|in_progress|completed|failed|skipped
  Validation:  pending|passed|failed|skipped

Examples:
  ./build-output.sh init task_20260201_120000
  ./build-output.sh step task_20260201_120000 step_1 in_progress
  ./build-output.sh micro task_20260201_120000 step_1 1 completed '{"success":true}'
  ./build-output.sh validate task_20260201_120000 step_1 0 passed "PASS"
  ./build-output.sh retry task_20260201_120000 step_2 failed "Connection refused"
  ./build-output.sh artifact task_20260201_120000 step_1 src/auth.ts created
  ./build-output.sh can-resume task_20260201_120000
  ./build-output.sh summary task_20260201_120000

EOF
}

# ============================================================================
# MAIN DISPATCH
# ============================================================================
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init)           cmd_init "$@" ;;
        get)            cmd_get "$@" ;;
        status)         cmd_status "$@" ;;
        step)           cmd_step "$@" ;;
        micro)          cmd_micro "$@" ;;
        validate)       cmd_validate "$@" ;;
        retry)          cmd_retry "$@" ;;
        artifact)       cmd_artifact "$@" ;;
        error)          cmd_error "$@" ;;
        quality-gate)   cmd_quality_gate "$@" ;;
        resume-point)   cmd_resume_point "$@" ;;
        can-resume)     cmd_can_resume "$@" ;;
        summary)        cmd_summary "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            log_error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
