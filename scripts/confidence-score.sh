#!/usr/bin/env bash
# ============================================================================
# confidence-score.sh - Plan Confidence Score Calculator
# ============================================================================
# Evaluates plan quality before build to prevent weak plans from executing.
# Scores 4 categories (25 points each): requirements, step_quality, context, risk
#
# Usage:
#   ./scripts/confidence-score.sh --plan-file <path>
#   ./scripts/confidence-score.sh --task-id <id>
#   ./scripts/confidence-score.sh --task-id <id> --threshold 70
#
# Exit codes:
#   0 - Confidence >= threshold (default 70)
#   1 - Confidence < threshold
#   2 - Plan not found
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
DEFAULT_THRESHOLD=70

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
confidence-score.sh - Plan Confidence Score Calculator

USAGE:
    ./scripts/confidence-score.sh --plan-file <path>
    ./scripts/confidence-score.sh --task-id <id>
    ./scripts/confidence-score.sh --task-id <id> --threshold 70

OPTIONS:
    --plan-file <path>   Path to plan.json file
    --task-id <id>       Task ID (looks for .studio/tasks/<id>/plan.json)
    --threshold <n>      Minimum score to pass (default: 70)
    --json               Output JSON only
    --quiet              Suppress progress output
    --help               Show this help

SCORING (100 points total):
    Requirements (25):  User confirmations, edge cases, scope clarity
    Step Quality (25):  Atomic steps, success criteria, dependencies
    Context (25):       Learnings embedded, constraints documented
    Risk (25):          Failure modes, retry behavior, rollback strategy

RECOMMENDATIONS:
    >= 80: PROCEED_WITH_CONFIDENCE
    60-79: PROCEED_WITH_CAUTION
    40-59: REVIEW_WARNINGS
    < 40:  DO_NOT_BUILD

EXAMPLES:
    # Check confidence before build
    ./scripts/confidence-score.sh --task-id task_20240215_auth

    # Require higher confidence for critical tasks
    ./scripts/confidence-score.sh --task-id task_xxx --threshold 85
EOF
}

# ============================================================================
# SCORING FUNCTIONS
# ============================================================================

# Score requirements completeness (0-25)
score_requirements() {
    local plan_file="$1"
    local score=0
    local details="{}"
    
    # Check user_confirmations exist (0-10 points)
    local confirmations
    confirmations=$(jq '.requirements.user_confirmations | length // 0' "$plan_file" 2>/dev/null || echo "0")
    local confirm_score=0
    if [[ "$confirmations" -ge 3 ]]; then
        confirm_score=10
    elif [[ "$confirmations" -ge 1 ]]; then
        confirm_score=5
    fi
    score=$((score + confirm_score))
    
    # Check edge_cases identified (0-8 points)
    local edge_cases
    edge_cases=$(jq '.requirements.edge_cases | length // 0' "$plan_file" 2>/dev/null || echo "0")
    local edge_score=0
    if [[ "$edge_cases" -ge 3 ]]; then
        edge_score=8
    elif [[ "$edge_cases" -ge 1 ]]; then
        edge_score=4
    fi
    score=$((score + edge_score))
    
    # Check scope defined (0-7 points)
    local has_scope
    has_scope=$(jq '.requirements.scope != null and .requirements.scope != ""' "$plan_file" 2>/dev/null || echo "false")
    local has_out_of_scope
    has_out_of_scope=$(jq '.requirements.out_of_scope != null' "$plan_file" 2>/dev/null || echo "false")
    local scope_score=0
    [[ "$has_scope" == "true" ]] && scope_score=$((scope_score + 4))
    [[ "$has_out_of_scope" == "true" ]] && scope_score=$((scope_score + 3))
    score=$((score + scope_score))
    
    details=$(jq -n \
        --argjson confirmations "$confirmations" \
        --argjson edge_cases "$edge_cases" \
        --argjson confirm_score "$confirm_score" \
        --argjson edge_score "$edge_score" \
        --argjson scope_score "$scope_score" \
        '{user_confirmations: $confirmations, edge_cases: $edge_cases, breakdown: {confirmations: $confirm_score, edge_cases: $edge_score, scope: $scope_score}}')
    
    echo "{\"score\": $score, \"max\": 25, \"details\": $details}"
}

# Score step quality (0-25)
score_step_quality() {
    local plan_file="$1"
    local score=0
    
    local total_steps
    total_steps=$(jq '.steps | length // 0' "$plan_file" 2>/dev/null || echo "0")
    
    if [[ "$total_steps" -eq 0 ]]; then
        echo '{"score": 0, "max": 25, "details": {"error": "No steps defined"}}'
        return
    fi
    
    # Check all steps have success_criteria (0-10 points)
    local steps_with_criteria
    steps_with_criteria=$(jq '[.steps[] | select(.success_criteria != null and (.success_criteria | length) > 0)] | length' "$plan_file" 2>/dev/null || echo "0")
    local criteria_ratio
    criteria_ratio=$(echo "scale=2; $steps_with_criteria / $total_steps" | bc)
    local criteria_score
    criteria_score=$(echo "scale=0; $criteria_ratio * 10 / 1" | bc)
    score=$((score + criteria_score))
    
    # Check steps have actions defined (0-8 points)
    local steps_with_actions
    steps_with_actions=$(jq '[.steps[] | select(.action != null and .action != "")] | length' "$plan_file" 2>/dev/null || echo "0")
    local action_ratio
    action_ratio=$(echo "scale=2; $steps_with_actions / $total_steps" | bc)
    local action_score
    action_score=$(echo "scale=0; $action_ratio * 8 / 1" | bc)
    score=$((score + action_score))
    
    # Check dependencies are clear / no cycles (0-7 points)
    local has_deps
    has_deps=$(jq '[.steps[] | select(.depends_on != null)] | length' "$plan_file" 2>/dev/null || echo "0")
    local dep_score=7  # Assume good unless proven otherwise
    # Simple check: no step depends on itself
    local self_deps
    self_deps=$(jq '[.steps[] | select(.depends_on != null) | select(.depends_on | index(.id))] | length' "$plan_file" 2>/dev/null || echo "0")
    [[ "$self_deps" -gt 0 ]] && dep_score=0
    score=$((score + dep_score))
    
    echo "{\"score\": $score, \"max\": 25, \"details\": {\"total_steps\": $total_steps, \"with_criteria\": $steps_with_criteria, \"with_actions\": $steps_with_actions}}"
}

# Score context coverage (0-25)
score_context() {
    local plan_file="$1"
    local score=0
    
    # Check technical_constraints documented (0-10 points)
    local constraints
    constraints=$(jq '.requirements.technical_constraints | length // 0' "$plan_file" 2>/dev/null || echo "0")
    local constraint_score=0
    if [[ "$constraints" -ge 2 ]]; then
        constraint_score=10
    elif [[ "$constraints" -ge 1 ]]; then
        constraint_score=5
    fi
    score=$((score + constraint_score))
    
    # Check quality_requirements defined (0-8 points)
    local has_testing
    has_testing=$(jq '.requirements.quality_requirements.testing != null' "$plan_file" 2>/dev/null || echo "false")
    local has_security
    has_security=$(jq '.requirements.quality_requirements.security != null' "$plan_file" 2>/dev/null || echo "false")
    local quality_score=0
    [[ "$has_testing" == "true" ]] && quality_score=$((quality_score + 4))
    [[ "$has_security" == "true" ]] && quality_score=$((quality_score + 4))
    score=$((score + quality_score))
    
    # Check acceptance_criteria defined (0-7 points)
    local ac_count
    ac_count=$(jq '.acceptance_criteria | length // 0' "$plan_file" 2>/dev/null || echo "0")
    local ac_score=0
    if [[ "$ac_count" -ge 3 ]]; then
        ac_score=7
    elif [[ "$ac_count" -ge 1 ]]; then
        ac_score=4
    fi
    score=$((score + ac_score))
    
    echo "{\"score\": $score, \"max\": 25, \"details\": {\"constraints\": $constraints, \"has_testing\": $has_testing, \"has_security\": $has_security, \"acceptance_criteria\": $ac_count}}"
}

# Score risk assessment (0-25)
score_risk() {
    local plan_file="$1"
    local score=0
    
    local total_steps
    total_steps=$(jq '.steps | length // 0' "$plan_file" 2>/dev/null || echo "0")
    
    # Check retry_behavior defined on steps (0-10 points)
    local steps_with_retry
    steps_with_retry=$(jq '[.steps[] | select(.retry_behavior != null)] | length' "$plan_file" 2>/dev/null || echo "0")
    local retry_score=0
    if [[ "$total_steps" -gt 0 ]]; then
        local retry_ratio
        retry_ratio=$(echo "scale=2; $steps_with_retry / $total_steps" | bc)
        retry_score=$(echo "scale=0; $retry_ratio * 10 / 1" | bc)
    fi
    score=$((score + retry_score))
    
    # Check edge cases have handling (0-8 points)
    local edge_cases_with_handling
    edge_cases_with_handling=$(jq '[.requirements.edge_cases[] | select(.handling != null and .handling != "")] | length // 0' "$plan_file" 2>/dev/null || echo "0")
    local total_edge_cases
    total_edge_cases=$(jq '.requirements.edge_cases | length // 0' "$plan_file" 2>/dev/null || echo "0")
    local handling_score=0
    if [[ "$total_edge_cases" -gt 0 ]]; then
        local handling_ratio
        handling_ratio=$(echo "scale=2; $edge_cases_with_handling / $total_edge_cases" | bc)
        handling_score=$(echo "scale=0; $handling_ratio * 8 / 1" | bc)
    else
        handling_score=4  # No edge cases = partial credit
    fi
    score=$((score + handling_score))
    
    # Check estimated_complexity exists (0-7 points)
    local has_complexity
    has_complexity=$(jq '.estimated_complexity != null' "$plan_file" 2>/dev/null || echo "false")
    local has_estimated_time
    has_estimated_time=$(jq '.estimated_time != null' "$plan_file" 2>/dev/null || echo "false")
    local complexity_score=0
    [[ "$has_complexity" == "true" ]] && complexity_score=$((complexity_score + 4))
    [[ "$has_estimated_time" == "true" ]] && complexity_score=$((complexity_score + 3))
    score=$((score + complexity_score))
    
    echo "{\"score\": $score, \"max\": 25, \"details\": {\"steps_with_retry\": $steps_with_retry, \"edge_cases_handled\": $edge_cases_with_handling, \"has_complexity\": $has_complexity}}"
}

# Get recommendation based on score
get_recommendation() {
    local score="$1"
    
    if [[ "$score" -ge 80 ]]; then
        echo "PROCEED_WITH_CONFIDENCE"
    elif [[ "$score" -ge 60 ]]; then
        echo "PROCEED_WITH_CAUTION"
    elif [[ "$score" -ge 40 ]]; then
        echo "REVIEW_WARNINGS"
    else
        echo "DO_NOT_BUILD"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local plan_file=""
    local task_id=""
    local threshold="$DEFAULT_THRESHOLD"
    local json_only="false"
    local quiet="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plan-file) plan_file="$2"; shift 2 ;;
            --task-id) task_id="$2"; shift 2 ;;
            --threshold) threshold="$2"; shift 2 ;;
            --json) json_only="true"; shift ;;
            --quiet) quiet="true"; shift ;;
            --help|-h) show_help; exit 0 ;;
            *) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
        esac
    done
    
    # Resolve plan file
    if [[ -n "$task_id" ]]; then
        plan_file="${STUDIO_DIR}/tasks/${task_id}/plan.json"
    fi
    
    if [[ -z "$plan_file" ]]; then
        echo "Error: Must specify --plan-file or --task-id" >&2
        exit 2
    fi
    
    if [[ ! -f "$plan_file" ]]; then
        echo "Error: Plan file not found: $plan_file" >&2
        exit 2
    fi
    
    [[ "$quiet" != "true" && "$json_only" != "true" ]] && echo -e "${BLUE}Calculating confidence score...${NC}"
    
    # Calculate scores
    local req_result step_result ctx_result risk_result
    req_result=$(score_requirements "$plan_file")
    step_result=$(score_step_quality "$plan_file")
    ctx_result=$(score_context "$plan_file")
    risk_result=$(score_risk "$plan_file")
    
    local req_score step_score ctx_score risk_score
    req_score=$(echo "$req_result" | jq '.score')
    step_score=$(echo "$step_result" | jq '.score')
    ctx_score=$(echo "$ctx_result" | jq '.score')
    risk_score=$(echo "$risk_result" | jq '.score')
    
    local total_score
    total_score=$((req_score + step_score + ctx_score + risk_score))
    
    local recommendation
    recommendation=$(get_recommendation "$total_score")
    
    # Build warnings
    local warnings=()
    [[ "$req_score" -lt 15 ]] && warnings+=("Requirements incomplete - consider more user questioning")
    [[ "$step_score" -lt 15 ]] && warnings+=("Steps lack success criteria - hard to verify completion")
    [[ "$ctx_score" -lt 15 ]] && warnings+=("Context sparse - missing constraints or quality requirements")
    [[ "$risk_score" -lt 15 ]] && warnings+=("Risk not assessed - add retry behavior and edge case handling")
    
    local warnings_json="[]"
    for w in "${warnings[@]:-}"; do
        [[ -z "$w" ]] && continue
        warnings_json=$(echo "$warnings_json" | jq --arg w "$w" '. + [$w]')
    done
    
    # Build result
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local result
    result=$(jq -n \
        --argjson total "$total_score" \
        --argjson requirements "$req_score" \
        --argjson step_quality "$step_score" \
        --argjson context "$ctx_score" \
        --argjson risk "$risk_score" \
        --arg recommendation "$recommendation" \
        --argjson warnings "$warnings_json" \
        --arg calculated_at "$now" \
        --argjson threshold "$threshold" \
        --argjson req_details "$(echo "$req_result" | jq '.details')" \
        --argjson step_details "$(echo "$step_result" | jq '.details')" \
        --argjson ctx_details "$(echo "$ctx_result" | jq '.details')" \
        --argjson risk_details "$(echo "$risk_result" | jq '.details')" \
        '{
            total: $total,
            threshold: $threshold,
            passed: ($total >= $threshold),
            breakdown: {
                requirements: $requirements,
                step_quality: $step_quality,
                context: $context,
                risk: $risk
            },
            details: {
                requirements: $req_details,
                step_quality: $step_details,
                context: $ctx_details,
                risk: $risk_details
            },
            warnings: $warnings,
            recommendation: $recommendation,
            calculated_at: $calculated_at
        }')
    
    if [[ "$json_only" == "true" ]]; then
        echo "$result"
    else
        # Display results
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Confidence Score: ${NC}${total_score}/100"
        echo ""
        echo -e "  Requirements:  ${req_score}/25"
        echo -e "  Step Quality:  ${step_score}/25"
        echo -e "  Context:       ${ctx_score}/25"
        echo -e "  Risk:          ${risk_score}/25"
        echo ""
        
        case "$recommendation" in
            PROCEED_WITH_CONFIDENCE)
                echo -e "${GREEN}✓ $recommendation${NC}"
                ;;
            PROCEED_WITH_CAUTION)
                echo -e "${YELLOW}⚠ $recommendation${NC}"
                ;;
            REVIEW_WARNINGS)
                echo -e "${YELLOW}⚠ $recommendation${NC}"
                ;;
            DO_NOT_BUILD)
                echo -e "${RED}✗ $recommendation${NC}"
                ;;
        esac
        
        if [[ ${#warnings[@]} -gt 0 ]]; then
            echo ""
            echo -e "${YELLOW}Warnings:${NC}"
            for w in "${warnings[@]:-}"; do
                [[ -z "$w" ]] && continue
                echo "  - $w"
            done
        fi
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "$result"
    fi
    
    # Exit based on threshold
    if [[ "$total_score" -ge "$threshold" ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"
