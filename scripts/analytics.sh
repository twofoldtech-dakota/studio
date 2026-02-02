#!/usr/bin/env bash
# STUDIO Analytics Dashboard
# Tracks build metrics and displays analytics
#
# Usage:
#   analytics.sh log <task_id> <status> <duration_ms> <steps> <retries> <verdict>
#   analytics.sh dashboard [days]
#   analytics.sh export [format]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Plugin source directory (for reading agents, playbooks, etc.)
STUDIO_DIR="${STUDIO_DIR:-studio}"
# Output directory in user's project (for writing data)
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"

ANALYTICS_FILE="${STUDIO_OUTPUT_DIR}/data/analytics.json"

# Colors
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize analytics file if not exists
init_analytics() {
    mkdir -p "$(dirname "$ANALYTICS_FILE")"

    if [[ ! -f "$ANALYTICS_FILE" ]]; then
        cat > "$ANALYTICS_FILE" << 'EOF'
{
  "version": "1.0.0",
  "created_at": "",
  "builds": [],
  "summary": {
    "total": 0,
    "complete": 0,
    "failed": 0,
    "aborted": 0,
    "halted": 0
  }
}
EOF
        # Set creation timestamp
        local now
        now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        local tmp
        tmp=$(mktemp)
        jq --arg t "$now" '.created_at = $t' "$ANALYTICS_FILE" > "$tmp" && mv "$tmp" "$ANALYTICS_FILE"
    fi
}

# Log a build completion
log_build() {
    local task_id="$1"
    local status="$2"
    local duration_ms="$3"
    local steps="$4"
    local retries="$5"
    local verdict="$6"

    init_analytics

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    local tmp
    tmp=$(mktemp)

    jq --arg id "$task_id" \
       --arg status "$status" \
       --argjson duration "$duration_ms" \
       --argjson steps "$steps" \
       --argjson retries "$retries" \
       --arg verdict "$verdict" \
       --arg time "$now" \
       '
       .builds += [{
         "id": $id,
         "status": $status,
         "duration_ms": $duration,
         "steps": $steps,
         "retries": $retries,
         "verdict": $verdict,
         "completed_at": $time
       }] |
       .summary.total += 1 |
       if $status == "COMPLETE" then .summary.complete += 1
       elif $status == "FAILED" then .summary.failed += 1
       elif $status == "ABORTED" then .summary.aborted += 1
       elif $status == "HALTED" then .summary.halted += 1
       else . end
       ' "$ANALYTICS_FILE" > "$tmp" && mv "$tmp" "$ANALYTICS_FILE"

    echo "Build logged: $task_id ($status)"
}

# Build progress bar
build_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-20}"

    [[ "$total" -eq 0 ]] && total=1
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    echo "$bar"
}

# Display analytics dashboard
show_dashboard() {
    local days="${1:-30}"

    init_analytics

    # Calculate cutoff timestamp
    local cutoff
    if [[ "$(uname)" == "Darwin" ]]; then
        cutoff=$(date -v-${days}d +%s 2>/dev/null || echo 0)
    else
        cutoff=$(date -d "$days days ago" +%s 2>/dev/null || echo 0)
    fi

    # Get stats for recent builds
    local stats
    stats=$(jq --arg cutoff "$cutoff" '
      .builds |
      map(select(
        (.completed_at | if . then (. | fromdateiso8601) else 0 end) > ($cutoff | tonumber)
      )) |
      {
        total: length,
        complete: map(select(.status == "COMPLETE")) | length,
        failed: map(select(.status == "FAILED")) | length,
        aborted: map(select(.status == "ABORTED")) | length,
        halted: map(select(.status == "HALTED")) | length,
        avg_duration: (if length > 0 then (map(.duration_ms // 0) | add / length / 1000) else 0 end),
        avg_steps: (if length > 0 then (map(.steps // 0) | add / length) else 0 end),
        avg_retries: (if length > 0 then (map(.retries // 0) | add / length) else 0 end),
        verdicts: (group_by(.verdict) | map({key: (.[0].verdict // "unknown"), value: length}) | from_entries)
      }
    ' "$ANALYTICS_FILE")

    local total complete failed aborted halted
    total=$(echo "$stats" | jq '.total')
    complete=$(echo "$stats" | jq '.complete')
    failed=$(echo "$stats" | jq '.failed')
    aborted=$(echo "$stats" | jq '.aborted')
    halted=$(echo "$stats" | jq '.halted')

    local success_rate=0
    [[ "$total" -gt 0 ]] && success_rate=$((complete * 100 / total))

    local avg_duration avg_steps avg_retries
    avg_duration=$(echo "$stats" | jq '.avg_duration | floor')
    avg_steps=$(echo "$stats" | jq '.avg_steps * 10 | floor / 10')
    avg_retries=$(echo "$stats" | jq '.avg_retries * 10 | floor / 10')

    # Get verdict breakdown
    local strong sound unstable blocked
    strong=$(echo "$stats" | jq '.verdicts.STRONG // 0')
    sound=$(echo "$stats" | jq '.verdicts.SOUND // 0')
    unstable=$(echo "$stats" | jq '.verdicts.UNSTABLE // 0')
    blocked=$(echo "$stats" | jq '.verdicts.BLOCK // 0')

    # Build success rate bar
    local success_bar
    success_bar=$(build_bar "$success_rate" 100 20)

    # Display dashboard
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}STUDIO ANALYTICS${NC} (Last ${days} days)"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${BOLD}Build Summary${NC}"
    echo -e "${BOLD}║${NC}  ├─ Total:      ${total} builds"
    echo -e "${BOLD}║${NC}  ├─ ${GREEN}Complete${NC}:  ${complete}"
    echo -e "${BOLD}║${NC}  ├─ ${RED}Failed${NC}:    ${failed}"
    echo -e "${BOLD}║${NC}  ├─ ${YELLOW}Halted${NC}:    ${halted}"
    echo -e "${BOLD}║${NC}  └─ ${DIM}Aborted${NC}:   ${aborted}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${BOLD}Success Rate${NC}"
    echo -e "${BOLD}║${NC}  [${GREEN}${success_bar}${NC}] ${success_rate}%"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${BOLD}Averages${NC}"
    echo -e "${BOLD}║${NC}  ├─ Duration:  ${avg_duration}s per build"
    echo -e "${BOLD}║${NC}  ├─ Steps:     ${avg_steps} per build"
    echo -e "${BOLD}║${NC}  └─ Retries:   ${avg_retries} per build"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${BOLD}Quality Verdicts${NC}"
    echo -e "${BOLD}║${NC}  ├─ ${GREEN}STRONG${NC}:   ${strong}"
    echo -e "${BOLD}║${NC}  ├─ ${GREEN}SOUND${NC}:    ${sound}"
    echo -e "${BOLD}║${NC}  ├─ ${YELLOW}UNSTABLE${NC}: ${unstable}"
    echo -e "${BOLD}║${NC}  └─ ${RED}BLOCKED${NC}:  ${blocked}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Show recent builds
show_recent() {
    local count="${1:-10}"

    init_analytics

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}RECENT BUILDS${NC} (Last ${count})"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"

    jq -r --argjson n "$count" '
      .builds | reverse | .[:$n][] |
      "\(.completed_at | .[0:10]) | \(.id | .[0:20]) | \(.status) | \(.steps)s/\(.retries)r | \(.verdict // "-")"
    ' "$ANALYTICS_FILE" | while IFS='|' read -r date id status steps_retries verdict; do
        # Color based on status
        local status_color="${NC}"
        case "$(echo "$status" | tr -d ' ')" in
            COMPLETE) status_color="${GREEN}" ;;
            FAILED|BLOCKED) status_color="${RED}" ;;
            HALTED) status_color="${YELLOW}" ;;
        esac

        echo -e "${BOLD}║${NC}  ${DIM}${date}${NC} ${id} ${status_color}${status}${NC} ${steps_retries} ${verdict}"
    done

    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Export analytics to different formats
export_analytics() {
    local format="${1:-json}"

    init_analytics

    case "$format" in
        json)
            cat "$ANALYTICS_FILE"
            ;;
        csv)
            echo "id,status,duration_ms,steps,retries,verdict,completed_at"
            jq -r '.builds[] | [.id, .status, .duration_ms, .steps, .retries, .verdict, .completed_at] | @csv' "$ANALYTICS_FILE"
            ;;
        summary)
            jq '.summary' "$ANALYTICS_FILE"
            ;;
        *)
            echo "Unknown format: $format (supported: json, csv, summary)" >&2
            exit 1
            ;;
    esac
}

# Reset analytics
reset_analytics() {
    if [[ -f "$ANALYTICS_FILE" ]]; then
        local backup="${ANALYTICS_FILE}.backup.$(date +%Y%m%d%H%M%S)"
        cp "$ANALYTICS_FILE" "$backup"
        echo "Backup created: $backup"
    fi

    rm -f "$ANALYTICS_FILE"
    init_analytics
    echo "Analytics reset"
}

# Main
case "${1:-dashboard}" in
    log)
        shift
        log_build "$@"
        ;;
    dashboard|show)
        show_dashboard "${2:-30}"
        ;;
    recent)
        show_recent "${2:-10}"
        ;;
    export)
        export_analytics "${2:-json}"
        ;;
    reset)
        reset_analytics
        ;;
    help|--help|-h)
        cat << 'EOF'
STUDIO Analytics

Usage:
  analytics.sh log <task_id> <status> <duration_ms> <steps> <retries> <verdict>
  analytics.sh dashboard [days]     Show analytics dashboard (default: 30 days)
  analytics.sh recent [count]       Show recent builds (default: 10)
  analytics.sh export [format]      Export data (json|csv|summary)
  analytics.sh reset                Reset analytics (with backup)

Examples:
  analytics.sh log task_20260201 COMPLETE 45000 5 2 STRONG
  analytics.sh dashboard 7
  analytics.sh export csv > builds.csv
EOF
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Use 'analytics.sh help' for usage" >&2
        exit 1
        ;;
esac
