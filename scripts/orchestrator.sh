#!/usr/bin/env bash
#
# STUDIO Orchestrator Utilities - Multi-Agent Workflow Coordination
# ==================================================================
#
# This script provides state management utilities for the orchestrator agent.
# Handles routing, state persistence, checkpoints, and failure recovery.
#
# Usage:
#   ./orchestrator.sh init <goal>                    Initialize orchestration session
#   ./orchestrator.sh state [session_id]             Get current state
#   ./orchestrator.sh route <goal>                   Analyze and route goal
#   ./orchestrator.sh agent-start <agent>            Mark agent as started
#   ./orchestrator.sh agent-complete <agent>         Mark agent as completed
#   ./orchestrator.sh agent-fail <agent> <error>     Mark agent as failed
#   ./orchestrator.sh checkpoint <name>              Save checkpoint
#   ./orchestrator.sh resume [checkpoint]            Resume from checkpoint
#   ./orchestrator.sh handoff <from> <to> <context>  Record agent handoff
#   ./orchestrator.sh status                         Show orchestration status
#   ./orchestrator.sh cleanup [session_id]           Clean up session
#
# Environment:
#   STUDIO_DIR       Base directory for STUDIO state (default: .studio)
#   ORCH_SESSION_ID  Current orchestration session ID
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-.studio}"
ORCH_DIR="${STUDIO_DIR}/orchestration"
CURRENT_SESSION_FILE="${ORCH_DIR}/.current"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' BOLD='' DIM='' NC=''
fi

# Logging
log_orch() { echo -e "${MAGENTA}[Orchestrator]${NC} $*"; }
log_success() { echo -e "${GREEN}[Orchestrator]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[Orchestrator]${NC} $*" >&2; }
log_error() { echo -e "${RED}[Orchestrator]${NC} $*" >&2; }

# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

# Generate session ID
generate_session_id() {
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local random
    random=$(head -c 2 /dev/urandom | xxd -p)
    echo "orch_${timestamp}_${random}"
}

# Get current session ID
get_current_session() {
    if [[ -n "${ORCH_SESSION_ID:-}" ]]; then
        echo "$ORCH_SESSION_ID"
    elif [[ -f "$CURRENT_SESSION_FILE" ]]; then
        cat "$CURRENT_SESSION_FILE"
    else
        echo ""
    fi
}

# Set current session
set_current_session() {
    local session_id="${1:-}"
    mkdir -p "$ORCH_DIR"
    echo "$session_id" > "$CURRENT_SESSION_FILE"
}

# Get session directory
get_session_dir() {
    local session_id="${1:-$(get_current_session)}"
    echo "${ORCH_DIR}/${session_id}"
}

# ============================================================================
# INITIALIZATION
# ============================================================================

# Initialize a new orchestration session
cmd_init() {
    local goal="${1:-}"
    local mode="${2:-implicit}"

    if [[ -z "$goal" ]]; then
        log_error "Usage: orchestrator.sh init <goal> [mode]"
        exit 1
    fi

    local session_id
    session_id=$(generate_session_id)
    local session_dir
    session_dir=$(get_session_dir "$session_id")

    mkdir -p "$session_dir"
    mkdir -p "${STUDIO_DIR}/tasks"

    # Create initial state
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "${session_dir}/state.json" << EOF
{
  "id": "${session_id}",
  "mode": "${mode}",
  "trigger": "build_command",
  "status": "initializing",
  "created_at": "${now}",
  "updated_at": "${now}",
  "goal": $(echo "$goal" | jq -R .),
  "routing": {
    "analyzed_goal": null,
    "selected_workflow": null,
    "agent_sequence": [],
    "routing_confidence": 0
  },
  "context_budget": {
    "total_allocated": 150000,
    "pools": {},
    "pressure_level": "normal",
    "optimization_triggered": false
  },
  "agent_states": [],
  "handoffs": [],
  "checkpoints": [],
  "failures": [],
  "outcome": null
}
EOF

    set_current_session "$session_id"

    log_success "Orchestration session initialized: $session_id"
    echo "$session_id"
}

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

# Get current state
cmd_state() {
    local session_id="${1:-$(get_current_session)}"

    if [[ -z "$session_id" ]]; then
        log_error "No active session. Run 'orchestrator.sh init' first."
        exit 1
    fi

    local session_dir
    session_dir=$(get_session_dir "$session_id")

    if [[ ! -f "${session_dir}/state.json" ]]; then
        log_error "Session not found: $session_id"
        exit 1
    fi

    cat "${session_dir}/state.json"
}

# Update state field
update_state() {
    local session_id="${1:-$(get_current_session)}"
    local field="${2:-}"
    local value="${3:-}"

    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Session not found: $session_id"
        exit 1
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update field and timestamp
    local tmp_file
    tmp_file=$(mktemp)
    jq --arg field "$field" --argjson value "$value" --arg now "$now" \
        '.[$field] = $value | .updated_at = $now' \
        "$state_file" > "$tmp_file" && mv "$tmp_file" "$state_file"
}

# ============================================================================
# ROUTING
# ============================================================================

# Analyze goal and determine routing
cmd_route() {
    local goal="${1:-}"
    local session_id
    session_id=$(get_current_session)

    if [[ -z "$goal" ]]; then
        # Get from state
        goal=$(cmd_state | jq -r '.goal // empty')
    fi

    if [[ -z "$goal" ]]; then
        log_error "No goal provided"
        exit 1
    fi

    local goal_lower
    goal_lower=$(echo "$goal" | tr '[:upper:]' '[:lower:]')

    # Determine workflow based on goal analysis
    local workflow="plan_then_build"
    local agents='["planner", "builder"]'
    local confidence=0.8

    # Simple heuristics for routing
    if echo "$goal_lower" | grep -qE "(fix|bug|error|typo)"; then
        # Quick fixes might not need full planning
        workflow="build_only"
        agents='["builder"]'
        confidence=0.7
    elif echo "$goal_lower" | grep -qE "(refactor|reorganize|restructure)"; then
        # Refactoring needs careful planning
        workflow="plan_then_build"
        agents='["planner", "builder"]'
        confidence=0.9
    elif echo "$goal_lower" | grep -qE "(add|create|implement|build)"; then
        # New features need full workflow
        workflow="plan_then_build"
        agents='["planner", "builder"]'
        confidence=0.85
    fi

    # Build agent sequence
    local agent_sequence="[]"
    local order=1
    for agent in $(echo "$agents" | jq -r '.[]'); do
        agent_sequence=$(echo "$agent_sequence" | jq \
            --arg agent "$agent" \
            --argjson order "$order" \
            '. + [{"agent": $agent, "order": $order, "status": "pending", "reason": null}]')
        ((order++))
    done

    # Update routing in state
    local routing
    routing=$(jq -n \
        --arg goal "$goal" \
        --arg workflow "$workflow" \
        --argjson agents "$agent_sequence" \
        --argjson conf "$confidence" \
        '{
            "analyzed_goal": $goal,
            "selected_workflow": $workflow,
            "agent_sequence": $agents,
            "routing_confidence": $conf
        }')

    update_state "$session_id" "routing" "$routing"
    update_state "$session_id" "status" '"routing"'

    log_orch "Routed to workflow: $workflow (confidence: $confidence)"
    echo "$routing" | jq .
}

# ============================================================================
# AGENT LIFECYCLE
# ============================================================================

# Mark agent as started
cmd_agent_start() {
    local agent="${1:-}"

    if [[ -z "$agent" ]]; then
        log_error "Usage: orchestrator.sh agent-start <agent>"
        exit 1
    fi

    local session_id
    session_id=$(get_current_session)
    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update agent in routing sequence
    jq --arg agent "$agent" --arg now "$now" \
        '(.routing.agent_sequence[] | select(.agent == $agent)) |=
         . + {"status": "active", "started_at": $now}' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    # Add to agent_states if not present
    local invocation_id="${agent}_$(date +%s)"
    jq --arg agent "$agent" --arg now "$now" --arg inv_id "$invocation_id" \
        '.agent_states += [{
            "agent_name": $agent,
            "invocation_id": $inv_id,
            "status": "active",
            "started_at": $now,
            "completed_at": null,
            "input": {},
            "output": null,
            "context_used": 0,
            "error": null
        }] | .status = "executing" | .updated_at = $now' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    log_orch "Agent started: $agent"
}

# Mark agent as completed
cmd_agent_complete() {
    local agent="${1:-}"
    local output="${2:-}"

    # Default to empty object if not provided
    if [[ -z "$output" ]]; then
        output='{}'
    fi

    if [[ -z "$agent" ]]; then
        log_error "Usage: orchestrator.sh agent-complete <agent> [output_json]"
        exit 1
    fi

    local session_id
    session_id=$(get_current_session)
    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update routing sequence
    jq --arg agent "$agent" --arg now "$now" \
        '(.routing.agent_sequence[] | select(.agent == $agent)) |=
         . + {"status": "completed", "completed_at": $now}' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    # Use a temp file for the output to avoid shell escaping issues
    local output_file
    output_file=$(mktemp)
    printf '%s' "$output" > "$output_file"

    # Validate output is valid JSON, default to empty object
    if ! jq . "$output_file" >/dev/null 2>&1; then
        printf '{}' > "$output_file"
    fi

    # Update agent_states
    jq --arg agent "$agent" --arg now "$now" --slurpfile out "$output_file" \
        '(.agent_states[] | select(.agent_name == $agent and .status == "active")) |=
         . + {"status": "completed", "completed_at": $now, "output": $out[0]} | .updated_at = $now' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    rm -f "$output_file"
    log_success "Agent completed: $agent"
}

# Mark agent as failed
cmd_agent_fail() {
    local agent="${1:-}"
    local error="${2:-Unknown error}"

    if [[ -z "$agent" ]]; then
        log_error "Usage: orchestrator.sh agent-fail <agent> <error_message>"
        exit 1
    fi

    local session_id
    session_id=$(get_current_session)
    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update routing sequence
    jq --arg agent "$agent" \
        '(.routing.agent_sequence[] | select(.agent == $agent)) |=
         . + {"status": "failed"}' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    # Update agent_states
    jq --arg agent "$agent" --arg now "$now" --arg error "$error" \
        '(.agent_states[] | select(.agent_name == $agent and .status == "active")) |=
         . + {"status": "failed", "completed_at": $now, "error": $error} |
         .status = "recovering" | .updated_at = $now' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    # Add to failures
    jq --arg agent "$agent" --arg now "$now" --arg error "$error" \
        '.failures += [{
            "timestamp": $now,
            "agent": $agent,
            "error_type": "recoverable",
            "error_message": $error,
            "recovery_action": null,
            "recovery_successful": null,
            "retry_count": 0
        }]' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    log_error "Agent failed: $agent - $error"
}

# ============================================================================
# CHECKPOINTS
# ============================================================================

# Save checkpoint
cmd_checkpoint() {
    local name="${1:-checkpoint}"

    local session_id
    session_id=$(get_current_session)
    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local checkpoint_id="cp_$(date +%s)"

    # Get current state
    local state
    state=$(cat "$state_file")

    # Find last completed agent
    local last_agent
    last_agent=$(echo "$state" | jq -r '.routing.agent_sequence | map(select(.status == "completed")) | last | .agent // "none"')

    # Add checkpoint
    jq --arg id "$checkpoint_id" --arg name "$name" --arg now "$now" --arg agent "$last_agent" \
        '.checkpoints += [{
            "id": $id,
            "name": $name,
            "timestamp": $now,
            "after_agent": $agent,
            "state": .,
            "can_resume_from": true
        }] | .updated_at = $now' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    # Save checkpoint file
    cp "$state_file" "${session_dir}/${checkpoint_id}.json"

    log_success "Checkpoint saved: $name ($checkpoint_id)"
    echo "$checkpoint_id"
}

# Resume from checkpoint
cmd_resume() {
    local checkpoint="${1:-}"

    local session_id
    session_id=$(get_current_session)
    local session_dir
    session_dir=$(get_session_dir "$session_id")

    if [[ -z "$checkpoint" ]]; then
        # Find latest checkpoint
        checkpoint=$(jq -r '.checkpoints | last | .id // empty' "${session_dir}/state.json")
    fi

    if [[ -z "$checkpoint" ]]; then
        log_error "No checkpoint found"
        exit 1
    fi

    local checkpoint_file="${session_dir}/${checkpoint}.json"

    if [[ ! -f "$checkpoint_file" ]]; then
        log_error "Checkpoint file not found: $checkpoint"
        exit 1
    fi

    # Restore state from checkpoint
    local checkpoint_state
    checkpoint_state=$(jq '.checkpoints[-1].state' "$checkpoint_file")

    # Update status to paused for resume
    echo "$checkpoint_state" | jq '.status = "paused"' > "${session_dir}/state.json"

    log_success "Resumed from checkpoint: $checkpoint"
}

# ============================================================================
# HANDOFFS
# ============================================================================

# Record agent handoff
cmd_handoff() {
    local from="${1:-}"
    local to="${2:-}"
    local context="${3:-}"

    # Default to empty object if not provided
    if [[ -z "$context" ]]; then
        context='{}'
    fi

    if [[ -z "$from" || -z "$to" ]]; then
        log_error "Usage: orchestrator.sh handoff <from_agent> <to_agent> [context_json]"
        exit 1
    fi

    local session_id
    session_id=$(get_current_session)
    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Use a temp file for the context to avoid shell escaping issues
    local context_file
    context_file=$(mktemp)
    printf '%s' "$context" > "$context_file"

    # Validate context is valid JSON, default to empty object
    if ! jq . "$context_file" >/dev/null 2>&1; then
        log_warn "Invalid JSON context, using empty object"
        printf '{}' > "$context_file"
    fi

    jq --arg from "$from" --arg to "$to" --arg now "$now" --slurpfile ctx "$context_file" \
        '.handoffs += [{
            "from_agent": $from,
            "to_agent": $to,
            "timestamp": $now,
            "context_passed": $ctx[0],
            "reason": "workflow_sequence"
        }] | .updated_at = $now' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    rm -f "$context_file"
    log_orch "Handoff: $from -> $to"
}

# Get handoff context for an agent
cmd_get_handoff() {
    local agent="${1:-}"

    if [[ -z "$agent" ]]; then
        log_error "Usage: orchestrator.sh get-handoff <agent>"
        exit 1
    fi

    local session_id
    session_id=$(get_current_session)

    if [[ -z "$session_id" ]]; then
        # No active session, no handoff
        echo "{}"
        return 0
    fi

    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    if [[ ! -f "$state_file" ]]; then
        echo "{}"
        return 0
    fi

    # Find the most recent handoff TO this agent
    local handoff
    handoff=$(jq --arg agent "$agent" \
        '[.handoffs[] | select(.to_agent == $agent)] | last // empty' \
        "$state_file")

    if [[ -z "$handoff" || "$handoff" == "null" ]]; then
        echo "{}"
        return 0
    fi

    # Return the context_passed from the handoff
    echo "$handoff" | jq '.context_passed // {}'
}

# ============================================================================
# FAILURE RECOVERY
# ============================================================================

# Determine recovery action based on failure count
cmd_recover() {
    local agent="${1:-}"

    local session_id
    session_id=$(get_current_session)

    if [[ -z "$session_id" ]]; then
        log_error "No active session"
        exit 1
    fi

    local session_dir
    session_dir=$(get_session_dir "$session_id")
    local state_file="${session_dir}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "Session state not found"
        exit 1
    fi

    # Count failures for this agent (or all if not specified)
    local failure_count
    if [[ -n "$agent" ]]; then
        failure_count=$(jq --arg agent "$agent" \
            '[.failures[] | select(.agent == $agent)] | length' \
            "$state_file")
    else
        failure_count=$(jq '.failures | length' "$state_file")
    fi

    local action
    local reason

    if [[ $failure_count -lt 3 ]]; then
        action="retry"
        reason="Failure count ($failure_count) below retry threshold (3)"
    elif [[ $failure_count -lt 5 ]]; then
        action="replan"
        reason="Failure count ($failure_count) exceeded retry threshold, attempting replan"
    else
        action="escalate"
        reason="Failure count ($failure_count) exceeded all thresholds, escalating to user"
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Update the most recent failure with recovery action
    jq --arg action "$action" --arg now "$now" \
        '(.failures[-1].recovery_action) = $action | .updated_at = $now' \
        "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

    # Output decision
    jq -n \
        --arg action "$action" \
        --arg reason "$reason" \
        --argjson count "$failure_count" \
        '{
            "action": $action,
            "reason": $reason,
            "failure_count": $count,
            "thresholds": {
                "retry_max": 3,
                "replan_max": 5
            }
        }'

    log_orch "Recovery decision: $action ($reason)"
}

# ============================================================================
# STATUS
# ============================================================================

# Show orchestration status
cmd_status() {
    local session_id
    session_id=$(get_current_session)

    if [[ -z "$session_id" ]]; then
        echo ""
        echo -e "${YELLOW}No active orchestration session${NC}"
        echo ""
        return
    fi

    local state
    state=$(cmd_state 2>/dev/null || echo '{}')

    if [[ "$state" == "{}" ]]; then
        log_error "Could not read session state"
        return 1
    fi

    echo ""
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${MAGENTA}            ORCHESTRATION STATUS                        ${NC}"
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "Session:  ${CYAN}$(echo "$state" | jq -r '.id')${NC}"
    echo -e "Mode:     $(echo "$state" | jq -r '.mode')"
    echo -e "Status:   ${BOLD}$(echo "$state" | jq -r '.status')${NC}"
    echo -e "Goal:     $(echo "$state" | jq -r '.goal' | head -c 60)..."
    echo ""

    echo -e "${BOLD}Workflow:${NC} $(echo "$state" | jq -r '.routing.selected_workflow // "not routed"')"
    echo -e "${BOLD}Confidence:${NC} $(echo "$state" | jq -r '.routing.routing_confidence // 0')"
    echo ""

    echo -e "${BOLD}Agent Sequence:${NC}"
    echo "$state" | jq -r '.routing.agent_sequence[]? | "  [\(.status | if . == "completed" then "✓" elif . == "active" then "⟳" elif . == "failed" then "✗" else "○" end)] \(.agent)"'

    local failures
    failures=$(echo "$state" | jq '.failures | length')
    if [[ "$failures" -gt 0 ]]; then
        echo ""
        echo -e "${RED}Failures: $failures${NC}"
        echo "$state" | jq -r '.failures[]? | "  - \(.agent): \(.error_message)"'
    fi

    local checkpoints
    checkpoints=$(echo "$state" | jq '.checkpoints | length')
    if [[ "$checkpoints" -gt 0 ]]; then
        echo ""
        echo -e "${GREEN}Checkpoints: $checkpoints${NC}"
        echo "$state" | jq -r '.checkpoints[]? | "  - \(.name) (\(.id))"'
    fi

    echo ""
}

# ============================================================================
# CLEANUP
# ============================================================================

# Clean up session
cmd_cleanup() {
    local session_id="${1:-$(get_current_session)}"

    if [[ -z "$session_id" ]]; then
        log_warn "No session to clean up"
        return
    fi

    local session_dir
    session_dir=$(get_session_dir "$session_id")

    if [[ -d "$session_dir" ]]; then
        rm -rf "$session_dir"
        log_success "Cleaned up session: $session_id"
    fi

    # Clear current session if it matches
    local current
    current=$(get_current_session)
    if [[ "$current" == "$session_id" ]]; then
        rm -f "$CURRENT_SESSION_FILE"
    fi
}

# ============================================================================
# HELP
# ============================================================================

cmd_help() {
    cat << 'EOF'
STUDIO Orchestrator Utilities - Multi-Agent Workflow Coordination
==================================================================

Manages orchestration sessions, agent lifecycle, and failure recovery.

Usage: orchestrator.sh <command> [arguments]

Session Commands:
  init <goal> [mode]           Initialize orchestration (mode: implicit/explicit)
  state [session_id]           Get current session state
  status                       Show orchestration status
  cleanup [session_id]         Clean up session

Routing Commands:
  route <goal>                 Analyze goal and determine agent routing

Agent Lifecycle:
  agent-start <agent>          Mark agent as started
  agent-complete <agent> [out] Mark agent as completed with output
  agent-fail <agent> <error>   Mark agent as failed

State Management:
  checkpoint <name>            Save checkpoint
  resume [checkpoint_id]       Resume from checkpoint
  handoff <from> <to> [ctx]    Record agent handoff
  get-handoff <agent>          Get incoming handoff context for agent

Failure Recovery:
  recover [agent]              Determine recovery action (retry/replan/escalate)
                               Based on failure count thresholds:
                               - <3 failures: retry
                               - 3-4 failures: replan
                               - 5+ failures: escalate

Environment Variables:
  STUDIO_DIR        Base directory for STUDIO state (default: .studio)
  ORCH_SESSION_ID   Override current session ID

Examples:
  ./orchestrator.sh init "Add user authentication"
  ./orchestrator.sh route
  ./orchestrator.sh agent-start planner
  ./orchestrator.sh agent-complete planner '{"plan_id": "bp_xxx"}'
  ./orchestrator.sh handoff planner builder '{"task_id": "task_xxx"}'
  ./orchestrator.sh get-handoff builder
  ./orchestrator.sh checkpoint "planning_complete"
  ./orchestrator.sh agent-fail builder "Test failures"
  ./orchestrator.sh recover builder
  ./orchestrator.sh status

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init)           cmd_init "$@" ;;
        state)          cmd_state "$@" ;;
        route)          cmd_route "$@" ;;
        agent-start)    cmd_agent_start "$@" ;;
        agent-complete) cmd_agent_complete "$@" ;;
        agent-fail)     cmd_agent_fail "$@" ;;
        checkpoint)     cmd_checkpoint "$@" ;;
        resume)         cmd_resume "$@" ;;
        handoff)        cmd_handoff "$@" ;;
        get-handoff)    cmd_get_handoff "$@" ;;
        recover)        cmd_recover "$@" ;;
        status)         cmd_status "$@" ;;
        cleanup)        cmd_cleanup "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            log_error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
