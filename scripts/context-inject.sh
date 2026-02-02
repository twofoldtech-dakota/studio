#!/usr/bin/env bash
# =============================================================================
# Context Injection Script
# =============================================================================
# Implements 4-tier context injection for enterprise project decomposition.
# Manages token budgets and context aging across 50+ tasks.
#
# Tier 0: Invariants     (~5K tokens)  - Never aged
# Tier 1: Active         (~30K tokens) - Last 5 tasks
# Tier 2: Summarized     (~15K tokens) - Tasks 6-20
# Tier 3: Indexed        (~5K tokens)  - Tasks 21+
#
# Usage:
#   ./context-inject.sh --task-id <task_id> [--goal "<goal>"]
#   ./context-inject.sh --update-invariants
#   ./context-inject.sh --summarize
#   ./context-inject.sh --status
#
# Output:
#   JSON context object ready for injection into task execution
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_ROOT="${SCRIPT_DIR}/.."

# =============================================================================
# Configuration
# =============================================================================

# Token budgets per tier
TIER_0_BUDGET=5000
TIER_1_BUDGET=30000
TIER_2_BUDGET=15000
TIER_3_BUDGET=5000
TOTAL_BUDGET=55000  # Leaves ~40K for working space in 95K context

# Retention windows
TIER_1_WINDOW=5     # Last 5 tasks
TIER_2_FROM=6       # Tasks 6-20
TIER_2_TO=20
TIER_3_FROM=21      # Tasks 21+

# File paths
INVARIANTS_FILE="studio/context/invariants.md"
CONTEXT_STATE_FILE=".studio/context-state.json"
LEARNINGS_DIR="studio/learnings"
TASKS_DIR=".studio/tasks"
BACKLOG_FILE=".studio/backlog.json"

# =============================================================================
# Utility Functions
# =============================================================================

estimate_tokens() {
    local text="$1"
    # Rough estimate: ~4 characters per token
    local chars=${#text}
    echo $(( chars / 4 ))
}

compress_to_budget() {
    local content="$1"
    local budget="$2"
    local current_tokens
    current_tokens=$(estimate_tokens "$content")

    if [[ "$current_tokens" -le "$budget" ]]; then
        echo "$content"
        return
    fi

    # Simple truncation with indicator
    local ratio
    ratio=$(echo "scale=2; $budget / $current_tokens" | bc)
    local target_chars
    target_chars=$(echo "scale=0; ${#content} * $ratio * 0.95" | bc | cut -d. -f1)

    echo "${content:0:$target_chars}...[truncated to fit ${budget} token budget]"
}

json_get() {
    local json="$1"
    local path="$2"
    echo "$json" | jq -r "$path // empty"
}

# =============================================================================
# Context Loading Functions
# =============================================================================

load_invariants() {
    local invariants_content=""

    if [[ -f "$INVARIANTS_FILE" ]]; then
        invariants_content=$(cat "$INVARIANTS_FILE")
    fi

    # Compress if needed
    local compressed
    compressed=$(compress_to_budget "$invariants_content" "$TIER_0_BUDGET")

    local tokens
    tokens=$(estimate_tokens "$compressed")

    jq -n \
        --arg content "$compressed" \
        --argjson tokens "$tokens" \
        --argjson budget "$TIER_0_BUDGET" \
        '{
            content: $content,
            tokens_used: $tokens,
            token_budget: $budget,
            source: "studio/context/invariants.md"
        }'
}

detect_domains() {
    local goal="$1"
    local domains="[]"

    # Simple keyword-based domain detection
    if echo "$goal" | grep -qiE "frontend|ui|component|react|vue|css|style|button|form|modal"; then
        domains=$(echo "$domains" | jq '. + ["frontend"]')
    fi

    if echo "$goal" | grep -qiE "backend|api|server|database|endpoint|route|service|query"; then
        domains=$(echo "$domains" | jq '. + ["backend"]')
    fi

    if echo "$goal" | grep -qiE "test|spec|coverage|unit|integration|e2e|playwright"; then
        domains=$(echo "$domains" | jq '. + ["testing"]')
    fi

    if echo "$goal" | grep -qiE "auth|login|password|session|token|oauth|jwt|security|permission"; then
        domains=$(echo "$domains" | jq '. + ["security"]')
    fi

    if echo "$goal" | grep -qiE "performance|speed|optimize|cache|lazy|bundle|lighthouse"; then
        domains=$(echo "$domains" | jq '. + ["performance"]')
    fi

    # Always include global
    domains=$(echo "$domains" | jq '. + ["global"]' | jq 'unique')

    echo "$domains"
}

load_domain_learnings() {
    local domains="$1"
    local combined=""
    local total_tokens=0
    local max_per_domain=$(( TIER_1_BUDGET / 3 ))  # Reserve space

    while IFS= read -r domain; do
        [[ -z "$domain" ]] && continue

        local learning_file="${LEARNINGS_DIR}/${domain}.md"
        if [[ -f "$learning_file" ]]; then
            local content
            content=$(cat "$learning_file")

            # Compress each domain's learnings
            local compressed
            compressed=$(compress_to_budget "$content" "$max_per_domain")

            if [[ -n "$combined" ]]; then
                combined="${combined}\n\n---\n\n"
            fi
            combined="${combined}## ${domain^} Learnings\n\n${compressed}"

            total_tokens=$(( total_tokens + $(estimate_tokens "$compressed") ))
        fi
    done < <(echo "$domains" | jq -r '.[]')

    echo "$combined"
}

load_current_task() {
    local task_id="$1"
    local task_dir="${TASKS_DIR}/${task_id}"

    if [[ ! -d "$task_dir" ]]; then
        echo "{}"
        return
    fi

    local plan_file="${task_dir}/plan.json"
    if [[ -f "$plan_file" ]]; then
        cat "$plan_file"
    else
        echo "{}"
    fi
}

load_adjacent_tasks() {
    local current_task_id="$1"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "[]"
        return
    fi

    local backlog
    backlog=$(cat "$BACKLOG_FILE")

    # Get all tasks in order
    local all_tasks
    all_tasks=$(echo "$backlog" | jq '[.epics[].features[].tasks[]] | sort_by(.created_at)')

    # Find current task index
    local current_index
    current_index=$(echo "$all_tasks" | jq --arg id "$current_task_id" '
        to_entries | map(select(.value.id == $id or .value.short_id == $id)) | .[0].key // -1
    ')

    if [[ "$current_index" == "-1" ]]; then
        echo "[]"
        return
    fi

    # Get previous and next tasks
    local adjacent="[]"

    # Previous task
    if [[ "$current_index" -gt 0 ]]; then
        local prev
        prev=$(echo "$all_tasks" | jq --argjson idx "$current_index" '.[$idx - 1]')
        local prev_summary
        prev_summary=$(echo "$prev" | jq '{
            task_id: .id,
            relationship: "previous",
            name: .name,
            status: .status,
            outputs: (.outputs // [])
        }')
        adjacent=$(echo "$adjacent" | jq --argjson p "$prev_summary" '. + [$p]')
    fi

    # Next task
    local task_count
    task_count=$(echo "$all_tasks" | jq 'length')
    if [[ "$current_index" -lt $(( task_count - 1 )) ]]; then
        local next
        next=$(echo "$all_tasks" | jq --argjson idx "$current_index" '.[$idx + 1]')
        local next_summary
        next_summary=$(echo "$next" | jq '{
            task_id: .id,
            relationship: "next",
            name: .name,
            status: .status,
            inputs: (.inputs // [])
        }')
        adjacent=$(echo "$adjacent" | jq --argjson n "$next_summary" '. + [$n]')
    fi

    echo "$adjacent"
}

load_recent_learnings() {
    local count="$1"
    local domains="$2"

    # This would load learnings from completed tasks
    # For now, return domain-based learnings
    load_domain_learnings "$domains"
}

load_task_summaries() {
    local from_task="$1"
    local to_task="$2"

    if [[ ! -f "$CONTEXT_STATE_FILE" ]]; then
        echo "[]"
        return
    fi

    local state
    state=$(cat "$CONTEXT_STATE_FILE")

    echo "$state" | jq --argjson from "$from_task" --argjson to "$to_task" '
        .tiers.tier_2.content.task_summaries // [] |
        .[$from:$to]
    '
}

load_file_history() {
    local affected_files="$1"

    if [[ ! -f "$CONTEXT_STATE_FILE" ]]; then
        echo "{}"
        return
    fi

    local state
    state=$(cat "$CONTEXT_STATE_FILE")

    # Filter file history to only affected files
    echo "$state" | jq --argjson files "$affected_files" '
        .tiers.tier_3.content.file_history // {} |
        with_entries(select(.key as $k | $files | index($k)))
    '
}

# =============================================================================
# Context Injection Main Function
# =============================================================================

inject_context_for_task() {
    local task_id="$1"
    local goal="${2:-}"

    # Tier 0: Always load invariants
    local invariants
    invariants=$(load_invariants)

    # Detect domains from goal
    local domains="[\"global\"]"
    if [[ -n "$goal" ]]; then
        domains=$(detect_domains "$goal")
    fi

    # Tier 1: Active context
    local current_task
    current_task=$(load_current_task "$task_id")

    local adjacent_tasks
    adjacent_tasks=$(load_adjacent_tasks "$task_id")

    local recent_learnings
    recent_learnings=$(load_recent_learnings "$TIER_1_WINDOW" "$domains")

    # Tier 2: Summarized context
    local task_summaries
    task_summaries=$(load_task_summaries "$TIER_2_FROM" "$TIER_2_TO")

    # Tier 3: Indexed references
    local affected_files="[]"
    if [[ -n "$current_task" && "$current_task" != "{}" ]]; then
        affected_files=$(echo "$current_task" | jq '.steps // [] | map(.outputs // []) | flatten | unique')
    fi

    local file_history
    file_history=$(load_file_history "$affected_files")

    # Calculate token usage
    local tier_0_tokens
    tier_0_tokens=$(echo "$invariants" | jq -r '.tokens_used // 0')

    local tier_1_content="${recent_learnings}"
    local tier_1_tokens
    tier_1_tokens=$(estimate_tokens "$tier_1_content")

    local tier_2_content
    tier_2_content=$(echo "$task_summaries" | jq -r 'tostring')
    local tier_2_tokens
    tier_2_tokens=$(estimate_tokens "$tier_2_content")

    local tier_3_content
    tier_3_content=$(echo "$file_history" | jq -r 'tostring')
    local tier_3_tokens
    tier_3_tokens=$(estimate_tokens "$tier_3_content")

    local total_tokens=$(( tier_0_tokens + tier_1_tokens + tier_2_tokens + tier_3_tokens ))

    # Build context object
    jq -n \
        --arg task_id "$task_id" \
        --argjson domains "$domains" \
        --argjson invariants "$invariants" \
        --argjson current_task "$current_task" \
        --argjson adjacent "$adjacent_tasks" \
        --arg learnings "$recent_learnings" \
        --argjson summaries "$task_summaries" \
        --argjson file_history "$file_history" \
        --argjson tier_0_tokens "$tier_0_tokens" \
        --argjson tier_1_tokens "$tier_1_tokens" \
        --argjson tier_2_tokens "$tier_2_tokens" \
        --argjson tier_3_tokens "$tier_3_tokens" \
        --argjson total_tokens "$total_tokens" \
        --argjson total_budget "$TOTAL_BUDGET" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            task_id: $task_id,
            domains_detected: $domains,
            injected_at: $timestamp,
            tiers: {
                tier_0_invariants: $invariants,
                tier_1_active: {
                    current_task: $current_task,
                    adjacent_tasks: $adjacent,
                    learnings: $learnings,
                    tokens_used: $tier_1_tokens
                },
                tier_2_summarized: {
                    task_summaries: $summaries,
                    tokens_used: $tier_2_tokens
                },
                tier_3_indexed: {
                    file_history: $file_history,
                    tokens_used: $tier_3_tokens
                }
            },
            token_usage: {
                tier_0: $tier_0_tokens,
                tier_1: $tier_1_tokens,
                tier_2: $tier_2_tokens,
                tier_3: $tier_3_tokens,
                total: $total_tokens,
                budget: $total_budget,
                utilization: (($total_tokens / $total_budget) * 100 | floor / 100)
            }
        }'
}

# =============================================================================
# Summarization and State Management
# =============================================================================

update_invariants() {
    local new_invariant="$1"
    local invariant_type="$2"  # architectural_decision, constraint, pattern, convention

    if [[ ! -f "$INVARIANTS_FILE" ]]; then
        echo "Error: Invariants file not found at $INVARIANTS_FILE" >&2
        exit 1
    fi

    # This would append to the invariants file
    # For now, just output what would be added
    echo "Would add $invariant_type: $new_invariant"
    echo "To: $INVARIANTS_FILE"
}

summarize_task() {
    local task_id="$1"
    local task_dir="${TASKS_DIR}/${task_id}"

    if [[ ! -d "$task_dir" ]]; then
        echo "Error: Task directory not found: $task_dir" >&2
        exit 1
    fi

    # Load task details
    local plan_file="${task_dir}/plan.json"
    if [[ ! -f "$plan_file" ]]; then
        echo "Error: Plan file not found for task $task_id" >&2
        exit 1
    fi

    local plan
    plan=$(cat "$plan_file")

    # Create summary
    local summary
    summary=$(jq -n \
        --arg task_id "$task_id" \
        --arg goal "$(echo "$plan" | jq -r '.goal // ""')" \
        --argjson steps "$(echo "$plan" | jq '.steps | length')" \
        '{
            task_id: $task_id,
            summary: ("Completed: " + $goal),
            outcome: "success",
            key_decisions: [],
            files_affected: [],
            patterns_discovered: []
        }')

    echo "$summary"
}

trigger_summarization() {
    # Check if summarization is needed
    local current_task_count=0

    if [[ -f "$CONTEXT_STATE_FILE" ]]; then
        current_task_count=$(jq -r '.current_state.total_tasks_completed // 0' "$CONTEXT_STATE_FILE")
    fi

    local last_summarization=0
    if [[ -f "$CONTEXT_STATE_FILE" ]]; then
        last_summarization=$(jq -r '.current_state.last_summarization_at_task // 0' "$CONTEXT_STATE_FILE")
    fi

    # Trigger if more than 5 tasks since last summarization
    if [[ $(( current_task_count - last_summarization )) -ge 5 ]]; then
        echo "Summarization triggered: $(( current_task_count - last_summarization )) tasks since last run"
        # Would run actual summarization here
    else
        echo "No summarization needed"
    fi
}

get_status() {
    if [[ ! -f "$CONTEXT_STATE_FILE" ]]; then
        echo "No context state found. Run --task-id to initialize."
        exit 0
    fi

    local state
    state=$(cat "$CONTEXT_STATE_FILE")

    echo "$state" | jq '{
        total_tasks_completed: .current_state.total_tasks_completed,
        current_task_number: .current_state.current_task_number,
        token_usage: .token_usage,
        last_updated: .updated_at
    }'
}

# =============================================================================
# CLI Interface
# =============================================================================

usage() {
    cat << EOF
Context Injection Script

Usage:
    $(basename "$0") --task-id <task_id> [--goal "<goal>"]
        Inject context for a specific task

    $(basename "$0") --update-invariants "<invariant>" --type <type>
        Add a new invariant (types: architectural_decision, constraint, pattern, convention)

    $(basename "$0") --summarize --task-id <task_id>
        Create summary for a completed task

    $(basename "$0") --trigger-summarization
        Check and trigger context summarization if needed

    $(basename "$0") --status
        Show current context state

    $(basename "$0") --help
        Show this help message

Token Budgets:
    Tier 0 (Invariants):  ${TIER_0_BUDGET} tokens (never aged)
    Tier 1 (Active):      ${TIER_1_BUDGET} tokens (last ${TIER_1_WINDOW} tasks)
    Tier 2 (Summarized):  ${TIER_2_BUDGET} tokens (tasks ${TIER_2_FROM}-${TIER_2_TO})
    Tier 3 (Indexed):     ${TIER_3_BUDGET} tokens (tasks ${TIER_3_FROM}+)
    Total Budget:         ${TOTAL_BUDGET} tokens

EOF
}

main() {
    local task_id=""
    local goal=""
    local invariant=""
    local invariant_type=""
    local action=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                usage
                exit 0
                ;;
            --task-id)
                task_id="$2"
                if [[ -z "$action" ]]; then
                    action="inject"
                fi
                shift 2
                ;;
            --goal)
                goal="$2"
                shift 2
                ;;
            --update-invariants)
                action="update-invariants"
                invariant="$2"
                shift 2
                ;;
            --type)
                invariant_type="$2"
                shift 2
                ;;
            --summarize)
                action="summarize"
                shift
                ;;
            --trigger-summarization)
                action="trigger-summarization"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                exit 1
                ;;
        esac
    done

    # Execute action
    case "$action" in
        inject)
            if [[ -z "$task_id" ]]; then
                echo "Error: --task-id required for context injection" >&2
                exit 1
            fi
            inject_context_for_task "$task_id" "$goal"
            ;;
        update-invariants)
            if [[ -z "$invariant" || -z "$invariant_type" ]]; then
                echo "Error: --update-invariants requires invariant text and --type" >&2
                exit 1
            fi
            update_invariants "$invariant" "$invariant_type"
            ;;
        summarize)
            if [[ -z "$task_id" ]]; then
                echo "Error: --task-id required for summarization" >&2
                exit 1
            fi
            summarize_task "$task_id"
            ;;
        trigger-summarization)
            trigger_summarization
            ;;
        status)
            get_status
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# Run main if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
