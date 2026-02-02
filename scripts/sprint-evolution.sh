#!/usr/bin/env bash
#
# STUDIO Sprint Evolution - Post-sprint self-correction protocol
# ==============================================================
#
# Triggers every 5 atomic tasks to propose knowledge base evolution:
# - Deletable rules: Constraints with no violations in 10+ tasks
# - New enforcement rules: Highest-impact recurring patterns
#
# Usage:
#   ./sprint-evolution.sh check              Check if evolution is due
#   ./sprint-evolution.sh increment <task_id> Increment counter and track task
#   ./sprint-evolution.sh propose            Generate evolution proposals
#   ./sprint-evolution.sh apply <proposal>   Apply an approved proposal
#   ./sprint-evolution.sh status             Show sprint status
#   ./sprint-evolution.sh reset              Reset sprint counter
#   ./sprint-evolution.sh help               Show this help
#
# Philosophy: "Evolve or become obsolete."
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-.studio}"
SPRINT_FILE="${STUDIO_DIR}/sprint-counter.json"
KNOWLEDGE_BASE="STUDIO_KNOWLEDGE_BASE.md"
LEARNINGS_DIR="studio/learnings"
EVOLUTION_THRESHOLD=5
DELETION_THRESHOLD=10

# Colors for output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;95m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' BOLD='' NC=''
fi

log_evolution() { echo -e "${MAGENTA}[Evolution]${NC} $*"; }
log_success() { echo -e "${GREEN}[Evolution]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[Evolution]${NC} $*" >&2; }
log_error() { echo -e "${RED}[Evolution]${NC} $*" >&2; }

# Ensure sprint file exists
ensure_sprint_file() {
    mkdir -p "$STUDIO_DIR"
    if [[ ! -f "$SPRINT_FILE" ]]; then
        cat > "$SPRINT_FILE" << 'EOF'
{
  "current_sprint": 1,
  "tasks_in_sprint": 0,
  "last_evolution": null,
  "task_ids": [],
  "total_tasks": 0,
  "violations": {}
}
EOF
        log_evolution "Initialized sprint counter"
    fi
}

# Read JSON value (portable, no jq required)
read_json_value() {
    local file="$1"
    local key="$2"
    grep -oP "\"${key}\"\s*:\s*\K[^,}]+" "$file" 2>/dev/null | tr -d '"' || echo ""
}

# Read JSON array (portable)
read_json_array() {
    local file="$1"
    local key="$2"
    grep -oP "\"${key}\"\s*:\s*\[\K[^\]]+" "$file" 2>/dev/null | tr -d '"' || echo ""
}

# Update sprint file with jq or sed fallback
update_sprint_file() {
    local key="$1"
    local value="$2"

    if command -v jq &> /dev/null; then
        local tmp
        tmp=$(mktemp)
        jq ".$key = $value" "$SPRINT_FILE" > "$tmp" && mv "$tmp" "$SPRINT_FILE"
    else
        # Sed fallback for simple values
        sed -i.bak "s/\"$key\": [^,}]*/\"$key\": $value/" "$SPRINT_FILE"
        rm -f "${SPRINT_FILE}.bak"
    fi
}

# Check if evolution is due
cmd_check() {
    ensure_sprint_file

    local tasks_in_sprint
    if command -v jq &> /dev/null; then
        tasks_in_sprint=$(jq -r '.tasks_in_sprint' "$SPRINT_FILE")
    else
        tasks_in_sprint=$(read_json_value "$SPRINT_FILE" "tasks_in_sprint")
    fi

    if [[ "$tasks_in_sprint" -ge "$EVOLUTION_THRESHOLD" ]]; then
        echo "EVOLUTION_DUE"
        log_evolution "Evolution threshold reached ($tasks_in_sprint/$EVOLUTION_THRESHOLD tasks)"
        exit 0
    else
        echo "NOT_DUE"
        log_evolution "Tasks until evolution: $((EVOLUTION_THRESHOLD - tasks_in_sprint))"
        exit 1
    fi
}

# Increment task counter
cmd_increment() {
    local task_id="${1:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Usage: ./sprint-evolution.sh increment <task_id>"
        exit 1
    fi

    ensure_sprint_file

    if command -v jq &> /dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --arg tid "$task_id" '
          .tasks_in_sprint += 1 |
          .total_tasks += 1 |
          .task_ids += [$tid]
        ' "$SPRINT_FILE" > "$tmp" && mv "$tmp" "$SPRINT_FILE"
    else
        # Fallback: read, modify, write
        local current
        current=$(read_json_value "$SPRINT_FILE" "tasks_in_sprint")
        local total
        total=$(read_json_value "$SPRINT_FILE" "total_tasks")
        update_sprint_file "tasks_in_sprint" "$((current + 1))"
        update_sprint_file "total_tasks" "$((total + 1))"
    fi

    local tasks_in_sprint
    if command -v jq &> /dev/null; then
        tasks_in_sprint=$(jq -r '.tasks_in_sprint' "$SPRINT_FILE")
    else
        tasks_in_sprint=$(read_json_value "$SPRINT_FILE" "tasks_in_sprint")
    fi

    log_success "Task tracked: $task_id (Sprint progress: $tasks_in_sprint/$EVOLUTION_THRESHOLD)"

    # Check if evolution is due
    if [[ "$tasks_in_sprint" -ge "$EVOLUTION_THRESHOLD" ]]; then
        log_warn "EVOLUTION THRESHOLD REACHED - Run './sprint-evolution.sh propose' to generate proposals"
        echo "EVOLUTION_DUE"
    fi
}

# Generate evolution proposals
cmd_propose() {
    ensure_sprint_file

    echo ""
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}${BOLD}                    SPRINT EVOLUTION PROPOSALS                      ${NC}"
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""

    local proposals=()
    local proposal_count=0

    # === PROPOSAL TYPE 1: DELETABLE RULES ===
    echo -e "${CYAN}Analyzing rules for potential deletion...${NC}"

    if [[ -f "$KNOWLEDGE_BASE" ]]; then
        # Find constraints that haven't been violated recently
        local total_tasks
        if command -v jq &> /dev/null; then
            total_tasks=$(jq -r '.total_tasks // 0' "$SPRINT_FILE")
        else
            total_tasks=$(read_json_value "$SPRINT_FILE" "total_tasks")
        fi

        if [[ "$total_tasks" -ge "$DELETION_THRESHOLD" ]]; then
            # Extract constraint IDs and check violation count
            local constraints
            constraints=$(grep -oP "^### SC-[0-9]+:" "$KNOWLEDGE_BASE" 2>/dev/null | sed 's/:$//' || true)

            if [[ -n "$constraints" ]]; then
                echo ""
                echo -e "${YELLOW}PROPOSAL: Consider deleting stale constraints${NC}"
                echo "The following constraints have had no violations in $DELETION_THRESHOLD+ tasks:"
                echo ""

                while IFS= read -r constraint; do
                    local constraint_id="${constraint#### }"
                    # Check violations object in sprint file
                    local violations=0
                    if command -v jq &> /dev/null; then
                        violations=$(jq -r ".violations.\"$constraint_id\" // 0" "$SPRINT_FILE")
                    fi

                    if [[ "$violations" -eq 0 ]]; then
                        echo "  - $constraint_id (0 violations in last $total_tasks tasks)"
                        proposal_count=$((proposal_count + 1))
                    fi
                done <<< "$constraints"
            fi
        else
            echo "  (Need $DELETION_THRESHOLD+ tasks to propose deletions, currently at $total_tasks)"
        fi
    fi

    echo ""

    # === PROPOSAL TYPE 2: NEW ENFORCEMENT RULES ===
    echo -e "${CYAN}Analyzing learnings for promotion candidates...${NC}"

    # Check Pending Queue for items with 2+ occurrences
    if [[ -f "$KNOWLEDGE_BASE" ]]; then
        local pending_section
        pending_section=$(awk '/^## Pending Queue/,/^## [A-Z]/' "$KNOWLEDGE_BASE" | grep -v "^## " || true)

        if [[ -n "$pending_section" ]] && [[ "$pending_section" != *"No pending items"* ]]; then
            echo ""
            echo -e "${YELLOW}PROPOSAL: Promote items from Pending Queue${NC}"
            echo "The following patterns have reached the promotion threshold:"
            echo ""
            echo "$pending_section" | grep -E "^\*|^-" | head -10 || true
            proposal_count=$((proposal_count + 1))
        fi
    fi

    # Scan recent learnings for high-impact patterns
    echo ""
    echo -e "${CYAN}Scanning recent learnings for patterns...${NC}"

    local high_impact_count=0
    for domain_file in "$LEARNINGS_DIR"/*.md; do
        if [[ -f "$domain_file" ]]; then
            # Look for HIGH severity or error keywords
            local high_impact
            high_impact=$(grep -iE "(HIGH|crash|fail|broke|critical)" "$domain_file" 2>/dev/null | head -5 || true)
            if [[ -n "$high_impact" ]]; then
                local domain
                domain=$(basename "$domain_file" .md)
                echo ""
                echo -e "${YELLOW}High-impact patterns in $domain:${NC}"
                echo "$high_impact" | sed 's/^/  /'
                high_impact_count=$((high_impact_count + 1))
            fi
        fi
    done

    if [[ $high_impact_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}PROPOSAL: Promote recurring high-impact patterns to Strict Constraints${NC}"
        proposal_count=$((proposal_count + 1))
    fi

    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}"

    if [[ $proposal_count -eq 0 ]]; then
        echo -e "${GREEN}No evolution proposals at this time. Knowledge base is current.${NC}"
    else
        echo -e "${YELLOW}Generated $proposal_count proposal(s) for review.${NC}"
        echo ""
        echo "To apply proposals:"
        echo "  1. Review each proposal above"
        echo "  2. Manually edit STUDIO_KNOWLEDGE_BASE.md to accept/reject"
        echo "  3. Run './sprint-evolution.sh reset' to start new sprint"
    fi
    echo ""
}

# Apply a proposal (manual for now)
cmd_apply() {
    local proposal="${1:-}"

    log_warn "Proposal application requires manual review."
    log_warn "Please edit STUDIO_KNOWLEDGE_BASE.md directly to:"
    log_warn "  - Delete stale constraints"
    log_warn "  - Promote pending items to Strict Constraints"
    log_warn "  - Add new entries from high-impact learnings"
    log_warn ""
    log_warn "After editing, run: ./sprint-evolution.sh reset"
}

# Show sprint status
cmd_status() {
    ensure_sprint_file

    echo ""
    echo -e "${CYAN}${BOLD}SPRINT STATUS${NC}"
    echo "─────────────────────────────────────"

    if command -v jq &> /dev/null; then
        local sprint tasks total last_evo
        sprint=$(jq -r '.current_sprint' "$SPRINT_FILE")
        tasks=$(jq -r '.tasks_in_sprint' "$SPRINT_FILE")
        total=$(jq -r '.total_tasks // 0' "$SPRINT_FILE")
        last_evo=$(jq -r '.last_evolution // "never"' "$SPRINT_FILE")

        echo "  Current Sprint:     $sprint"
        echo "  Tasks in Sprint:    $tasks / $EVOLUTION_THRESHOLD"
        echo "  Total Tasks:        $total"
        echo "  Last Evolution:     $last_evo"
        echo ""

        local recent_tasks
        recent_tasks=$(jq -r '.task_ids[-5:][]' "$SPRINT_FILE" 2>/dev/null || true)
        if [[ -n "$recent_tasks" ]]; then
            echo -e "${CYAN}Recent Tasks:${NC}"
            echo "$recent_tasks" | sed 's/^/  - /'
        fi
    else
        cat "$SPRINT_FILE"
    fi

    echo ""

    # Progress bar
    local tasks_in_sprint
    if command -v jq &> /dev/null; then
        tasks_in_sprint=$(jq -r '.tasks_in_sprint' "$SPRINT_FILE")
    else
        tasks_in_sprint=$(read_json_value "$SPRINT_FILE" "tasks_in_sprint")
    fi

    local filled=$((tasks_in_sprint * 20 / EVOLUTION_THRESHOLD))
    local empty=$((20 - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    echo -e "  Progress: [${GREEN}${bar}${NC}] $tasks_in_sprint/$EVOLUTION_THRESHOLD"

    if [[ "$tasks_in_sprint" -ge "$EVOLUTION_THRESHOLD" ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠ EVOLUTION DUE - Run './sprint-evolution.sh propose'${NC}"
    fi
    echo ""
}

# Reset sprint counter
cmd_reset() {
    ensure_sprint_file

    local current_sprint last_evo total
    if command -v jq &> /dev/null; then
        current_sprint=$(jq -r '.current_sprint' "$SPRINT_FILE")
        total=$(jq -r '.total_tasks // 0' "$SPRINT_FILE")
        last_evo=$(date +"%Y-%m-%d")

        local tmp
        tmp=$(mktemp)
        jq --arg date "$last_evo" '
          .current_sprint += 1 |
          .tasks_in_sprint = 0 |
          .last_evolution = $date |
          .task_ids = []
        ' "$SPRINT_FILE" > "$tmp" && mv "$tmp" "$SPRINT_FILE"

        log_success "Sprint $current_sprint complete. Starting Sprint $((current_sprint + 1))"
        log_success "Total tasks processed: $total"
    else
        update_sprint_file "tasks_in_sprint" "0"
        update_sprint_file "task_ids" "[]"
        log_success "Sprint counter reset"
    fi
}

# Show help
cmd_help() {
    cat << 'EOF'
STUDIO Sprint Evolution - Post-Sprint Self-Correction Protocol
===============================================================

"Evolve or become obsolete."

Usage: ./sprint-evolution.sh <command> [arguments]

Commands:
  check                Check if evolution is due (exit 0 = due, exit 1 = not due)
  increment <task_id>  Increment counter and track task
  propose              Generate evolution proposals
  apply <proposal>     Apply an approved proposal (manual review)
  status               Show sprint status and progress
  reset                Reset sprint counter for new sprint
  help                 Show this help message

Evolution Triggers:
  - Every 5 atomic tasks (configurable via EVOLUTION_THRESHOLD)

Proposal Types:
  1. DELETABLE RULES
     Constraints with no violations in 10+ tasks
     → Proposal to remove from Strict Constraints

  2. NEW ENFORCEMENT RULES
     Items in Pending Queue with 2+ occurrences
     High-impact patterns from recent learnings
     → Proposal to promote to Strict Constraints

Workflow:
  1. Tasks are tracked via 'increment' command
  2. After 5 tasks, 'check' returns EVOLUTION_DUE
  3. Run 'propose' to generate proposals
  4. Review and manually edit STUDIO_KNOWLEDGE_BASE.md
  5. Run 'reset' to start new sprint

Configuration:
  Sprint state stored in: .studio/sprint-counter.json
  Evolution threshold: 5 tasks
  Deletion threshold: 10+ tasks without violation

Examples:
  ./sprint-evolution.sh increment task_20240215_auth
  ./sprint-evolution.sh status
  ./sprint-evolution.sh propose
  ./sprint-evolution.sh reset

EOF
}

# Main dispatch
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        check)
            cmd_check
            ;;
        increment|inc|track)
            cmd_increment "$@"
            ;;
        propose|proposals)
            cmd_propose
            ;;
        apply)
            cmd_apply "$@"
            ;;
        status|stat)
            cmd_status
            ;;
        reset)
            cmd_reset
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
