#!/usr/bin/env bash
# STUDIO Progress Dashboard
# Real-time project status, burndown tracking, time estimates
#
# Usage:
#   dashboard.sh                    # Full dashboard view
#   dashboard.sh status             # Quick status summary
#   dashboard.sh burndown           # Burndown chart
#   dashboard.sh epic <epic-id>     # Epic-specific view
#   dashboard.sh velocity           # Velocity metrics
#   dashboard.sh time               # Time tracking summary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
BACKLOG_FILE="${STUDIO_DIR}/backlog.json"
TIME_LOG="${STUDIO_DIR}/time-log.json"

# Colors
if [[ -z "${NO_COLOR:-}" ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' CYAN='' PURPLE='' BLUE='' NC=''
fi

# Initialize time log if needed
init_time_log() {
    if [[ ! -f "$TIME_LOG" ]]; then
        echo '{"entries": [], "estimates": {}}' > "$TIME_LOG"
    fi
}

# Get task counts by status
get_task_counts() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "0|0|0|0|0"
        return
    fi
    
    local total pending in_progress complete blocked
    total=$(jq '[.epics[].features[].tasks[]] | length' "$BACKLOG_FILE")
    pending=$(jq '[.epics[].features[].tasks[] | select(.status == "PENDING")] | length' "$BACKLOG_FILE")
    in_progress=$(jq '[.epics[].features[].tasks[] | select(.status == "IN_PROGRESS")] | length' "$BACKLOG_FILE")
    complete=$(jq '[.epics[].features[].tasks[] | select(.status == "COMPLETE" or .status == "COMPLETED")] | length' "$BACKLOG_FILE")
    blocked=$(jq '[.epics[].features[].tasks[] | select(.status == "BLOCKED")] | length' "$BACKLOG_FILE")
    
    echo "$total|$pending|$in_progress|$complete|$blocked"
}

# Draw progress bar
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-40}
    local label=${4:-""}
    
    local pct=0
    ((total > 0)) && pct=$((current * 100 / total))
    local filled=$((pct * width / 100))
    
    printf "%s " "$label"
    printf "${GREEN}"
    for ((i=0; i<filled; i++)); do printf "█"; done
    printf "${NC}"
    for ((i=filled; i<width; i++)); do printf "░"; done
    printf " %d/%d (%d%%)\n" "$current" "$total" "$pct"
}

# Full dashboard
cmd_dashboard() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found. Run /studio to create a project." >&2
        return 1
    fi
    
    local project_name
    project_name=$(jq -r '.project_name // "Unknown"' "$BACKLOG_FILE")
    
    clear 2>/dev/null || true
    
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║             STUDIO DASHBOARD: ${CYAN}$project_name${NC}${BOLD}                    ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Task counts
    IFS='|' read -r total pending in_progress complete blocked <<< "$(get_task_counts)"
    
    echo -e "${BOLD}Progress Overview${NC}"
    draw_progress_bar "$complete" "$total" 50 "  Overall:"
    echo ""
    
    # Status breakdown
    echo -e "${BOLD}Task Status${NC}"
    echo -e "  ${GREEN}✓ Complete:${NC}    $complete"
    echo -e "  ${YELLOW}◐ In Progress:${NC} $in_progress"
    echo -e "  ${CYAN}○ Pending:${NC}     $pending"
    echo -e "  ${RED}✗ Blocked:${NC}     $blocked"
    echo ""
    
    # Epic progress
    echo -e "${BOLD}Epic Progress${NC}"
    local epics
    epics=$(jq -r '.epics[] | "\(.short_id)|\(.name)|\([.features[].tasks[]] | length)|\([.features[].tasks[] | select(.status == "COMPLETE" or .status == "COMPLETED")] | length)"' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$epics" ]]; then
        while IFS='|' read -r id name task_total task_complete; do
            draw_progress_bar "$task_complete" "$task_total" 30 "  $id:"
        done <<< "$epics"
    fi
    echo ""
    
    # Recent activity
    echo -e "${BOLD}Recent Activity${NC}"
    local recent
    recent=$(jq -r '
        [.epics[].features[].tasks[] | 
         select(.changelog != null) | 
         .changelog[-1] as $last |
         "\(.short_id)|\($last.action)|\($last.timestamp)"
        ] | sort_by(.[2]) | reverse | .[0:5] | .[]
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$recent" ]]; then
        while IFS='|' read -r id action ts; do
            local time_ago
            time_ago=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%s" 2>/dev/null || echo "0")
            echo -e "  ${DIM}$ts${NC} $id: $action"
        done <<< "$recent"
    else
        echo -e "  ${DIM}No recent activity${NC}"
    fi
    echo ""
    
    # Quick actions
    echo -e "${BOLD}Quick Actions${NC}"
    echo -e "  ${DIM}dashboard.sh burndown${NC}  - View burndown chart"
    echo -e "  ${DIM}dashboard.sh velocity${NC}  - View velocity metrics"
    echo -e "  ${DIM}risk-assess.sh report${NC}  - View risk report"
}

# Quick status
cmd_status() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog" >&2
        return 1
    fi
    
    IFS='|' read -r total pending in_progress complete blocked <<< "$(get_task_counts)"
    
    local pct=0
    ((total > 0)) && pct=$((complete * 100 / total))
    
    echo -e "${BOLD}Project Status${NC}"
    echo -e "  Progress: ${GREEN}$complete${NC}/$total tasks ($pct%)"
    echo -e "  Active:   ${YELLOW}$in_progress${NC} in progress"
    
    if ((blocked > 0)); then
        echo -e "  ${RED}⚠ $blocked tasks blocked${NC}"
    fi
    
    # Next task suggestion
    local next_task
    next_task=$(jq -r '
        [.epics[].features[].tasks[] | 
         select(.status == "PENDING") |
         select(.depends_on == null or .depends_on == []) |
         .short_id
        ] | first // empty
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$next_task" ]]; then
        echo -e "  ${CYAN}Next:${NC} $next_task ready to start"
    fi
}

# Burndown chart
cmd_burndown() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    echo -e "${BOLD}Burndown Chart${NC}"
    echo ""
    
    IFS='|' read -r total pending in_progress complete blocked <<< "$(get_task_counts)"
    local remaining=$((total - complete))
    
    # ASCII burndown
    local height=10
    local width=50
    
    # Ideal line
    echo -e "${DIM}Ideal vs Actual Remaining Tasks${NC}"
    echo ""
    
    for ((row=height; row>=0; row--)); do
        local threshold=$((row * total / height))
        printf "%3d │" "$threshold"
        
        for ((col=0; col<width; col++)); do
            local ideal_at_col=$((total - (col * total / width)))
            
            if ((ideal_at_col == threshold)); then
                printf "${CYAN}·${NC}"
            elif ((col == width - 1)) && ((remaining == threshold)); then
                printf "${GREEN}●${NC}"
            else
                printf " "
            fi
        done
        echo ""
    done
    
    printf "    └"
    for ((i=0; i<width; i++)); do printf "─"; done
    echo ""
    printf "     Start"
    printf "%*s" $((width - 10)) "Now"
    echo ""
    
    echo ""
    echo -e "  Total tasks:     $total"
    echo -e "  Completed:       ${GREEN}$complete${NC}"
    echo -e "  Remaining:       ${YELLOW}$remaining${NC}"
    
    if ((total > 0)); then
        local velocity=$((complete)) # Simplified - would track over time
        if ((velocity > 0)); then
            local eta=$((remaining / velocity))
            echo -e "  Est. completion: ${CYAN}~$eta more cycles${NC}"
        fi
    fi
}

# Epic-specific view
cmd_epic() {
    local epic_id="${1:-}"
    
    if [[ -z "$epic_id" ]]; then
        echo "Usage: dashboard.sh epic <epic-id>" >&2
        return 1
    fi
    
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    local epic
    epic=$(jq -r --arg id "$epic_id" '
        .epics[] | select(.id == $id or .short_id == $id) |
        "\(.name)|\(.description // "")|\(.status)"
    ' "$BACKLOG_FILE" | head -1)
    
    if [[ -z "$epic" ]]; then
        echo "Epic not found: $epic_id" >&2
        return 1
    fi
    
    IFS='|' read -r name description status <<< "$epic"
    
    echo -e "${BOLD}Epic: $epic_id - $name${NC}"
    echo -e "Status: $status"
    [[ -n "$description" ]] && echo -e "Description: $description"
    echo ""
    
    # Features in this epic
    echo -e "${BOLD}Features${NC}"
    local features
    features=$(jq -r --arg id "$epic_id" '
        .epics[] | select(.id == $id or .short_id == $id) |
        .features[] | 
        "\(.short_id)|\(.name)|\([.tasks[]] | length)|\([.tasks[] | select(.status == "COMPLETE" or .status == "COMPLETED")] | length)"
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    while IFS='|' read -r fid fname ftotal fcomplete; do
        [[ -z "$fid" ]] && continue
        draw_progress_bar "$fcomplete" "$ftotal" 25 "  $fid:"
        echo -e "       ${DIM}$fname${NC}"
    done <<< "$features"
}

# Velocity metrics
cmd_velocity() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    echo -e "${BOLD}Velocity Metrics${NC}"
    echo ""
    
    # Count completed tasks by date (from changelog)
    local completed_tasks
    completed_tasks=$(jq -r '
        [.epics[].features[].tasks[] |
         select(.status == "COMPLETE" or .status == "COMPLETED") |
         .changelog[]? | select(.action == "COMPLETED" or .action == "STATUS_CHANGED") |
         .timestamp[0:10]
        ] | group_by(.) | map({date: .[0], count: length}) | .[]? |
        "\(.date)|\(.count)"
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -z "$completed_tasks" ]]; then
        echo -e "  ${DIM}No completion data yet${NC}"
        echo ""
        echo -e "  Tasks completed will show velocity over time."
        return
    fi
    
    echo -e "${CYAN}Tasks Completed by Date${NC}"
    local total_completed=0
    local days=0
    
    while IFS='|' read -r date count; do
        [[ -z "$date" ]] && continue
        ((total_completed += count))
        ((days++))
        
        # Simple bar
        printf "  %s " "$date"
        for ((i=0; i<count; i++)); do printf "${GREEN}█${NC}"; done
        printf " %d\n" "$count"
    done <<< "$completed_tasks"
    
    echo ""
    if ((days > 0)); then
        local avg=$((total_completed / days))
        echo -e "  Average: ${BOLD}$avg tasks/day${NC}"
    fi
}

# Time tracking summary
cmd_time() {
    init_time_log
    
    echo -e "${BOLD}Time Tracking${NC}"
    echo ""
    
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    # Get effort estimates from backlog
    local tasks
    tasks=$(jq -r '
        .epics[].features[].tasks[] |
        "\(.short_id)|\(.name)|\(.effort.size // "M")|\(.status)"
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    # Size to hours mapping
    declare -A size_hours
    size_hours["XS"]=1
    size_hours["S"]=2
    size_hours["M"]=4
    size_hours["L"]=8
    size_hours["XL"]=16
    
    local total_estimated=0
    local completed_estimated=0
    
    echo -e "${CYAN}Effort Summary${NC}"
    
    while IFS='|' read -r id name size status; do
        [[ -z "$id" ]] && continue
        local hours=${size_hours[$size]:-4}
        ((total_estimated += hours))
        
        if [[ "$status" == "COMPLETE" ]] || [[ "$status" == "COMPLETED" ]]; then
            ((completed_estimated += hours))
        fi
    done <<< "$tasks"
    
    echo -e "  Total estimated:     ${BOLD}${total_estimated}h${NC}"
    echo -e "  Completed estimated: ${GREEN}${completed_estimated}h${NC}"
    echo -e "  Remaining estimated: ${YELLOW}$((total_estimated - completed_estimated))h${NC}"
    echo ""
    
    # Effort by size
    echo -e "${CYAN}Tasks by Size${NC}"
    for size in XS S M L XL; do
        local count
        count=$(jq -r --arg s "$size" '[.epics[].features[].tasks[] | select(.effort.size == $s)] | length' "$BACKLOG_FILE" 2>/dev/null || echo "0")
        [[ "$count" == "0" ]] && continue
        echo -e "  $size: $count tasks (${size_hours[$size]:-4}h each)"
    done
}

# Main dispatch
main() {
    local cmd="${1:-dashboard}"
    shift || true
    
    case "$cmd" in
        dashboard|d|"")
            cmd_dashboard
            ;;
        status|s)
            cmd_status
            ;;
        burndown|b)
            cmd_burndown
            ;;
        epic|e)
            cmd_epic "$@"
            ;;
        velocity|v)
            cmd_velocity
            ;;
        time|t)
            cmd_time
            ;;
        -h|--help|help)
            echo "Usage: dashboard.sh <command> [args]"
            echo ""
            echo "Commands:"
            echo "  dashboard        Full dashboard view (default)"
            echo "  status           Quick status summary"
            echo "  burndown         Burndown chart"
            echo "  epic <epic-id>   Epic-specific view"
            echo "  velocity         Velocity metrics"
            echo "  time             Time tracking summary"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            return 1
            ;;
    esac
}

main "$@"
