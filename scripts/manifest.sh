#!/usr/bin/env bash
#
# STUDIO Task Manifest Manager
# ============================
#
# Unified tracking for requirements, tasks, and execution state.
#
# Usage:
#   manifest.sh init <task_id> <goal>     Create new manifest
#   manifest.sh status [task_id]          Show current status
#   manifest.sh board [cast_id]           Show task board
#   manifest.sh timeline [cast_id]        Show event timeline
#   manifest.sh req add <desc> [priority] Add requirement
#   manifest.sh req list                  List requirements
#   manifest.sh task start <task_id>      Start a task
#   manifest.sh task complete <task_id>   Complete a task
#   manifest.sh task fail <task_id> <reason>
#   manifest.sh task block <task_id> <reason>
#   manifest.sh event <type> <message>    Log an event
#   manifest.sh progress <phase> <pct>    Update progress
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
PROJECTS_DIR="${STUDIO_DIR}/projects"

# Colors (safe for terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Find active task
find_active_task() {
    local task_id="${1:-}"

    if [[ -n "$task_id" ]]; then
        echo "${PROJECTS_DIR}/default/tasks/${task_id}"
        return 0
    fi

    # Find most recent active task
    local latest=""
    for dir in "${PROJECTS_DIR}"/*/tasks/task_*/; do
        if [[ -f "${dir}manifest.json" ]]; then
            local status
            status=$(jq -r '.status' "${dir}manifest.json" 2>/dev/null)
            if [[ "$status" != "COMPLETE" && "$status" != "FAILED" && "$status" != "ABORTED" ]]; then
                latest="${dir%/}"
            fi
        fi
    done

    if [[ -n "$latest" ]]; then
        echo "$latest"
        return 0
    fi

    # Return most recent task if no active
    ls -td "${PROJECTS_DIR}"/*/tasks/task_*/ 2>/dev/null | head -1 | tr -d '/'
}

# Initialize new manifest
cmd_init() {
    local task_id="$1"
    local goal="$2"
    local task_dir="${PROJECTS_DIR}/default/tasks/${task_id}"
    local manifest="${task_dir}/manifest.json"

    mkdir -p "$task_dir"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$manifest" << EOF
{
  "id": "${task_id}",
  "goal": "${goal}",
  "status": "GATHERING",
  "created_at": "${now}",
  "updated_at": "${now}",
  "progress": {
    "phase": "skill_acquisition",
    "phase_progress": 0,
    "overall_progress": 0,
    "current_task": null
  },
  "requirements": {
    "gathered_at": null,
    "confirmed_by_user": false,
    "functional": [],
    "non_functional": [],
    "constraints": [],
    "out_of_scope": []
  },
  "tasks": {
    "backlog": [],
    "in_progress": [],
    "blocked": [],
    "completed": [],
    "failed": []
  },
  "artifacts": {
    "created": [],
    "modified": [],
    "deleted": []
  },
  "quality": {
    "checks_passed": 0,
    "checks_failed": 0,
    "checks_skipped": 0,
    "verdict": "PENDING",
    "issues": []
  },
  "timeline": [
    {
      "timestamp": "${now}",
      "type": "task_started",
      "message": "Task initialized",
      "details": {"goal": "${goal}"}
    }
  ],
  "metrics": {
    "duration_ms": 0,
    "tasks_total": 0,
    "tasks_completed": 0,
    "tasks_failed": 0,
    "retries_total": 0
  }
}
EOF

    echo -e "${GREEN}✓${NC} Manifest created: ${manifest}"
}

# Show status overview
cmd_status() {
    local task_dir
    task_dir=$(find_active_task "${1:-}")
    local manifest="${task_dir}/manifest.json"

    if [[ ! -f "$manifest" ]]; then
        echo -e "${RED}No manifest found${NC}"
        return 1
    fi

    local id status phase phase_pct overall_pct current goal
    id=$(jq -r '.id' "$manifest")
    goal=$(jq -r '.goal' "$manifest")
    status=$(jq -r '.status' "$manifest")
    phase=$(jq -r '.progress.phase // "unknown"' "$manifest")
    phase_pct=$(jq -r '.progress.phase_progress // 0' "$manifest")
    overall_pct=$(jq -r '.progress.overall_progress // 0' "$manifest")
    current=$(jq -r '.progress.current_task // "none"' "$manifest")

    # Status color
    local status_color="$YELLOW"
    case "$status" in
        COMPLETE) status_color="$GREEN" ;;
        FAILED|ABORTED) status_color="$RED" ;;
        BLOCKED) status_color="$RED" ;;
        BUILDING) status_color="$CYAN" ;;
    esac

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  STUDIO BUILD STATUS                                         ${BOLD}║${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}  ID:     ${CYAN}${id}${NC}"
    echo -e "${BOLD}║${NC}  Goal:   ${goal:0:50}"
    echo -e "${BOLD}║${NC}  Status: ${status_color}${status}${NC}"
    echo -e "${BOLD}║${NC}"

    # Progress bar
    local bar_width=40
    local filled=$((overall_pct * bar_width / 100))
    local empty=$((bar_width - filled))
    local bar="${GREEN}"
    for ((i=0; i<filled; i++)); do bar+="█"; done
    bar+="${DIM}"
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="${NC}"

    echo -e "${BOLD}║${NC}  Progress: [${bar}] ${overall_pct}%"
    echo -e "${BOLD}║${NC}  Phase:    ${phase} (${phase_pct}%)"
    echo -e "${BOLD}║${NC}  Current:  ${current}"
    echo -e "${BOLD}║${NC}"

    # Task counts
    local backlog in_progress blocked completed failed
    backlog=$(jq '.tasks.backlog | length' "$manifest")
    in_progress=$(jq '.tasks.in_progress | length' "$manifest")
    blocked=$(jq '.tasks.blocked | length' "$manifest")
    completed=$(jq '.tasks.completed | length' "$manifest")
    failed=$(jq '.tasks.failed | length' "$manifest")

    echo -e "${BOLD}║${NC}  Tasks:    ${DIM}Backlog:${NC} ${backlog}  ${CYAN}In Progress:${NC} ${in_progress}  ${RED}Blocked:${NC} ${blocked}"
    echo -e "${BOLD}║${NC}            ${GREEN}Completed:${NC} ${completed}  ${RED}Failed:${NC} ${failed}"
    echo -e "${BOLD}║${NC}"

    # Requirements counts
    local req_func req_nonfunc req_confirmed
    req_func=$(jq '.requirements.functional | length' "$manifest")
    req_nonfunc=$(jq '.requirements.non_functional | length' "$manifest")
    req_confirmed=$(jq '.requirements.confirmed_by_user' "$manifest")

    echo -e "${BOLD}║${NC}  Reqs:     Functional: ${req_func}  Non-Functional: ${req_nonfunc}"
    echo -e "${BOLD}║${NC}            Confirmed: ${req_confirmed}"
    echo -e "${BOLD}║${NC}"

    # Quality
    local verdict checks_passed checks_failed
    verdict=$(jq -r '.quality.verdict' "$manifest")
    checks_passed=$(jq '.quality.checks_passed' "$manifest")
    checks_failed=$(jq '.quality.checks_failed' "$manifest")

    local verdict_color="$YELLOW"
    case "$verdict" in
        STRONG) verdict_color="$GREEN" ;;
        SOUND) verdict_color="$GREEN" ;;
        BRITTLE) verdict_color="$YELLOW" ;;
        CRACKED) verdict_color="$RED" ;;
    esac

    echo -e "${BOLD}║${NC}  Quality:  ${verdict_color}${verdict}${NC}  (${GREEN}✓${checks_passed}${NC} / ${RED}✗${checks_failed}${NC})"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show task board
cmd_board() {
    local task_dir
    task_dir=$(find_active_task "${1:-}")
    local manifest="${task_dir}/manifest.json"

    if [[ ! -f "$manifest" ]]; then
        echo -e "${RED}No manifest found${NC}"
        return 1
    fi

    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  TASK BOARD                                                                     ${BOLD}║${NC}"
    echo -e "${BOLD}╠════════════════╦════════════════╦════════════════╦════════════════╦═══════════════╣${NC}"
    echo -e "${BOLD}║${NC} ${DIM}BACKLOG${NC}        ${BOLD}║${NC} ${CYAN}IN PROGRESS${NC}    ${BOLD}║${NC} ${RED}BLOCKED${NC}        ${BOLD}║${NC} ${GREEN}COMPLETED${NC}      ${BOLD}║${NC} ${RED}FAILED${NC}        ${BOLD}║${NC}"
    echo -e "${BOLD}╠════════════════╬════════════════╬════════════════╬════════════════╬═══════════════╣${NC}"

    # Get max rows needed
    local max_rows=0
    for col in backlog in_progress blocked completed failed; do
        local count
        count=$(jq ".tasks.${col} | length" "$manifest")
        [[ $count -gt $max_rows ]] && max_rows=$count
    done

    [[ $max_rows -eq 0 ]] && max_rows=1

    for ((i=0; i<max_rows; i++)); do
        local backlog_task in_progress_task blocked_task completed_task failed_task

        backlog_task=$(jq -r ".tasks.backlog[$i].id // \"\"" "$manifest")
        in_progress_task=$(jq -r ".tasks.in_progress[$i].id // \"\"" "$manifest")
        blocked_task=$(jq -r ".tasks.blocked[$i].id // \"\"" "$manifest")
        completed_task=$(jq -r ".tasks.completed[$i].id // \"\"" "$manifest")
        failed_task=$(jq -r ".tasks.failed[$i].id // \"\"" "$manifest")

        printf "${BOLD}║${NC} %-14s ${BOLD}║${NC} %-14s ${BOLD}║${NC} %-14s ${BOLD}║${NC} %-14s ${BOLD}║${NC} %-13s ${BOLD}║${NC}\n" \
            "$backlog_task" "$in_progress_task" "$blocked_task" "$completed_task" "$failed_task"
    done

    echo -e "${BOLD}╚════════════════╩════════════════╩════════════════╩════════════════╩═══════════════╝${NC}"
    echo ""
}

# Show timeline
cmd_timeline() {
    local task_dir
    task_dir=$(find_active_task "${1:-}")
    local manifest="${task_dir}/manifest.json"

    if [[ ! -f "$manifest" ]]; then
        echo -e "${RED}No manifest found${NC}"
        return 1
    fi

    echo ""
    echo -e "${BOLD}TIMELINE${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────${NC}"

    jq -r '.timeline[] | "\(.timestamp | split("T")[1] | split(".")[0])  \(.type)  \(.message)"' "$manifest" | \
    while read -r line; do
        local time type msg
        time=$(echo "$line" | cut -d' ' -f1)
        type=$(echo "$line" | cut -d' ' -f3)
        msg=$(echo "$line" | cut -d' ' -f4-)

        local color="$NC"
        case "$type" in
            *completed*|*passed*) color="$GREEN" ;;
            *failed*|*error*) color="$RED" ;;
            *started*) color="$CYAN" ;;
            *blocked*) color="$YELLOW" ;;
        esac

        echo -e "${DIM}${time}${NC}  ${color}${type}${NC}  ${msg}"
    done

    echo ""
}

# Add requirement
cmd_req_add() {
    local task_dir
    task_dir=$(find_active_task "")
    local manifest="${task_dir}/manifest.json"

    local desc="$1"
    local priority="${2:-should}"
    local req_type="${3:-functional}"

    # Generate ID
    local count
    count=$(jq ".requirements.${req_type} | length" "$manifest")
    local id
    id=$(printf "REQ-%03d" $((count + 1)))

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Add requirement
    local tmp
    tmp=$(mktemp)
    jq ".requirements.${req_type} += [{
        \"id\": \"${id}\",
        \"description\": \"${desc}\",
        \"priority\": \"${priority}\",
        \"status\": \"gathered\",
        \"source\": \"user\",
        \"linked_tasks\": [],
        \"acceptance_criteria\": []
    }] | .updated_at = \"${now}\"" "$manifest" > "$tmp" && mv "$tmp" "$manifest"

    echo -e "${GREEN}✓${NC} Added ${id}: ${desc}"
}

# List requirements
cmd_req_list() {
    local task_dir
    task_dir=$(find_active_task "${1:-}")
    local manifest="${task_dir}/manifest.json"

    echo ""
    echo -e "${BOLD}REQUIREMENTS${NC}"
    echo -e "${DIM}─────────────────────────────────────────────────────────────${NC}"

    echo -e "\n${BOLD}Functional:${NC}"
    jq -r '.requirements.functional[] | "  \(.id) [\(.priority)] \(.status) - \(.description)"' "$manifest" 2>/dev/null || echo "  (none)"

    echo -e "\n${BOLD}Non-Functional:${NC}"
    jq -r '.requirements.non_functional[] | "  \(.id) [\(.priority)] \(.status) - \(.description)"' "$manifest" 2>/dev/null || echo "  (none)"

    echo -e "\n${BOLD}Constraints:${NC}"
    jq -r '.requirements.constraints[] | "  \(.id) [\(.priority)] \(.status) - \(.description)"' "$manifest" 2>/dev/null || echo "  (none)"

    echo ""
}

# Log event
cmd_event() {
    local task_dir
    task_dir=$(find_active_task "")
    local manifest="${task_dir}/manifest.json"

    local type="$1"
    local message="$2"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp
    tmp=$(mktemp)
    jq ".timeline += [{
        \"timestamp\": \"${now}\",
        \"type\": \"${type}\",
        \"message\": \"${message}\",
        \"details\": {}
    }] | .updated_at = \"${now}\"" "$manifest" > "$tmp" && mv "$tmp" "$manifest"
}

# Update progress
cmd_progress() {
    local task_dir
    task_dir=$(find_active_task "")
    local manifest="${task_dir}/manifest.json"

    local phase="$1"
    local pct="$2"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp
    tmp=$(mktemp)
    jq ".progress.phase = \"${phase}\" | .progress.phase_progress = ${pct} | .updated_at = \"${now}\"" "$manifest" > "$tmp" && mv "$tmp" "$manifest"
}

# Task operations
cmd_task() {
    local action="$1"
    shift

    local task_dir
    task_dir=$(find_active_task "")
    local manifest="${task_dir}/manifest.json"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    case "$action" in
        start)
            local task_id="$1"
            # Move from backlog to in_progress
            local tmp
            tmp=$(mktemp)
            jq "
                (.tasks.backlog[] | select(.id == \"${task_id}\")) as \$task |
                .tasks.backlog -= [\$task] |
                .tasks.in_progress += [\$task | .status = \"in_progress\" | .started_at = \"${now}\"] |
                .progress.current_task = \"${task_id}\" |
                .updated_at = \"${now}\"
            " "$manifest" > "$tmp" && mv "$tmp" "$manifest"
            cmd_event "task_started" "Started ${task_id}"
            echo -e "${CYAN}▶${NC} Started ${task_id}"
            ;;

        complete)
            local task_id="$1"
            local tmp
            tmp=$(mktemp)
            jq "
                (.tasks.in_progress[] | select(.id == \"${task_id}\")) as \$task |
                .tasks.in_progress -= [\$task] |
                .tasks.completed += [\$task | .status = \"completed\" | .completed_at = \"${now}\"] |
                .metrics.tasks_completed += 1 |
                .progress.current_task = null |
                .updated_at = \"${now}\"
            " "$manifest" > "$tmp" && mv "$tmp" "$manifest"
            cmd_event "task_completed" "Completed ${task_id}"
            echo -e "${GREEN}✓${NC} Completed ${task_id}"
            ;;

        fail)
            local task_id="$1"
            local reason="${2:-Unknown failure}"
            local tmp
            tmp=$(mktemp)
            jq "
                (.tasks.in_progress[] | select(.id == \"${task_id}\")) as \$task |
                .tasks.in_progress -= [\$task] |
                .tasks.failed += [\$task | .status = \"failed\" | .failure_reason = \"${reason}\"] |
                .metrics.tasks_failed += 1 |
                .progress.current_task = null |
                .updated_at = \"${now}\"
            " "$manifest" > "$tmp" && mv "$tmp" "$manifest"
            cmd_event "task_failed" "Failed ${task_id}: ${reason}"
            echo -e "${RED}✗${NC} Failed ${task_id}: ${reason}"
            ;;

        block)
            local task_id="$1"
            local reason="${2:-Unknown blocker}"
            local tmp
            tmp=$(mktemp)
            jq "
                (.tasks.in_progress[] | select(.id == \"${task_id}\")) as \$task |
                .tasks.in_progress -= [\$task] |
                .tasks.blocked += [\$task | .status = \"blocked\" | .blocker_reason = \"${reason}\"] |
                .progress.current_task = null |
                .updated_at = \"${now}\"
            " "$manifest" > "$tmp" && mv "$tmp" "$manifest"
            cmd_event "task_blocked" "Blocked ${task_id}: ${reason}"
            echo -e "${YELLOW}⊘${NC} Blocked ${task_id}: ${reason}"
            ;;
    esac
}

# Main dispatcher
main() {
    local cmd="${1:-status}"
    shift || true

    case "$cmd" in
        init)     cmd_init "$@" ;;
        status)   cmd_status "$@" ;;
        board)    cmd_board "$@" ;;
        timeline) cmd_timeline "$@" ;;
        req)
            local subcmd="${1:-list}"
            shift || true
            case "$subcmd" in
                add)  cmd_req_add "$@" ;;
                list) cmd_req_list "$@" ;;
            esac
            ;;
        task)     cmd_task "$@" ;;
        event)    cmd_event "$@" ;;
        progress) cmd_progress "$@" ;;
        *)
            echo "Unknown command: $cmd"
            echo "Usage: manifest.sh {init|status|board|timeline|req|task|event|progress}"
            exit 1
            ;;
    esac
}

main "$@"
