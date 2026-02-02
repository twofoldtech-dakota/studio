#!/usr/bin/env bash
#
# STUDIO Context Manager - Intelligent Context Management
# ========================================================
#
# This script provides context management utilities including:
# - Token estimation for different content types
# - Tier detection based on entry age
# - Budget tracking and warnings
# - LLM summarization prompt generation
# - Cache management for summaries
#
# Usage:
#   ./context-manager.sh estimate <file>              Estimate tokens in file
#   ./context-manager.sh budget [pool]                Show budget status
#   ./context-manager.sh tier <date>                  Determine tier for date
#   ./context-manager.sh scan [domain]                Scan learnings for optimization
#   ./context-manager.sh summarize <file> <entry>     Generate summarization prompt
#   ./context-manager.sh cache-get <key>              Get cached summary
#   ./context-manager.sh cache-set <key> <content>    Cache a summary
#   ./context-manager.sh optimize [pool]              Trigger optimization
#   ./context-manager.sh status                       Show full context status
#
# Environment:
#   STUDIO_DIR        Base directory for STUDIO state (default: .studio)
#   CONTEXT_CONFIG    Path to context config (default: studio/config/context.json)
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-.studio}"
LEARNINGS_DIR="${LEARNINGS_DIR:-studio/learnings}"
CACHE_DIR="${STUDIO_DIR}/.cache/summaries"
CONTEXT_CONFIG="${CONTEXT_CONFIG:-}"

# Budget configuration - using functions for compatibility with older bash
get_soft_limit() {
    local pool="$1"
    case "$pool" in
        reserved)  echo 30000 ;;
        learnings) echo 20000 ;;
        backlog)   echo 15000 ;;
        plans)     echo 30000 ;;
        context7)  echo 25000 ;;
        working)   echo 30000 ;;
        *)         echo 0 ;;
    esac
}

get_hard_limit() {
    local pool="$1"
    case "$pool" in
        reserved)  echo 35000 ;;
        learnings) echo 25000 ;;
        backlog)   echo 20000 ;;
        plans)     echo 35000 ;;
        context7)  echo 30000 ;;
        working)   echo 40000 ;;
        *)         echo 0 ;;
    esac
}

# List of all pools
ALL_POOLS="reserved learnings backlog plans context7 working"

# Tier thresholds (days)
TIER1_MAX_AGE=30
TIER2_MAX_AGE=90

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
log_context() { echo -e "${CYAN}[Context]${NC} $*"; }
log_success() { echo -e "${GREEN}[Context]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[Context]${NC} $*" >&2; }
log_error() { echo -e "${RED}[Context]${NC} $*" >&2; }

# ============================================================================
# TOKEN ESTIMATION
# ============================================================================

# Estimate tokens for a file based on content type
# Code: chars/4, Markdown: words*1.3, JSON: chars/3.3
cmd_estimate() {
    local file="${1:-}"

    if [[ -z "$file" ]]; then
        log_error "Usage: context-manager.sh estimate <file>"
        exit 1
    fi

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi

    local content
    content=$(cat "$file")
    local ext="${file##*.}"
    local tokens=0

    case "$ext" in
        md|markdown)
            # Markdown: words * 1.3
            local words
            words=$(echo "$content" | wc -w | tr -d ' ')
            tokens=$(echo "scale=0; $words * 1.3 / 1" | bc)
            ;;
        json)
            # JSON: chars / 3.3
            local chars
            chars=$(echo "$content" | wc -c | tr -d ' ')
            tokens=$(echo "scale=0; $chars / 3.3" | bc)
            ;;
        sh|bash|py|js|ts|tsx|jsx|go|rs|rb|java|c|cpp|h|hpp)
            # Code: chars / 4
            local chars
            chars=$(echo "$content" | wc -c | tr -d ' ')
            tokens=$((chars / 4))
            ;;
        *)
            # Default: chars / 4
            local chars
            chars=$(echo "$content" | wc -c | tr -d ' ')
            tokens=$((chars / 4))
            ;;
    esac

    echo "$tokens"
}

# Estimate tokens for a string
estimate_string() {
    local content="${1:-}"
    local type="${2:-text}"  # text, code, json

    case "$type" in
        code)
            echo $(( ${#content} / 4 ))
            ;;
        json)
            echo "scale=0; ${#content} / 3.3" | bc
            ;;
        markdown|text)
            local words
            words=$(echo "$content" | wc -w | tr -d ' ')
            echo "scale=0; $words * 1.3 / 1" | bc
            ;;
        *)
            echo $(( ${#content} / 4 ))
            ;;
    esac
}

# ============================================================================
# BUDGET TRACKING
# ============================================================================

# Show budget status for a pool or all pools
cmd_budget() {
    local pool="${1:-all}"

    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}            CONTEXT BUDGET STATUS                       ${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ "$pool" == "all" ]]; then
        printf "${BOLD}%-12s %10s %10s %10s %8s${NC}\n" "Pool" "Used" "Soft" "Hard" "Status"
        echo "────────────────────────────────────────────────────────"

        local total_used=0
        local total_soft=0

        for p in $ALL_POOLS; do
            local used
            used=$(get_pool_usage "$p")
            local soft
            soft=$(get_soft_limit "$p")
            local hard
            hard=$(get_hard_limit "$p")
            local pct=0
            [[ $soft -gt 0 ]] && pct=$((used * 100 / soft))
            local status

            if [[ $used -ge $hard ]]; then
                status="${RED}EXCEEDED${NC}"
            elif [[ $used -ge $soft ]]; then
                status="${YELLOW}WARNING${NC}"
            else
                status="${GREEN}OK${NC}"
            fi

            printf "%-12s %10d %10d %10d %8s\n" "$p" "$used" "$soft" "$hard" "$(echo -e "$status")"

            total_used=$((total_used + used))
            total_soft=$((total_soft + soft))
        done

        echo "────────────────────────────────────────────────────────"
        printf "${BOLD}%-12s %10d %10d${NC}\n" "TOTAL" "$total_used" "$total_soft"

        local total_pct=0
        [[ $total_soft -gt 0 ]] && total_pct=$((total_used * 100 / total_soft))
        echo ""
        echo -e "Overall usage: ${BOLD}${total_pct}%${NC}"
    else
        local soft
        soft=$(get_soft_limit "$pool")
        if [[ $soft -eq 0 ]]; then
            log_error "Unknown pool: $pool"
            log_error "Valid pools: reserved, learnings, backlog, plans, context7, working"
            exit 1
        fi

        local used
        used=$(get_pool_usage "$pool")
        local hard
        hard=$(get_hard_limit "$pool")
        local pct=0
        [[ $soft -gt 0 ]] && pct=$((used * 100 / soft))

        echo -e "Pool: ${BOLD}$pool${NC}"
        echo -e "Used: ${BOLD}$used${NC} tokens"
        echo -e "Soft Limit: $soft tokens"
        echo -e "Hard Limit: $hard tokens"
        echo -e "Usage: ${pct}%"

        # Progress bar
        local bar_width=40
        local filled=$((pct * bar_width / 100))
        [[ $filled -gt $bar_width ]] && filled=$bar_width

        local bar=""
        local color="$GREEN"
        [[ $pct -ge 80 ]] && color="$YELLOW"
        [[ $pct -ge 95 ]] && color="$RED"

        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=filled; i<bar_width; i++)); do bar+="░"; done

        echo -e "[${color}${bar}${NC}]"
    fi
    echo ""
}

# Get current usage for a pool
get_pool_usage() {
    local pool="${1:-}"

    case "$pool" in
        learnings)
            # Estimate from learnings files
            local total=0
            if [[ -d "$LEARNINGS_DIR" ]]; then
                for file in "$LEARNINGS_DIR"/*.md; do
                    if [[ -f "$file" ]]; then
                        local tokens
                        tokens=$(cmd_estimate "$file" 2>/dev/null || echo 0)
                        total=$((total + tokens))
                    fi
                done
            fi
            echo "$total"
            ;;
        plans)
            # Estimate from plan.json files in .studio/tasks/
            local total=0
            local tasks_dir="${STUDIO_DIR}/tasks"
            if [[ -d "$tasks_dir" ]]; then
                for plan_file in "$tasks_dir"/*/plan.json; do
                    if [[ -f "$plan_file" ]]; then
                        local tokens
                        tokens=$(cmd_estimate "$plan_file" 2>/dev/null || echo 0)
                        total=$((total + tokens))
                    fi
                done
            fi
            echo "$total"
            ;;
        backlog)
            # Estimate from backlog.json
            local backlog_file="${STUDIO_DIR}/backlog.json"
            if [[ -f "$backlog_file" ]]; then
                cmd_estimate "$backlog_file" 2>/dev/null || echo 0
            else
                echo 0
            fi
            ;;
        reserved)
            # Estimate from playbooks and agent definitions
            local total=0
            local script_dir
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            local project_root
            project_root="$(dirname "$script_dir")"

            # Count playbook tokens
            for playbook in "$project_root"/playbooks/*/SKILL.md; do
                if [[ -f "$playbook" ]]; then
                    local tokens
                    tokens=$(cmd_estimate "$playbook" 2>/dev/null || echo 0)
                    total=$((total + tokens))
                fi
            done

            # Count agent definition tokens
            for agent in "$project_root"/agents/*.yaml; do
                if [[ -f "$agent" ]]; then
                    local chars
                    chars=$(wc -c < "$agent" | tr -d ' ')
                    # YAML similar to code: chars / 4
                    total=$((total + chars / 4))
                fi
            done

            echo "$total"
            ;;
        context7)
            # Context7 is for external docs - check cache if it exists
            local cache_dir="${STUDIO_DIR}/.cache/context7"
            local total=0
            if [[ -d "$cache_dir" ]]; then
                for file in "$cache_dir"/*; do
                    if [[ -f "$file" ]]; then
                        local tokens
                        tokens=$(cmd_estimate "$file" 2>/dev/null || echo 0)
                        total=$((total + tokens))
                    fi
                done
            fi
            echo "$total"
            ;;
        working)
            # Working pool is dynamic during execution
            # Check orchestration state for context_used by active agents
            local orch_current="${STUDIO_DIR}/orchestration/.current"
            if [[ -f "$orch_current" ]]; then
                local session_id
                session_id=$(cat "$orch_current")
                local state_file="${STUDIO_DIR}/orchestration/${session_id}/state.json"
                if [[ -f "$state_file" ]]; then
                    # Sum context_used from all agent states
                    jq '[.agent_states[]?.context_used // 0] | add // 0' "$state_file" 2>/dev/null || echo 0
                else
                    echo 0
                fi
            else
                echo 0
            fi
            ;;
        *)
            # Unknown pool
            echo 0
            ;;
    esac
}

# ============================================================================
# TIER DETECTION
# ============================================================================

# Determine tier for a given date
cmd_tier() {
    local date_str="${1:-}"

    if [[ -z "$date_str" ]]; then
        log_error "Usage: context-manager.sh tier <date>"
        log_error "Date format: YYYY-MM-DD"
        exit 1
    fi

    # Calculate days since date
    local now_epoch
    local date_epoch

    if [[ "$(uname)" == "Darwin" ]]; then
        now_epoch=$(date +%s)
        date_epoch=$(date -j -f "%Y-%m-%d" "$date_str" +%s 2>/dev/null || echo 0)
    else
        now_epoch=$(date +%s)
        date_epoch=$(date -d "$date_str" +%s 2>/dev/null || echo 0)
    fi

    if [[ $date_epoch -eq 0 ]]; then
        log_error "Invalid date format: $date_str"
        exit 1
    fi

    local days_ago=$(( (now_epoch - date_epoch) / 86400 ))

    if [[ $days_ago -lt $TIER1_MAX_AGE ]]; then
        echo "tier1"
        echo "full"
        echo "$days_ago days old - Full content (100% tokens)"
    elif [[ $days_ago -lt $TIER2_MAX_AGE ]]; then
        echo "tier2"
        echo "summary"
        echo "$days_ago days old - Summary (20-30% tokens)"
    else
        echo "tier3"
        echo "index"
        echo "$days_ago days old - Index only (5% tokens)"
    fi
}

# ============================================================================
# LEARNINGS SCAN
# ============================================================================

# Scan learnings for optimization opportunities
cmd_scan() {
    local domain="${1:-all}"

    echo ""
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${MAGENTA}            LEARNINGS CONTEXT SCAN                      ${NC}"
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ ! -d "$LEARNINGS_DIR" ]]; then
        log_warn "Learnings directory not found: $LEARNINGS_DIR"
        exit 0
    fi

    local tier1_count=0
    local tier2_count=0
    local tier3_count=0
    local needs_summarization=()
    local needs_archiving=()

    local files=()
    if [[ "$domain" == "all" ]]; then
        for f in "$LEARNINGS_DIR"/*.md; do
            [[ -f "$f" ]] && files+=("$f")
        done
    else
        files=("$LEARNINGS_DIR/${domain}.md")
    fi

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            continue
        fi

        local domain_name
        domain_name=$(basename "$file" .md)

        # Extract dates from entries
        while IFS= read -r line; do
            if [[ "$line" =~ ^##[[:space:]]([0-9]{4}-[0-9]{2}-[0-9]{2}): ]]; then
                local entry_date="${BASH_REMATCH[1]}"
                local tier_info
                tier_info=$(cmd_tier "$entry_date" 2>/dev/null | head -1)

                case "$tier_info" in
                    tier1)
                        ((tier1_count++))
                        ;;
                    tier2)
                        ((tier2_count++))
                        needs_summarization+=("${domain_name}:${entry_date}")
                        ;;
                    tier3)
                        ((tier3_count++))
                        needs_archiving+=("${domain_name}:${entry_date}")
                        ;;
                esac
            fi
        done < "$file"
    done

    # Report
    echo -e "Entries by tier:"
    echo -e "  ${GREEN}Tier 1 (Full):${NC}    $tier1_count entries (< ${TIER1_MAX_AGE} days)"
    echo -e "  ${YELLOW}Tier 2 (Summary):${NC} $tier2_count entries (${TIER1_MAX_AGE}-${TIER2_MAX_AGE} days)"
    echo -e "  ${RED}Tier 3 (Index):${NC}   $tier3_count entries (> ${TIER2_MAX_AGE} days)"
    echo ""

    if [[ ${#needs_summarization[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Entries needing summarization:${NC}"
        for entry in "${needs_summarization[@]}"; do
            echo "  - $entry"
        done
        echo ""
    fi

    if [[ ${#needs_archiving[@]} -gt 0 ]]; then
        echo -e "${RED}Entries needing archival:${NC}"
        for entry in "${needs_archiving[@]}"; do
            echo "  - $entry"
        done
        echo ""
    fi

    # Token estimate
    local total_tokens=0
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            local tokens
            tokens=$(cmd_estimate "$file" 2>/dev/null || echo 0)
            total_tokens=$((total_tokens + tokens))
        fi
    done

    local soft_limit
    soft_limit=$(get_soft_limit "learnings")
    local pct=$((total_tokens * 100 / soft_limit))

    echo -e "Token usage: ${BOLD}$total_tokens${NC} / $soft_limit (${pct}%)"

    if [[ $pct -ge 95 ]]; then
        echo -e "${RED}CRITICAL: Optimization required${NC}"
    elif [[ $pct -ge 80 ]]; then
        echo -e "${YELLOW}WARNING: Approaching budget limit${NC}"
    else
        echo -e "${GREEN}OK: Within budget${NC}"
    fi
    echo ""
}

# ============================================================================
# SUMMARIZATION
# ============================================================================

# Generate LLM summarization prompt for an entry
cmd_summarize() {
    local file="${1:-}"
    local entry_date="${2:-}"

    if [[ -z "$file" || -z "$entry_date" ]]; then
        log_error "Usage: context-manager.sh summarize <file> <entry_date>"
        exit 1
    fi

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi

    # Extract entry content
    local in_entry=0
    local entry_content=""
    local entry_title=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]${entry_date}: ]]; then
            in_entry=1
            entry_title="${line#*: }"
            continue
        fi

        if [[ $in_entry -eq 1 ]]; then
            if [[ "$line" =~ ^##[[:space:]][0-9]{4}-[0-9]{2}-[0-9]{2}: ]]; then
                break
            fi
            entry_content+="$line"$'\n'
        fi
    done < "$file"

    if [[ -z "$entry_content" ]]; then
        log_error "Entry not found for date: $entry_date"
        exit 1
    fi

    # Generate summarization prompt
    cat << EOF
Summarize this learning entry, preserving:
1. The key insight (one sentence)
2. Pattern names mentioned
3. Code snippets (keep if < 10 lines, describe otherwise)
4. Problem-solution pairs

Original entry:
## ${entry_date}: ${entry_title}

${entry_content}

Output format:
## ${entry_date}: ${entry_title} (summarized)
**Key Insight:** ...
**Patterns:** ...
**Ref:** ${file}#${entry_date}
EOF
}

# ============================================================================
# CACHE MANAGEMENT
# ============================================================================

# Get cached summary
cmd_cache_get() {
    local key="${1:-}"

    if [[ -z "$key" ]]; then
        log_error "Usage: context-manager.sh cache-get <key>"
        exit 1
    fi

    local cache_file="${CACHE_DIR}/${key}.md"

    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
    else
        exit 1
    fi
}

# Cache a summary
cmd_cache_set() {
    local key="${1:-}"
    local content="${2:-}"

    if [[ -z "$key" ]]; then
        log_error "Usage: context-manager.sh cache-set <key> <content>"
        exit 1
    fi

    mkdir -p "$CACHE_DIR"

    local cache_file="${CACHE_DIR}/${key}.md"
    echo "$content" > "$cache_file"

    log_success "Cached summary: $key"
}

# ============================================================================
# OPTIMIZATION
# ============================================================================

# Trigger optimization for a pool
cmd_optimize() {
    local pool="${1:-learnings}"

    echo ""
    echo -e "${BOLD}${YELLOW}Triggering optimization for pool: $pool${NC}"
    echo ""

    case "$pool" in
        learnings)
            # Scan for entries needing tier promotion
            cmd_scan all

            log_warn "To complete optimization, run summarization on flagged entries"
            log_warn "Use: context-manager.sh summarize <file> <date>"
            ;;
        *)
            log_warn "Optimization not implemented for pool: $pool"
            ;;
    esac
}

# ============================================================================
# STATUS
# ============================================================================

# Show full context status
cmd_status() {
    cmd_budget all
    echo ""
    cmd_scan all
}

# ============================================================================
# HELP
# ============================================================================

cmd_help() {
    cat << 'EOF'
STUDIO Context Manager - Intelligent Context Management
========================================================

Manages context window budgets, tier-based content aging, and optimization.

Usage: context-manager.sh <command> [arguments]

Commands:
  estimate <file>              Estimate tokens in a file
  budget [pool]                Show budget status (pool: reserved/learnings/backlog/plans/context7/working)
  tier <date>                  Determine tier for a date (YYYY-MM-DD)
  scan [domain]                Scan learnings for optimization opportunities
  summarize <file> <date>      Generate LLM summarization prompt for entry
  cache-get <key>              Get a cached summary
  cache-set <key> <content>    Cache a summary
  optimize [pool]              Trigger optimization for a pool
  status                       Show full context status
  help                         Show this help message

Token Estimation:
  - Code files: characters / 4
  - Markdown:   words * 1.3
  - JSON:       characters / 3.3

Tier System:
  - Tier 1 (Full):    < 30 days old, 100% tokens
  - Tier 2 (Summary): 30-90 days old, 20-30% tokens
  - Tier 3 (Index):   > 90 days old, 5% tokens

Budget Pools:
  - reserved:  30k tokens - System prompts, playbooks
  - learnings: 20k tokens - Project learnings
  - backlog:   15k tokens - Epic/Feature/Task hierarchy
  - plans:     30k tokens - Current plan details
  - context7:  25k tokens - External documentation
  - working:   30k tokens - Agent workspace

Examples:
  ./context-manager.sh estimate studio/learnings/frontend.md
  ./context-manager.sh budget learnings
  ./context-manager.sh tier 2025-11-15
  ./context-manager.sh scan frontend
  ./context-manager.sh status

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        estimate)     cmd_estimate "$@" ;;
        budget)       cmd_budget "$@" ;;
        tier)         cmd_tier "$@" ;;
        scan)         cmd_scan "$@" ;;
        summarize)    cmd_summarize "$@" ;;
        cache-get)    cmd_cache_get "$@" ;;
        cache-set)    cmd_cache_set "$@" ;;
        optimize)     cmd_optimize "$@" ;;
        status)       cmd_status "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            log_error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
