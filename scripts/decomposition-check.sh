#!/usr/bin/env bash
# STUDIO Decomposition Check
# Detects if enterprise decomposition is needed and whether it exists
#
# Usage:
#   decomposition-check.sh status           # Check current state
#   decomposition-check.sh should-trigger   # Returns 0 if should trigger, 1 if not
#   decomposition-check.sh estimate <goal>  # Estimate project scale from goal text
#
# Exit codes for should-trigger:
#   0 = Should trigger decomposition (large project, no map exists)
#   1 = Should NOT trigger (small project OR map already exists)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
DECOMPOSITION_MAP="${STUDIO_DIR}/decomposition-map.json"
BACKLOG_FILE="${STUDIO_DIR}/backlog.json"

# Thresholds
MIN_TASKS_FOR_DECOMPOSITION=5
MIN_COMPLEXITY_SCORE=15

# Colors (respect NO_COLOR)
if [[ -z "${NO_COLOR:-}" ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
    NC='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' CYAN='' PURPLE='' NC=''
fi

# Check if decomposition map exists
map_exists() {
    [[ -f "$DECOMPOSITION_MAP" ]] && return 0
    return 1
}

# Check if backlog exists (indicates enterprise decomposition was already done)
backlog_exists() {
    [[ -f "$BACKLOG_FILE" ]] && return 0
    return 1
}

# Get current task count from backlog
get_task_count() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "0"
        return
    fi
    
    jq '.metrics.total_tasks // 0' "$BACKLOG_FILE" 2>/dev/null || echo "0"
}

# Estimate complexity from goal text
# Returns a score 0-100 based on complexity indicators
estimate_complexity() {
    local goal="${1:-}"
    local score=0
    
    # Multi-component indicators (+10 each)
    if echo "$goal" | grep -qiE 'auth|authentication|authorization|login|sso|oauth'; then
        ((score += 10))
    fi
    if echo "$goal" | grep -qiE 'database|migration|schema|models'; then
        ((score += 10))
    fi
    if echo "$goal" | grep -qiE 'api|endpoint|rest|graphql'; then
        ((score += 10))
    fi
    if echo "$goal" | grep -qiE 'ui|frontend|dashboard|interface|components'; then
        ((score += 10))
    fi
    if echo "$goal" | grep -qiE 'integration|third.party|external|webhook'; then
        ((score += 10))
    fi
    if echo "$goal" | grep -qiE 'deploy|infrastructure|ci.cd|kubernetes|docker'; then
        ((score += 10))
    fi
    
    # Scale indicators (+15 each)
    if echo "$goal" | grep -qiE 'enterprise|platform|system|architecture'; then
        ((score += 15))
    fi
    if echo "$goal" | grep -qiE 'multi.tenant|saas|marketplace'; then
        ((score += 15))
    fi
    if echo "$goal" | grep -qiE 'complete|full|entire|whole|all'; then
        ((score += 10))
    fi
    
    # Task count indicators (+20 each)
    if echo "$goal" | grep -qiE 'from scratch|greenfield|new project'; then
        ((score += 20))
    fi
    if echo "$goal" | grep -qiE 'rebuild|rewrite|overhaul|refactor entire'; then
        ((score += 20))
    fi
    
    echo "$score"
}

# Scan codebase for scale indicators
scan_codebase_scale() {
    local indicators=0
    
    # Check for existing complexity
    local file_count
    file_count=$(find . -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.py" -o -name "*.go" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$file_count" -gt 100 ]]; then
        ((indicators += 10))
    fi
    if [[ "$file_count" -gt 500 ]]; then
        ((indicators += 10))
    fi
    
    # Check for multiple domains
    [[ -d "src/api" ]] || [[ -d "api" ]] && ((indicators += 5))
    [[ -d "src/components" ]] || [[ -d "components" ]] && ((indicators += 5))
    [[ -d "src/services" ]] || [[ -d "services" ]] && ((indicators += 5))
    [[ -d "src/models" ]] || [[ -d "models" ]] && ((indicators += 5))
    
    echo "$indicators"
}

# Main status command
cmd_status() {
    echo -e "${BOLD}Enterprise Decomposition Status${NC}"
    echo ""
    
    # Check project state
    if backlog_exists; then
        local backlog_tasks
        backlog_tasks=$(get_task_count)
        local project_name
        project_name=$(jq -r '.project_name // "unknown"' "$BACKLOG_FILE" 2>/dev/null || echo "unknown")
        
        echo -e "  ${GREEN}✓${NC} Enterprise project initialized"
        echo -e "    Project: ${BOLD}${project_name}${NC}"
        echo -e "    Backlog: ${CYAN}${BACKLOG_FILE}${NC}"
        echo -e "    Total tasks: ${backlog_tasks}"
        echo ""
        echo -e "  ${DIM}New /plan commands will add tasks to this backlog${NC}"
    else
        echo -e "  ${YELLOW}○${NC} No project initialized (first-time user)"
        echo -e "    Run /plan to start - large projects will trigger decomposition"
    fi
    
    echo ""
    
    # Check if map exists
    if map_exists; then
        local validated
        validated=$(jq '.validation_status.is_valid // false' "$DECOMPOSITION_MAP" 2>/dev/null || echo "false")
        local map_task_count
        map_task_count=$(jq '[.hierarchy.epics[].features[].tasks[]] | length' "$DECOMPOSITION_MAP" 2>/dev/null || echo "0")
        
        echo -e "  ${GREEN}✓${NC} Decomposition map exists"
        echo -e "    Path: ${CYAN}${DECOMPOSITION_MAP}${NC}"
        echo -e "    Tasks in map: ${map_task_count}"
        echo -e "    Validated: ${validated}"
    fi
}

# Should trigger decomposition?
# Returns:
#   BACKLOG_EXISTS - backlog exists, add to it (exit 1)
#   EXISTS - decomposition map exists (exit 1)
#   TASK_COUNT - trigger due to task count (exit 0)
#   COMPLEXITY - trigger due to goal complexity (exit 0)
#   CODEBASE - trigger due to codebase scale (exit 0)
#   SKIP - don't trigger (exit 1)
cmd_should_trigger() {
    local goal="${1:-}"
    
    # If backlog already exists, this is a returning user - add to backlog
    if backlog_exists; then
        echo "BACKLOG_EXISTS"
        return 1
    fi
    
    # If map already exists but no backlog (shouldn't happen), don't trigger
    if map_exists; then
        echo "EXISTS"
        return 1
    fi
    
    # Check complexity from goal first (for first-time users)
    if [[ -n "$goal" ]]; then
        local complexity
        complexity=$(estimate_complexity "$goal")
        
        if [[ "$complexity" -ge "$MIN_COMPLEXITY_SCORE" ]]; then
            echo "COMPLEXITY"
            return 0
        fi
    fi
    
    # Check codebase scale
    local codebase_scale
    codebase_scale=$(scan_codebase_scale)
    
    if [[ "$codebase_scale" -ge 20 ]]; then
        echo "CODEBASE"
        return 0
    fi
    
    echo "SKIP"
    return 1
}

# Estimate command
cmd_estimate() {
    local goal="${1:-}"
    
    if [[ -z "$goal" ]]; then
        echo "Usage: decomposition-check.sh estimate <goal>" >&2
        return 1
    fi
    
    echo -e "${BOLD}Project Scale Estimation${NC}"
    echo ""
    
    local complexity
    complexity=$(estimate_complexity "$goal")
    echo -e "  Complexity score: ${CYAN}${complexity}${NC} / 100"
    
    local codebase_scale
    codebase_scale=$(scan_codebase_scale)
    echo -e "  Codebase scale:   ${CYAN}${codebase_scale}${NC}"
    
    local total=$((complexity + codebase_scale))
    echo -e "  Combined score:   ${CYAN}${total}${NC}"
    echo ""
    
    if [[ "$total" -ge "$MIN_COMPLEXITY_SCORE" ]]; then
        echo -e "  ${YELLOW}Recommendation: Use enterprise decomposition${NC}"
        echo -e "  This project appears to have multiple pillars and significant scope."
        echo ""
        echo -e "  To initialize:"
        echo -e "    ${DIM}./scripts/backlog.sh init${NC}"
        echo -e "    ${DIM}Then follow enterprise decomposition prompts${NC}"
    else
        echo -e "  ${GREEN}Recommendation: Standard planning is sufficient${NC}"
        echo -e "  This appears to be a small-to-medium project."
    fi
}

# JSON output for programmatic use
cmd_json() {
    local goal="${1:-}"
    
    local backlog_exists_bool="false"
    backlog_exists && backlog_exists_bool="true"
    
    local map_exists_bool="false"
    map_exists && map_exists_bool="true"
    
    local task_count
    task_count=$(get_task_count)
    
    local complexity=0
    [[ -n "$goal" ]] && complexity=$(estimate_complexity "$goal")
    
    local codebase_scale
    codebase_scale=$(scan_codebase_scale)
    
    local should_trigger="false"
    local trigger_reason="none"
    local mode="standard"
    
    if [[ "$backlog_exists_bool" == "true" ]]; then
        # Returning user - add to existing backlog
        mode="add_to_backlog"
        trigger_reason="backlog_exists"
    elif [[ "$map_exists_bool" == "true" ]]; then
        # Map exists but no backlog (edge case)
        trigger_reason="map_exists"
    else
        # First-time user - check if should trigger decomposition
        if [[ "$complexity" -ge "$MIN_COMPLEXITY_SCORE" ]]; then
            should_trigger="true"
            trigger_reason="complexity"
            mode="initialize_decomposition"
        elif [[ "$codebase_scale" -ge 20 ]]; then
            should_trigger="true"
            trigger_reason="codebase_scale"
            mode="initialize_decomposition"
        fi
    fi
    
    cat << EOF
{
  "backlog_exists": ${backlog_exists_bool},
  "decomposition_map_exists": ${map_exists_bool},
  "decomposition_map_path": "${DECOMPOSITION_MAP}",
  "backlog_path": "${BACKLOG_FILE}",
  "backlog_task_count": ${task_count},
  "complexity_score": ${complexity},
  "codebase_scale_score": ${codebase_scale},
  "threshold_complexity": ${MIN_COMPLEXITY_SCORE},
  "should_trigger_decomposition": ${should_trigger},
  "trigger_reason": "${trigger_reason}",
  "mode": "${mode}"
}
EOF
}

# Main dispatch
main() {
    local cmd="${1:-status}"
    shift || true
    
    case "$cmd" in
        status)
            cmd_status
            ;;
        should-trigger)
            cmd_should_trigger "$@"
            ;;
        estimate)
            cmd_estimate "$@"
            ;;
        json)
            cmd_json "$@"
            ;;
        -h|--help|help)
            echo "Usage: decomposition-check.sh <command> [args]"
            echo ""
            echo "Commands:"
            echo "  status           Show current decomposition state"
            echo "  should-trigger   Check if decomposition should trigger (exit 0=yes, 1=no)"
            echo "  estimate <goal>  Estimate project scale from goal text"
            echo "  json [goal]      Output status as JSON"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            echo "Run 'decomposition-check.sh help' for usage" >&2
            return 1
            ;;
    esac
}

main "$@"
