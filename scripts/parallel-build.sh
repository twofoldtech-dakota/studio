#!/usr/bin/env bash
# ============================================================================
# parallel-build.sh - Parallel Task Execution
# ============================================================================
# Executes independent tasks concurrently using background jobs.
# Uses dependency-graph.sh to identify parallel batches.
#
# Usage:
#   ./scripts/parallel-build.sh --backlog                  # Build all ready tasks
#   ./scripts/parallel-build.sh --tasks T1,T2,T3           # Build specific tasks
#   ./scripts/parallel-build.sh --feature F1               # Build feature tasks
#   ./scripts/parallel-build.sh --max-parallel 4           # Limit concurrency
#
# Exit codes:
#   0 - All tasks completed successfully
#   1 - One or more tasks failed
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
MAX_PARALLEL="${MAX_PARALLEL:-4}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Cross-platform millisecond timestamp
get_timestamp_ms() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perl -MTime::HiRes=time -e 'printf "%d", time * 1000' 2>/dev/null || echo $(($(date +%s) * 1000))
    else
        echo $(($(date +%s%N) / 1000000))
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
parallel-build.sh - Parallel Task Execution

USAGE:
    ./scripts/parallel-build.sh --backlog                  # Build all ready tasks
    ./scripts/parallel-build.sh --tasks T1,T2,T3           # Build specific tasks
    ./scripts/parallel-build.sh --feature F1               # Build feature tasks
    ./scripts/parallel-build.sh --max-parallel 4           # Limit concurrency

OPTIONS:
    --backlog            Build all tasks with PENDING status in backlog
    --tasks <list>       Comma-separated list of task IDs
    --feature <id>       Build all tasks in a feature
    --max-parallel <n>   Maximum concurrent builds (default: 4)
    --dry-run            Show what would be built without building
    --json               Output results as JSON
    --help               Show this help

BATCHING:
    Tasks are grouped into parallel batches based on dependencies.
    Tasks with no dependencies run first. As tasks complete, 
    dependent tasks become eligible.

EXAMPLES:
    # Build all pending backlog tasks in parallel
    ./scripts/parallel-build.sh --backlog

    # Build 3 tasks with max 2 concurrent
    ./scripts/parallel-build.sh --tasks T1,T2,T3 --max-parallel 2

    # Dry run to see execution plan
    ./scripts/parallel-build.sh --backlog --dry-run
EOF
}

# ============================================================================
# DEPENDENCY GRAPH
# ============================================================================

# Get tasks in parallel batches
get_parallel_batches() {
    local tasks_json="$1"
    
    # If dependency-graph.sh exists, use it
    if [[ -x "${SCRIPT_DIR}/dependency-graph.sh" ]]; then
        echo "$tasks_json" | "${SCRIPT_DIR}/dependency-graph.sh" parallel-batches 2>/dev/null || \
            echo "[$(echo "$tasks_json" | jq -r '.[]')]"  # Fallback: all in one batch
    else
        # Simple fallback: put all tasks in one batch
        echo "[$(echo "$tasks_json" | jq -r '.[]')]"
    fi
}

# Get pending tasks from backlog
get_pending_tasks() {
    local backlog_file="${STUDIO_DIR}/backlog.json"
    
    if [[ ! -f "$backlog_file" ]]; then
        echo "[]"
        return
    fi
    
    jq '[.. | objects | select(.status == "PENDING") | .id // empty] | unique' "$backlog_file" 2>/dev/null || echo "[]"
}

# Get tasks for a feature
get_feature_tasks() {
    local feature_id="$1"
    local backlog_file="${STUDIO_DIR}/backlog.json"
    
    if [[ ! -f "$backlog_file" ]]; then
        echo "[]"
        return
    fi
    
    jq --arg fid "$feature_id" \
        '[.features[] | select(.id == $fid) | .tasks[].id] // []' \
        "$backlog_file" 2>/dev/null || echo "[]"
}

# ============================================================================
# TASK EXECUTION
# ============================================================================

# Execute a single task (called as background job)
execute_task() {
    local task_id="$1"
    local output_dir="$2"
    
    local start_time end_time duration
    start_time=$(get_timestamp_ms)
    
    local log_file="${output_dir}/${task_id}.log"
    local result_file="${output_dir}/${task_id}.result"
    
    # Find plan file
    local plan_file="${STUDIO_DIR}/tasks/${task_id}/plan.json"
    if [[ ! -f "$plan_file" ]]; then
        # Try backlog format
        plan_file=$(find "${STUDIO_DIR}" -name "plan.json" -path "*/${task_id}/*" 2>/dev/null | head -1)
    fi
    
    if [[ -z "$plan_file" || ! -f "$plan_file" ]]; then
        echo "{\"task_id\": \"$task_id\", \"status\": \"failed\", \"error\": \"Plan not found\"}" > "$result_file"
        return 1
    fi
    
    # Execute build (this would normally call the build agent)
    # For now, we simulate by running validation + AC verification
    local status="success"
    local error=""
    
    {
        echo "=== Building task: $task_id ==="
        echo "Plan: $plan_file"
        echo ""
        
        # Validate plan
        if ! "${SCRIPT_DIR}/validate-plan.sh" --plan-file "$plan_file" 2>&1; then
            status="failed"
            error="Plan validation failed"
        fi
        
    } > "$log_file" 2>&1
    
    end_time=$(get_timestamp_ms)
    duration=$((end_time - start_time))
    
    # Write result
    jq -n \
        --arg task_id "$task_id" \
        --arg status "$status" \
        --arg error "$error" \
        --argjson duration "$duration" \
        '{task_id: $task_id, status: $status, error: (if $error == "" then null else $error end), duration_ms: $duration}' \
        > "$result_file"
    
    [[ "$status" == "success" ]]
}

# Execute batch of tasks in parallel
execute_batch() {
    local batch_json="$1"
    local output_dir="$2"
    local max_parallel="$3"
    local dry_run="$4"
    
    local tasks
    tasks=$(echo "$batch_json" | jq -r '.[]')
    
    if [[ -z "$tasks" ]]; then
        return 0
    fi
    
    local pids=()
    local task_pids=()
    local running=0
    
    for task_id in $tasks; do
        if [[ "$dry_run" == "true" ]]; then
            echo -e "  ${BLUE}○${NC} Would build: $task_id"
            continue
        fi
        
        # Wait if we've hit max parallel
        while [[ $running -ge $max_parallel ]]; do
            # Wait for any job to complete
            wait -n 2>/dev/null || true
            running=$((running - 1))
        done
        
        echo -e "  ${CYAN}▶${NC} Starting: $task_id"
        
        # Start task in background
        execute_task "$task_id" "$output_dir" &
        pids+=($!)
        task_pids+=("$task_id:$!")
        running=$((running + 1))
    done
    
    # Wait for all tasks to complete
    local failed=0
    for pid in "${pids[@]:-}"; do
        if ! wait "$pid" 2>/dev/null; then
            failed=$((failed + 1))
        fi
    done
    
    return $failed
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local mode=""
    local tasks_input=""
    local feature_id=""
    local max_parallel="$MAX_PARALLEL"
    local dry_run="false"
    local json_only="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --backlog) mode="backlog"; shift ;;
            --tasks) tasks_input="$2"; shift 2 ;;
            --feature) feature_id="$2"; mode="feature"; shift 2 ;;
            --max-parallel) max_parallel="$2"; shift 2 ;;
            --dry-run) dry_run="true"; shift ;;
            --json) json_only="true"; shift ;;
            --help|-h) show_help; exit 0 ;;
            *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
        esac
    done
    
    # Get tasks to build
    local tasks_json="[]"
    
    if [[ -n "$tasks_input" ]]; then
        # Convert comma-separated to JSON array
        tasks_json=$(echo "$tasks_input" | tr ',' '\n' | jq -R . | jq -s .)
    elif [[ "$mode" == "backlog" ]]; then
        tasks_json=$(get_pending_tasks)
    elif [[ "$mode" == "feature" ]]; then
        tasks_json=$(get_feature_tasks "$feature_id")
    else
        echo "Error: Must specify --backlog, --tasks, or --feature" >&2
        show_help
        exit 1
    fi
    
    local task_count
    task_count=$(echo "$tasks_json" | jq 'length')
    
    if [[ "$task_count" -eq 0 ]]; then
        [[ "$json_only" != "true" ]] && echo "No tasks to build"
        echo '{"status": "complete", "tasks": 0, "success": 0, "failed": 0}'
        exit 0
    fi
    
    [[ "$json_only" != "true" ]] && echo -e "${BLUE}Building $task_count tasks (max $max_parallel parallel)${NC}"
    
    # Create output directory for results
    local output_dir
    output_dir=$(mktemp -d)
    trap "rm -rf $output_dir" EXIT
    
    # Get parallel batches
    local batches
    batches=$(get_parallel_batches "$tasks_json")
    
    local batch_num=1
    local total_success=0
    local total_failed=0
    
    # Execute each batch
    echo "$batches" | jq -c '.[]?' 2>/dev/null | while read -r batch; do
        [[ -z "$batch" || "$batch" == "null" ]] && continue
        
        local batch_size
        batch_size=$(echo "$batch" | jq 'length')
        
        [[ "$json_only" != "true" ]] && echo -e "\n${CYAN}Batch $batch_num ($batch_size tasks):${NC}"
        
        if ! execute_batch "$batch" "$output_dir" "$max_parallel" "$dry_run"; then
            total_failed=$((total_failed + 1))
        else
            total_success=$((total_success + batch_size))
        fi
        
        batch_num=$((batch_num + 1))
    done
    
    # Collect results
    local results=()
    for result_file in "$output_dir"/*.result; do
        [[ -f "$result_file" ]] && results+=("$(cat "$result_file")")
    done
    
    local results_json="[]"
    for r in "${results[@]:-}"; do
        [[ -z "$r" ]] && continue
        results_json=$(echo "$results_json" | jq --argjson r "$r" '. + [$r]')
    done
    
    # Summary
    local success_count fail_count
    success_count=$(echo "$results_json" | jq '[.[] | select(.status == "success")] | length')
    fail_count=$(echo "$results_json" | jq '[.[] | select(.status == "failed")] | length')
    
    if [[ "$json_only" != "true" ]]; then
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Success:${NC} $success_count  ${RED}Failed:${NC} $fail_count"
    fi
    
    jq -n \
        --arg status "$([ "$fail_count" -eq 0 ] && echo 'complete' || echo 'partial')" \
        --argjson tasks "$task_count" \
        --argjson success "$success_count" \
        --argjson failed "$fail_count" \
        --argjson results "$results_json" \
        '{status: $status, tasks: $tasks, success: $success, failed: $failed, results: $results}'
    
    [[ "$fail_count" -eq 0 ]]
}

main "$@"
