#!/usr/bin/env bash
# STUDIO Risk Assessment
# Auto-detect high-risk patterns, flag tasks needing review, suggest mitigations
#
# Usage:
#   risk-assess.sh task <task-id>     # Assess risk for a specific task
#   risk-assess.sh all                # Assess all tasks in backlog
#   risk-assess.sh plan <task-id>     # Generate risk mitigation plan
#   risk-assess.sh report             # Full risk report for project

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
BACKLOG_FILE="${STUDIO_DIR}/backlog.json"
RISK_PATTERNS_FILE="${SCRIPT_DIR}/../data/risk-patterns.yaml"

# Colors
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

# Risk patterns with weights
declare -A RISK_PATTERNS=(
    # Authentication/Authorization (Critical)
    ["auth"]=30
    ["authentication"]=30
    ["authorization"]=30
    ["login"]=25
    ["password"]=30
    ["session"]=25
    ["token"]=25
    ["jwt"]=25
    ["oauth"]=30
    ["sso"]=30
    ["permission"]=25
    ["role"]=20
    ["rbac"]=25
    
    # Data & Database (High)
    ["migration"]=35
    ["database"]=20
    ["schema"]=25
    ["delete"]=30
    ["drop"]=40
    ["truncate"]=40
    ["backup"]=15
    ["restore"]=20
    ["data loss"]=40
    ["cascade"]=30
    
    # External Integrations (High)
    ["api"]=15
    ["external"]=20
    ["third-party"]=25
    ["integration"]=20
    ["webhook"]=20
    ["payment"]=35
    ["stripe"]=30
    ["billing"]=30
    
    # Security (Critical)
    ["security"]=30
    ["encryption"]=25
    ["secret"]=35
    ["credential"]=35
    ["vulnerability"]=40
    ["injection"]=40
    ["xss"]=35
    ["csrf"]=35
    ["sanitize"]=20
    
    # Infrastructure (High)
    ["deploy"]=25
    ["production"]=30
    ["infrastructure"]=25
    ["kubernetes"]=25
    ["docker"]=20
    ["ci/cd"]=20
    ["rollback"]=15
    ["downtime"]=30
    
    # Performance (Medium)
    ["performance"]=15
    ["scale"]=20
    ["cache"]=15
    ["optimization"]=15
    ["memory"]=20
    ["cpu"]=15
    
    # Complexity indicators (Medium)
    ["refactor"]=20
    ["rewrite"]=30
    ["legacy"]=25
    ["technical debt"]=20
    ["complex"]=15
)

# Calculate risk score for text
calculate_risk_score() {
    local text="$1"
    local score=0
    local matched_patterns=""
    
    text=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    
    for pattern in "${!RISK_PATTERNS[@]}"; do
        if [[ "$text" == *"$pattern"* ]]; then
            ((score += RISK_PATTERNS[$pattern]))
            matched_patterns+="$pattern (${RISK_PATTERNS[$pattern]}), "
        fi
    done
    
    echo "$score|${matched_patterns%, }"
}

# Get risk level from score
get_risk_level() {
    local score=$1
    
    if ((score >= 80)); then
        echo "CRITICAL"
    elif ((score >= 50)); then
        echo "HIGH"
    elif ((score >= 25)); then
        echo "MEDIUM"
    else
        echo "LOW"
    fi
}

# Get risk color
get_risk_color() {
    local level="$1"
    case "$level" in
        CRITICAL) echo "$RED" ;;
        HIGH) echo "$YELLOW" ;;
        MEDIUM) echo "$CYAN" ;;
        LOW) echo "$GREEN" ;;
        *) echo "$NC" ;;
    esac
}

# Assess a single task
cmd_task() {
    local task_id="${1:-}"
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: risk-assess.sh task <task-id>" >&2
        return 1
    fi
    
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    local task
    task=$(jq -r --arg id "$task_id" '
        .epics[].features[].tasks[] | 
        select(.id == $id or .short_id == $id) |
        "\(.name)|\(.description // "")"
    ' "$BACKLOG_FILE" | head -1)
    
    if [[ -z "$task" ]]; then
        echo "Task not found: $task_id" >&2
        return 1
    fi
    
    IFS='|' read -r name description <<< "$task"
    local text="$name $description"
    
    echo -e "${BOLD}Risk Assessment: $task_id${NC}"
    echo -e "  Task: $name"
    echo ""
    
    local result
    result=$(calculate_risk_score "$text")
    local score="${result%%|*}"
    local patterns="${result#*|}"
    
    local level
    level=$(get_risk_level "$score")
    local color
    color=$(get_risk_color "$level")
    
    echo -e "  ${BOLD}Risk Level:${NC} ${color}$level${NC} (score: $score)"
    
    if [[ -n "$patterns" ]]; then
        echo ""
        echo -e "  ${YELLOW}Risk Factors:${NC}"
        IFS=', ' read -ra pattern_array <<< "$patterns"
        for p in "${pattern_array[@]}"; do
            echo -e "    • $p"
        done
    fi
    
    # Suggest mitigations based on level
    echo ""
    case "$level" in
        CRITICAL)
            echo -e "  ${RED}⚠ CRITICAL RISK - Requires:${NC}"
            echo -e "    • Senior review before implementation"
            echo -e "    • Comprehensive rollback plan"
            echo -e "    • Staged deployment with monitoring"
            echo -e "    • Backup verification"
            ;;
        HIGH)
            echo -e "  ${YELLOW}⚠ HIGH RISK - Recommended:${NC}"
            echo -e "    • Code review by domain expert"
            echo -e "    • Integration tests before deploy"
            echo -e "    • Rollback plan documented"
            ;;
        MEDIUM)
            echo -e "  ${CYAN}○ MEDIUM RISK - Consider:${NC}"
            echo -e "    • Standard code review"
            echo -e "    • Unit test coverage"
            ;;
        LOW)
            echo -e "  ${GREEN}✓ LOW RISK${NC}"
            echo -e "    • Standard development workflow"
            ;;
    esac
}

# Assess all tasks
cmd_all() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    echo -e "${BOLD}Project Risk Assessment${NC}"
    echo ""
    
    local tasks
    tasks=$(jq -r '.epics[].features[].tasks[] | "\(.short_id)|\(.name)|\(.description // "")"' "$BACKLOG_FILE")
    
    if [[ -z "$tasks" ]]; then
        echo -e "  ${DIM}No tasks in backlog${NC}"
        return
    fi
    
    declare -A risk_counts
    risk_counts["CRITICAL"]=0
    risk_counts["HIGH"]=0
    risk_counts["MEDIUM"]=0
    risk_counts["LOW"]=0
    
    local highest_risk_task=""
    local highest_risk_score=0
    
    while IFS='|' read -r id name description; do
        local text="$name $description"
        local result
        result=$(calculate_risk_score "$text")
        local score="${result%%|*}"
        local level
        level=$(get_risk_level "$score")
        local color
        color=$(get_risk_color "$level")
        
        ((risk_counts[$level]++))
        
        if ((score > highest_risk_score)); then
            highest_risk_score=$score
            highest_risk_task="$id"
        fi
        
        printf "  ${color}%-8s${NC} ${BOLD}%-6s${NC} %s\n" "$level" "$id" "$name"
    done <<< "$tasks"
    
    echo ""
    echo -e "${BOLD}Summary:${NC}"
    echo -e "  ${RED}Critical:${NC} ${risk_counts[CRITICAL]}"
    echo -e "  ${YELLOW}High:${NC}     ${risk_counts[HIGH]}"
    echo -e "  ${CYAN}Medium:${NC}   ${risk_counts[MEDIUM]}"
    echo -e "  ${GREEN}Low:${NC}      ${risk_counts[LOW]}"
    
    if [[ -n "$highest_risk_task" ]] && ((highest_risk_score > 0)); then
        echo ""
        echo -e "  ${YELLOW}Highest risk task:${NC} $highest_risk_task (score: $highest_risk_score)"
        echo -e "  ${DIM}Run: risk-assess.sh plan $highest_risk_task${NC}"
    fi
}

# Generate risk mitigation plan
cmd_plan() {
    local task_id="${1:-}"
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: risk-assess.sh plan <task-id>" >&2
        return 1
    fi
    
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    local task
    task=$(jq -r --arg id "$task_id" '
        .epics[].features[].tasks[] | 
        select(.id == $id or .short_id == $id) |
        "\(.name)|\(.description // "")"
    ' "$BACKLOG_FILE" | head -1)
    
    if [[ -z "$task" ]]; then
        echo "Task not found: $task_id" >&2
        return 1
    fi
    
    IFS='|' read -r name description <<< "$task"
    local text="$name $description"
    
    local result
    result=$(calculate_risk_score "$text")
    local score="${result%%|*}"
    local patterns="${result#*|}"
    local level
    level=$(get_risk_level "$score")
    
    echo -e "${BOLD}Risk Mitigation Plan: $task_id${NC}"
    echo -e "Task: $name"
    echo -e "Risk Level: $level (score: $score)"
    echo ""
    
    echo -e "${CYAN}## Pre-Implementation Checklist${NC}"
    
    # Generate checklist based on detected patterns
    if [[ "$patterns" == *"auth"* ]] || [[ "$patterns" == *"password"* ]] || [[ "$patterns" == *"token"* ]]; then
        echo "- [ ] Security review scheduled"
        echo "- [ ] Auth flow documented"
        echo "- [ ] Session handling verified"
        echo "- [ ] Token expiration configured"
    fi
    
    if [[ "$patterns" == *"migration"* ]] || [[ "$patterns" == *"database"* ]] || [[ "$patterns" == *"schema"* ]]; then
        echo "- [ ] Database backup verified"
        echo "- [ ] Rollback migration created"
        echo "- [ ] Data integrity checks added"
        echo "- [ ] Dry run on staging completed"
    fi
    
    if [[ "$patterns" == *"payment"* ]] || [[ "$patterns" == *"billing"* ]]; then
        echo "- [ ] Test mode verified"
        echo "- [ ] Webhook signatures validated"
        echo "- [ ] Idempotency keys implemented"
        echo "- [ ] Audit logging enabled"
    fi
    
    if [[ "$patterns" == *"external"* ]] || [[ "$patterns" == *"integration"* ]] || [[ "$patterns" == *"api"* ]]; then
        echo "- [ ] API rate limits documented"
        echo "- [ ] Fallback behavior defined"
        echo "- [ ] Timeout handling implemented"
        echo "- [ ] Circuit breaker considered"
    fi
    
    if [[ "$patterns" == *"deploy"* ]] || [[ "$patterns" == *"production"* ]]; then
        echo "- [ ] Deployment checklist prepared"
        echo "- [ ] Rollback procedure documented"
        echo "- [ ] Monitoring alerts configured"
        echo "- [ ] Communication plan ready"
    fi
    
    echo ""
    echo -e "${CYAN}## Rollback Strategy${NC}"
    
    if [[ "$patterns" == *"migration"* ]] || [[ "$patterns" == *"database"* ]]; then
        echo "1. Run reverse migration: \`npm run migrate:down\`"
        echo "2. Restore from backup if needed: \`./scripts/restore-db.sh\`"
        echo "3. Verify data integrity"
    elif [[ "$patterns" == *"deploy"* ]]; then
        echo "1. Revert to previous deployment"
        echo "2. Verify service health"
        echo "3. Notify stakeholders"
    else
        echo "1. Revert code changes: \`git revert HEAD\`"
        echo "2. Redeploy previous version"
        echo "3. Verify functionality"
    fi
    
    echo ""
    echo -e "${CYAN}## Monitoring${NC}"
    echo "- Watch error rates for 30 minutes post-deploy"
    echo "- Monitor key metrics: response time, error rate, throughput"
    echo "- Have rollback ready during observation window"
}

# Full project risk report
cmd_report() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    local project_name
    project_name=$(jq -r '.project_name // "Unknown"' "$BACKLOG_FILE")
    
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}           PROJECT RISK REPORT: $project_name${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get all tasks with risk scores
    local tasks
    tasks=$(jq -r '.epics[].features[].tasks[] | "\(.short_id)|\(.name)|\(.description // "")"' "$BACKLOG_FILE")
    
    local total_score=0
    local task_count=0
    declare -A risk_counts
    risk_counts["CRITICAL"]=0
    risk_counts["HIGH"]=0
    risk_counts["MEDIUM"]=0
    risk_counts["LOW"]=0
    
    local critical_tasks=""
    local high_tasks=""
    
    while IFS='|' read -r id name description; do
        local text="$name $description"
        local result
        result=$(calculate_risk_score "$text")
        local score="${result%%|*}"
        local level
        level=$(get_risk_level "$score")
        
        ((total_score += score))
        ((task_count++))
        ((risk_counts[$level]++))
        
        [[ "$level" == "CRITICAL" ]] && critical_tasks+="$id "
        [[ "$level" == "HIGH" ]] && high_tasks+="$id "
    done <<< "$tasks"
    
    local avg_score=0
    ((task_count > 0)) && avg_score=$((total_score / task_count))
    local project_level
    project_level=$(get_risk_level "$avg_score")
    local color
    color=$(get_risk_color "$project_level")
    
    echo -e "${BOLD}Overall Project Risk:${NC} ${color}$project_level${NC}"
    echo -e "Average task risk score: $avg_score"
    echo ""
    
    echo -e "${BOLD}Risk Distribution:${NC}"
    local bar_width=40
    for level in CRITICAL HIGH MEDIUM LOW; do
        local count=${risk_counts[$level]}
        local pct=0
        ((task_count > 0)) && pct=$((count * 100 / task_count))
        local bar_len=$((pct * bar_width / 100))
        local color
        color=$(get_risk_color "$level")
        printf "  %-8s %3d%% " "$level" "$pct"
        printf "${color}"
        for ((i=0; i<bar_len; i++)); do printf "█"; done
        printf "${NC}"
        for ((i=bar_len; i<bar_width; i++)); do printf "░"; done
        printf " (%d)\n" "$count"
    done
    
    if [[ -n "$critical_tasks" ]]; then
        echo ""
        echo -e "${RED}${BOLD}⚠ CRITICAL RISK TASKS:${NC}"
        for task in $critical_tasks; do
            local name
            name=$(jq -r --arg id "$task" '.epics[].features[].tasks[] | select(.short_id == $id) | .name' "$BACKLOG_FILE")
            echo -e "  ${RED}•${NC} $task: $name"
        done
    fi
    
    if [[ -n "$high_tasks" ]]; then
        echo ""
        echo -e "${YELLOW}${BOLD}⚠ HIGH RISK TASKS:${NC}"
        for task in $high_tasks; do
            local name
            name=$(jq -r --arg id "$task" '.epics[].features[].tasks[] | select(.short_id == $id) | .name' "$BACKLOG_FILE")
            echo -e "  ${YELLOW}•${NC} $task: $name"
        done
    fi
    
    echo ""
    echo -e "${BOLD}Recommendations:${NC}"
    if ((risk_counts[CRITICAL] > 0)); then
        echo -e "  ${RED}1.${NC} Address critical tasks first with full review"
    fi
    if ((risk_counts[HIGH] > 0)); then
        echo -e "  ${YELLOW}2.${NC} Schedule domain expert reviews for high-risk tasks"
    fi
    echo -e "  ${CYAN}3.${NC} Ensure rollback plans exist before deployment"
    echo -e "  ${GREEN}4.${NC} Monitor closely for 24h after any high-risk deploy"
}

# Main dispatch
main() {
    local cmd="${1:-all}"
    shift || true
    
    case "$cmd" in
        task|t)
            cmd_task "$@"
            ;;
        all|a)
            cmd_all
            ;;
        plan|p)
            cmd_plan "$@"
            ;;
        report|r)
            cmd_report
            ;;
        -h|--help|help)
            echo "Usage: risk-assess.sh <command> [args]"
            echo ""
            echo "Commands:"
            echo "  task <task-id>   Assess risk for a specific task"
            echo "  all              Assess all tasks in backlog"
            echo "  plan <task-id>   Generate risk mitigation plan"
            echo "  report           Full risk report for project"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            return 1
            ;;
    esac
}

main "$@"
