#!/usr/bin/env bash
#
# STUDIO Signal Audit - Filter signal from noise in learnings
# ============================================================
#
# This script determines whether a learning entry is signal (worth capturing)
# or noise (should be filtered out). It classifies signals by type and
# determines the appropriate destination in the knowledge base.
#
# Usage:
#   ./signal-audit.sh classify <text>        Classify a learning and output destination
#   ./signal-audit.sh is-noise <text>        Check if entry is noise (exit 0 = noise)
#   ./signal-audit.sh detect-type <text>     Detect signal type (performance/error/etc)
#   ./signal-audit.sh validate <task_id>     Validate task_id format
#   ./signal-audit.sh frameworks             List tracked frameworks
#   ./signal-audit.sh help                   Show this help
#
# Signal Types:
#   performance  - Latency, LCP, memory, speed metrics → Performance Delta
#   error        - Errors, failures, bugs, crashes → Strict Constraints (if 2+)
#   framework    - Framework-specific patterns → Pending Queue (if 1)
#   convention   - Naming, structure, imports → Slop Ledger
#   pattern      - Reusable techniques → Domain learnings
#
# Philosophy: "Only capture what you'll actually use."
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-studio}"
CONFIG_DIR="${STUDIO_DIR}/config"
FRAMEWORKS_FILE="${CONFIG_DIR}/tracked-frameworks.json"
KNOWLEDGE_BASE="STUDIO_KNOWLEDGE_BASE.md"

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

log_signal() { echo -e "${MAGENTA}[Signal]${NC} $*"; }
log_noise() { echo -e "${YELLOW}[Noise]${NC} $*"; }
log_error() { echo -e "${RED}[Error]${NC} $*" >&2; }

# Noise keywords - entries containing these are filtered out
NOISE_KEYWORDS=(
    "how to"
    "basic"
    "simple"
    "standard"
    "obvious"
    "easy"
    "straightforward"
    "common"
    "typical"
    "normal"
    "usual"
    "just"
    "simply"
)

# Performance signal keywords
PERFORMANCE_KEYWORDS=(
    "latency"
    "lcp"
    "fcp"
    "cls"
    "inp"
    "memory"
    "slow"
    "timeout"
    "milliseconds"
    "ms"
    "seconds"
    "bytes"
    "kb"
    "mb"
    "bundle"
    "chunk"
    "load time"
    "render time"
    "ttfb"
    "throughput"
    "cpu"
    "optimization"
    "cache"
    "lazy"
    "defer"
)

# Error signal keywords
ERROR_KEYWORDS=(
    "error"
    "failed"
    "failure"
    "crash"
    "bug"
    "fix"
    "broke"
    "broken"
    "exception"
    "threw"
    "undefined"
    "null"
    "nan"
    "infinite"
    "loop"
    "deadlock"
    "race condition"
    "memory leak"
    "stack overflow"
)

# Convention signal keywords
CONVENTION_KEYWORDS=(
    "naming"
    "name"
    "convention"
    "structure"
    "import"
    "export"
    "organize"
    "folder"
    "directory"
    "file"
    "path"
    "case"
    "camelcase"
    "kebab"
    "snake"
    "pascal"
    "prefix"
    "suffix"
    "style"
)

# Check if text contains any keyword from array
contains_keyword() {
    local text="$1"
    shift
    local keywords=("$@")
    local text_lower
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    for keyword in "${keywords[@]}"; do
        if [[ "$text_lower" == *"$keyword"* ]]; then
            echo "$keyword"
            return 0
        fi
    done
    return 1
}

# Load framework keywords from config
load_framework_keywords() {
    if [[ -f "$FRAMEWORKS_FILE" ]]; then
        # Extract all keywords from the frameworks config
        if command -v jq &> /dev/null; then
            jq -r '.frameworks[].keywords[]' "$FRAMEWORKS_FILE" 2>/dev/null || true
            jq -r '.custom_signals[].pattern' "$FRAMEWORKS_FILE" 2>/dev/null || true
        else
            # Fallback: simple grep extraction
            grep -oP '(?<="keywords": \[)[^\]]+' "$FRAMEWORKS_FILE" 2>/dev/null | tr -d '",' || true
        fi
    fi
}

# Check if text matches framework patterns
matches_framework() {
    local text="$1"
    local text_lower
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

    if [[ ! -f "$FRAMEWORKS_FILE" ]]; then
        return 1
    fi

    local keywords
    keywords=$(load_framework_keywords)

    while IFS= read -r keyword; do
        if [[ -n "$keyword" && "$text_lower" == *"$keyword"* ]]; then
            echo "$keyword"
            return 0
        fi
    done <<< "$keywords"

    return 1
}

# Check if entry is noise (returns 0 for noise, 1 for signal)
# Internal version that returns instead of exits (for use within the script)
_check_is_noise() {
    local text="$1"

    # Rule 1: No task_id reference
    if ! echo "$text" | grep -qiE "(task_|task-|task id|#[0-9]+)"; then
        echo "No task_id reference found"
        return 0
    fi

    # Rule 2: Contains noise keywords
    local matched_noise
    if matched_noise=$(contains_keyword "$text" "${NOISE_KEYWORDS[@]}"); then
        echo "Contains noise keyword: '$matched_noise'"
        return 0
    fi

    # Rule 3: No measurable impact (no numbers or metrics)
    if ! echo "$text" | grep -qE "[0-9]+(\.[0-9]+)?\s*(ms|s|kb|mb|gb|%|x)"; then
        # Check for qualitative impact words
        if ! echo "$text" | grep -qiE "(broke|crashed|failed|fixed|improved|reduced|increased|eliminated|prevented)"; then
            echo "No measurable or observable impact"
            return 0
        fi
    fi

    # Not noise - it's signal
    return 1
}

# Check if entry is noise (command version with exit codes)
cmd_is_noise() {
    local text="${1:-}"

    if [[ -z "$text" ]]; then
        log_error "Usage: ./signal-audit.sh is-noise <text>"
        exit 1
    fi

    local reason
    if reason=$(_check_is_noise "$text"); then
        log_noise "$reason"
        exit 0
    fi

    # Not noise - it's signal
    exit 1
}

# Detect signal type
cmd_detect_type() {
    local text="${1:-}"

    if [[ -z "$text" ]]; then
        log_error "Usage: ./signal-audit.sh detect-type <text>"
        exit 1
    fi

    # Check in priority order

    # 1. Performance (highest priority if metrics present)
    if contains_keyword "$text" "${PERFORMANCE_KEYWORDS[@]}" > /dev/null; then
        if echo "$text" | grep -qE "[0-9]+(\.[0-9]+)?\s*(ms|s|kb|mb|gb|%)"; then
            echo "performance"
            return 0
        fi
    fi

    # 2. Error/Constraint
    if contains_keyword "$text" "${ERROR_KEYWORDS[@]}" > /dev/null; then
        echo "error"
        return 0
    fi

    # 3. Framework-specific
    if matches_framework "$text" > /dev/null; then
        echo "framework"
        return 0
    fi

    # 4. Convention/Slop
    if contains_keyword "$text" "${CONVENTION_KEYWORDS[@]}" > /dev/null; then
        echo "convention"
        return 0
    fi

    # 5. Default to pattern
    echo "pattern"
}

# Classify and determine destination
cmd_classify() {
    local text="${1:-}"

    if [[ -z "$text" ]]; then
        log_error "Usage: ./signal-audit.sh classify <text>"
        exit 1
    fi

    # First check if it's noise (use internal function that returns instead of exits)
    local noise_reason
    if noise_reason=$(_check_is_noise "$text"); then
        cat << EOF
{
  "is_signal": false,
  "reason": "filtered as noise: $noise_reason"
}
EOF
        return 0
    fi

    # Detect signal type
    local signal_type
    signal_type=$(cmd_detect_type "$text")

    # Determine destination based on type
    local destination severity
    case "$signal_type" in
        performance)
            destination="performance_delta"
            severity="MEDIUM"
            ;;
        error)
            destination="pending_queue"  # Moves to strict_constraints after 2+ occurrences
            severity="HIGH"
            ;;
        framework)
            destination="pending_queue"
            severity="MEDIUM"
            ;;
        convention)
            destination="slop_ledger"
            severity="MEDIUM"
            ;;
        pattern)
            destination="domain_learnings"
            severity="LOW"
            ;;
        *)
            destination="domain_learnings"
            severity="LOW"
            ;;
    esac

    # Upgrade severity if certain keywords present
    local text_lower
    text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')
    if [[ "$text_lower" == *"crash"* ]] || [[ "$text_lower" == *"data loss"* ]] || [[ "$text_lower" == *"security"* ]]; then
        severity="HIGH"
    fi

    # Output JSON result
    cat << EOF
{
  "is_signal": true,
  "signal_type": "$signal_type",
  "destination": "$destination",
  "suggested_severity": "$severity"
}
EOF
}

# Validate task_id format
cmd_validate() {
    local task_id="${1:-}"

    if [[ -z "$task_id" ]]; then
        log_error "Usage: ./signal-audit.sh validate <task_id>"
        exit 1
    fi

    # Valid formats:
    # - task_YYYYMMDD_description
    # - task-NNN
    # - #NNN (issue reference)
    if echo "$task_id" | grep -qE "^(task_[0-9]{8}_[a-z_]+|task-[0-9]+|#[0-9]+)$"; then
        echo "valid"
        exit 0
    else
        echo "invalid"
        exit 1
    fi
}

# List tracked frameworks
cmd_frameworks() {
    if [[ ! -f "$FRAMEWORKS_FILE" ]]; then
        log_error "Frameworks config not found: $FRAMEWORKS_FILE"
        log_error "Run setup to create it."
        exit 1
    fi

    echo ""
    echo -e "${CYAN}${BOLD}TRACKED FRAMEWORKS${NC}"
    echo "─────────────────────────────────────"

    if command -v jq &> /dev/null; then
        jq -r '.frameworks[] | "  \(.name): \(.keywords | join(", "))"' "$FRAMEWORKS_FILE"
        echo ""
        echo -e "${CYAN}Custom Signals:${NC}"
        jq -r '.custom_signals[] | "  \(.pattern) → \(.destination) [\(.severity)]"' "$FRAMEWORKS_FILE"
    else
        echo "  (Install jq for formatted output)"
        cat "$FRAMEWORKS_FILE"
    fi
    echo ""
}

# Show help
cmd_help() {
    cat << 'EOF'
STUDIO Signal Audit - Filter Signal from Noise
===============================================

"Only capture what you'll actually use."

Usage: ./signal-audit.sh <command> [arguments]

Commands:
  classify <text>      Classify a learning and output destination as JSON
  is-noise <text>      Check if entry is noise (exit 0 = noise, exit 1 = signal)
  detect-type <text>   Detect signal type (performance/error/framework/convention/pattern)
  validate <task_id>   Validate task_id format
  frameworks           List tracked frameworks from config
  help                 Show this help message

Signal Types:
  performance   Metrics, latency, memory, speed   → Performance Delta
  error         Failures, bugs, crashes           → Pending Queue / Strict Constraints
  framework     Framework-specific patterns       → Pending Queue
  convention    Naming, structure issues          → Slop Ledger
  pattern       Reusable techniques               → Domain Learnings

Noise Criteria (filtered out):
  - No task_id reference
  - Contains: "how to", "basic", "simple", "standard", "obvious"
  - No measurable or observable impact
  - Generic programming concepts

Examples:
  ./signal-audit.sh classify "Fixed memory leak in task_20240215_auth - reduced heap from 512MB to 128MB"
  # Output: {"is_signal": true, "signal_type": "performance", "destination": "performance_delta", ...}

  ./signal-audit.sh is-noise "How to use React hooks"
  # Exit 0 (is noise)

  ./signal-audit.sh detect-type "LCP improved from 2.4s to 1.1s after lazy loading"
  # Output: performance

Configuration:
  Framework patterns are loaded from studio/config/tracked-frameworks.json

EOF
}

# Main dispatch
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        classify)
            cmd_classify "$@"
            ;;
        is-noise|isnoise|noise)
            cmd_is_noise "$@"
            ;;
        detect-type|detect|type)
            cmd_detect_type "$@"
            ;;
        validate)
            cmd_validate "$@"
            ;;
        frameworks|fw)
            cmd_frameworks
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
