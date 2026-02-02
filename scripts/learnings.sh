#!/usr/bin/env bash
#
# STUDIO Learnings Utilities - Capture and Retrieve Project Learnings
# ====================================================================
#
# This script provides helper functions for managing the Learnings system.
# Learnings are captured during /build learn phases and inform future planning.
#
# Usage:
#   ./learnings.sh init                          Initialize learnings directory
#   ./learnings.sh add <domain> <title> <body>   Add a learning entry
#   ./learnings.sh list [domain]                 List learnings (all or specific domain)
#   ./learnings.sh count                         Count learnings per domain
#   ./learnings.sh read <domain>                 Read domain file contents
#   ./learnings.sh inject [domains...]           Output injection block for agents
#   ./learnings.sh detect <goal>                 Detect relevant domains from goal
#   ./learnings.sh search <query>                Search learnings by keyword
#
# Learnings are stored in studio/learnings/ as human-readable Markdown files.
#
# Philosophy: "Learn once, apply forever."
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-studio}"
LEARNINGS_DIR="${STUDIO_DIR}/learnings"
INTEGRATIONS_DIR="${LEARNINGS_DIR}/integrations"

# Valid domains
VALID_DOMAINS=("global" "frontend" "backend" "testing" "security" "performance")

# Colors for output (if terminal supports them)
if [[ -t 1 ]]; then
    MAGENTA='\033[0;95m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m' # No Color
else
    MAGENTA=''
    RED=''
    GREEN=''
    YELLOW=''
    CYAN=''
    BOLD=''
    NC=''
fi

# Logging functions
log_learn() {
    echo -e "${MAGENTA}[Learnings]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[Learnings]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[Learnings]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[Learnings]${NC} $*" >&2
}

# Get current date in YYYY-MM-DD format
get_date() {
    date +"%Y-%m-%d"
}

# Validate domain name
validate_domain() {
    local domain="$1"
    for valid in "${VALID_DOMAINS[@]}"; do
        if [[ "$domain" == "$valid" ]]; then
            return 0
        fi
    done
    return 1
}

# Initialize the learnings directory
cmd_init() {
    log_learn "Initializing learnings directory..."

    mkdir -p "$LEARNINGS_DIR"
    mkdir -p "$INTEGRATIONS_DIR"

    # Create domain files if they don't exist
    for domain in "${VALID_DOMAINS[@]}"; do
        local file="${LEARNINGS_DIR}/${domain}.md"
        if [[ ! -f "$file" ]]; then
            local title
            case "$domain" in
                global)      title="Global Learnings" ;;
                frontend)    title="Frontend Learnings" ;;
                backend)     title="Backend Learnings" ;;
                testing)     title="Testing Learnings" ;;
                security)    title="Security Learnings" ;;
                performance) title="Performance Learnings" ;;
            esac

            cat > "$file" << EOF
# ${title}

> Project-wide patterns and lessons learned for ${domain} domain.

<!-- Learnings are captured automatically during /build learn phase -->
<!-- Format: ## YYYY-MM-DD: Brief Title -->

EOF
            log_learn "Created ${domain}.md"
        fi
    done

    log_success "Learnings directory initialized at ${LEARNINGS_DIR}/"
}

# Add a learning entry to a domain file
cmd_add() {
    local domain="${1:-}"
    local title="${2:-}"
    local body="${3:-}"

    if [[ -z "$domain" || -z "$title" ]]; then
        log_error "Usage: ./learnings.sh add <domain> <title> [body]"
        log_error "Domains: ${VALID_DOMAINS[*]}"
        log_error "For integrations: ./learnings.sh add integration:<name> <title> [body]"
        exit 1
    fi

    local file
    local is_integration=0

    # Check if this is an integration learning
    if [[ "$domain" == integration:* ]]; then
        local integration_name="${domain#integration:}"
        file="${INTEGRATIONS_DIR}/${integration_name}.md"
        is_integration=1

        # Create integration file if it doesn't exist
        if [[ ! -f "$file" ]]; then
            cat > "$file" << EOF
# ${integration_name^} Integration Learnings

> Patterns and lessons learned for ${integration_name} integration.

<!-- Learnings are captured automatically during /build learn phase -->

EOF
            log_learn "Created integrations/${integration_name}.md"
        fi
    else
        if ! validate_domain "$domain"; then
            log_error "Invalid domain: ${domain}"
            log_error "Valid domains: ${VALID_DOMAINS[*]}"
            log_error "For integrations: ./learnings.sh add integration:<name> <title> [body]"
            exit 1
        fi
        file="${LEARNINGS_DIR}/${domain}.md"
    fi

    if [[ ! -f "$file" ]]; then
        log_error "File not found. Run './learnings.sh init' first."
        exit 1
    fi

    local date
    date=$(get_date)

    # Append the learning entry
    cat >> "$file" << EOF

## ${date}: ${title}

${body}

EOF

    if [[ $is_integration -eq 1 ]]; then
        log_success "Learning added to integrations/${domain#integration:}.md"
    else
        log_success "Learning added to ${domain}.md"
    fi
    echo -e "  ${CYAN}\"${title}\"${NC}"
}

# List learnings
cmd_list() {
    local domain="${1:-all}"

    if [[ ! -d "$LEARNINGS_DIR" ]]; then
        log_error "Learnings directory not found. Run './learnings.sh init' first."
        exit 1
    fi

    echo ""
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}${BOLD}                         STUDIO LEARNINGS                          ${NC}"
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ "$domain" == "all" ]]; then
        for d in "${VALID_DOMAINS[@]}"; do
            local file="${LEARNINGS_DIR}/${d}.md"
            if [[ -f "$file" ]]; then
                local count
                count=$(grep -c "^## [0-9]" "$file" 2>/dev/null || echo 0)
                if [[ $count -gt 0 ]]; then
                    echo -e "${CYAN}━━━ ${d^^} (${count} learnings) ━━━${NC}"
                    grep "^## [0-9]" "$file" | sed 's/^## /  /'
                    echo ""
                fi
            fi
        done

        # Also list integrations
        if [[ -d "$INTEGRATIONS_DIR" ]]; then
            for file in "$INTEGRATIONS_DIR"/*.md; do
                if [[ -f "$file" ]]; then
                    local name
                    name=$(basename "$file" .md)
                    local count
                    count=$(grep -c "^## [0-9]" "$file" 2>/dev/null || echo 0)
                    if [[ $count -gt 0 ]]; then
                        echo -e "${CYAN}━━━ INTEGRATION: ${name^^} (${count} learnings) ━━━${NC}"
                        grep "^## [0-9]" "$file" | sed 's/^## /  /'
                        echo ""
                    fi
                fi
            done
        fi
    else
        local file
        if [[ "$domain" == integration:* ]]; then
            local integration_name="${domain#integration:}"
            file="${INTEGRATIONS_DIR}/${integration_name}.md"
        else
            if ! validate_domain "$domain"; then
                log_error "Invalid domain: ${domain}"
                exit 1
            fi
            file="${LEARNINGS_DIR}/${domain}.md"
        fi

        if [[ -f "$file" ]]; then
            cat "$file"
        else
            log_error "File not found: ${file}"
            exit 1
        fi
    fi
}

# Count learnings per domain
cmd_count() {
    if [[ ! -d "$LEARNINGS_DIR" ]]; then
        log_error "Learnings directory not found. Run './learnings.sh init' first."
        exit 1
    fi

    echo ""
    echo -e "${MAGENTA}LEARNINGS COUNT${NC}"
    echo "─────────────────"

    local total=0

    for domain in "${VALID_DOMAINS[@]}"; do
        local file="${LEARNINGS_DIR}/${domain}.md"
        local count=0
        if [[ -f "$file" ]]; then
            count=$(grep -c "^## [0-9]" "$file" 2>/dev/null || true)
            count=${count:-0}
            # Ensure count is a number
            if ! [[ "$count" =~ ^[0-9]+$ ]]; then
                count=0
            fi
        fi
        printf "  %-14s %3d entries\n" "${domain}:" "$count"
        total=$((total + count))
    done

    # Count integrations
    if [[ -d "$INTEGRATIONS_DIR" ]]; then
        local int_count=0
        for file in "$INTEGRATIONS_DIR"/*.md; do
            if [[ -f "$file" ]]; then
                local count
                count=$(grep -c "^## [0-9]" "$file" 2>/dev/null || echo 0)
                int_count=$((int_count + count))
            fi
        done
        printf "  %-14s %3d entries\n" "integrations:" "$int_count"
        total=$((total + int_count))
    fi

    echo "─────────────────"
    printf "  %-14s %3d entries\n" "TOTAL:" "$total"
    echo ""
}

# Read domain file contents (raw)
cmd_read() {
    local domain="${1:-}"

    if [[ -z "$domain" ]]; then
        log_error "Usage: ./learnings.sh read <domain>"
        exit 1
    fi

    local file
    if [[ "$domain" == integration:* ]]; then
        local integration_name="${domain#integration:}"
        file="${INTEGRATIONS_DIR}/${integration_name}.md"
    else
        if ! validate_domain "$domain"; then
            log_error "Invalid domain: ${domain}"
            exit 1
        fi
        file="${LEARNINGS_DIR}/${domain}.md"
    fi

    if [[ -f "$file" ]]; then
        cat "$file"
    else
        log_error "File not found: ${file}"
        exit 1
    fi
}

# Generate injection block for agents
cmd_inject() {
    local domains=("$@")

    if [[ ${#domains[@]} -eq 0 ]]; then
        domains=("global")
    fi

    # Always include global if not already present
    local has_global=0
    for d in "${domains[@]}"; do
        if [[ "$d" == "global" ]]; then
            has_global=1
            break
        fi
    done

    if [[ $has_global -eq 0 ]]; then
        domains=("global" "${domains[@]}")
    fi

    # Check if any learnings exist
    local has_learnings=0
    for domain in "${domains[@]}"; do
        local file
        if [[ "$domain" == integration:* ]]; then
            local integration_name="${domain#integration:}"
            file="${INTEGRATIONS_DIR}/${integration_name}.md"
        else
            file="${LEARNINGS_DIR}/${domain}.md"
        fi
        if [[ -f "$file" ]]; then
            local count
            count=$(grep -c "^## [0-9]" "$file" 2>/dev/null || echo 0)
            if [[ $count -gt 0 ]]; then
                has_learnings=1
                break
            fi
        fi
    done

    if [[ $has_learnings -eq 0 ]]; then
        return 0
    fi

    # Output injection block
    cat << 'EOF'

═══════════════════════════════════════════════════════════════════════════════
                         PROJECT LEARNINGS
                    (From Previous Build Cycles)
═══════════════════════════════════════════════════════════════════════════════

EOF

    for domain in "${domains[@]}"; do
        local file
        local title

        if [[ "$domain" == integration:* ]]; then
            local integration_name="${domain#integration:}"
            file="${INTEGRATIONS_DIR}/${integration_name}.md"
            title="${integration_name^} Integration"
        else
            if ! validate_domain "$domain"; then
                continue
            fi
            file="${LEARNINGS_DIR}/${domain}.md"
            case "$domain" in
                global)      title="Global" ;;
                frontend)    title="Frontend" ;;
                backend)     title="Backend" ;;
                testing)     title="Testing" ;;
                security)    title="Security" ;;
                performance) title="Performance" ;;
            esac
        fi

        if [[ -f "$file" ]]; then
            local count
            count=$(grep -c "^## [0-9]" "$file" 2>/dev/null || echo 0)
            if [[ $count -gt 0 ]]; then
                echo "## ${title} Learnings"
                # Extract learning entries (headers and their content up to next header)
                awk '/^## [0-9]/{if(p)print ""; p=1} p' "$file"
                echo ""
            fi
        fi
    done

    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
Use these learnings to inform your approach. Apply patterns that worked,
avoid anti-patterns, and build on previous solutions.
═══════════════════════════════════════════════════════════════════════════════

EOF
}

# Detect relevant domains from goal text
cmd_detect() {
    local goal="${1:-}"

    if [[ -z "$goal" ]]; then
        log_error "Usage: ./learnings.sh detect <goal>"
        exit 1
    fi

    # Convert to lowercase for matching
    local goal_lower
    goal_lower=$(echo "$goal" | tr '[:upper:]' '[:lower:]')

    local detected=()

    # Frontend signals
    if echo "$goal_lower" | grep -qE "(react|vue|angular|component|ui|ux|css|style|styling|view|frontend|front-end|html|jsx|tsx|tailwind|sass|scss)"; then
        detected+=("frontend")
    fi

    # Backend signals
    if echo "$goal_lower" | grep -qE "(api|database|db|service|model|controller|schema|endpoint|rest|graphql|backend|back-end|server|prisma|sequelize|mongoose)"; then
        detected+=("backend")
    fi

    # Testing signals
    if echo "$goal_lower" | grep -qE "(test|spec|coverage|mock|jest|pytest|mocha|cypress|e2e|unit test|integration test|testing|qa)"; then
        detected+=("testing")
    fi

    # Security signals
    if echo "$goal_lower" | grep -qE "(auth|authentication|authorization|token|jwt|oauth|permission|encryption|cors|security|password|credential|ssl|tls)"; then
        detected+=("security")
    fi

    # Performance signals
    if echo "$goal_lower" | grep -qE "(performance|optimize|speed|cache|caching|lazy|bundle|memory|cpu|latency|throughput)"; then
        detected+=("performance")
    fi

    # Output detected domains (one per line for easy parsing)
    for d in "${detected[@]}"; do
        echo "$d"
    done
}

# Search learnings by keyword
cmd_search() {
    local query="${1:-}"

    if [[ -z "$query" ]]; then
        log_error "Usage: ./learnings.sh search <query>"
        exit 1
    fi

    if [[ ! -d "$LEARNINGS_DIR" ]]; then
        log_error "Learnings directory not found. Run './learnings.sh init' first."
        exit 1
    fi

    echo ""
    echo -e "${MAGENTA}Searching for: ${CYAN}${query}${NC}"
    echo "─────────────────────────────────────────"

    local found=0

    # Search in domain files
    for domain in "${VALID_DOMAINS[@]}"; do
        local file="${LEARNINGS_DIR}/${domain}.md"
        if [[ -f "$file" ]]; then
            local matches
            matches=$(grep -i -n "$query" "$file" 2>/dev/null || true)
            if [[ -n "$matches" ]]; then
                echo -e "\n${CYAN}${domain}.md:${NC}"
                echo "$matches" | sed 's/^/  /'
                found=1
            fi
        fi
    done

    # Search in integration files
    if [[ -d "$INTEGRATIONS_DIR" ]]; then
        for file in "$INTEGRATIONS_DIR"/*.md; do
            if [[ -f "$file" ]]; then
                local matches
                matches=$(grep -i -n "$query" "$file" 2>/dev/null || true)
                if [[ -n "$matches" ]]; then
                    local name
                    name=$(basename "$file")
                    echo -e "\n${CYAN}integrations/${name}:${NC}"
                    echo "$matches" | sed 's/^/  /'
                    found=1
                fi
            fi
        done
    fi

    if [[ $found -eq 0 ]]; then
        echo "No results found."
    fi
    echo ""
}

# Classify a learning entry using signal-audit
cmd_classify() {
    local text="${1:-}"

    if [[ -z "$text" ]]; then
        log_error "Usage: ./learnings.sh classify <text>"
        log_error "Classifies a learning entry and returns destination"
        exit 1
    fi

    # Use signal-audit.sh if available
    local script_dir
    script_dir=$(dirname "${BASH_SOURCE[0]}")
    local signal_audit="${script_dir}/signal-audit.sh"

    if [[ -x "$signal_audit" ]]; then
        "$signal_audit" classify "$text"
    else
        # Fallback classification
        local text_lower
        text_lower=$(echo "$text" | tr '[:upper:]' '[:lower:]')

        local signal_type="pattern"
        local destination="domain_learnings"
        local severity="LOW"

        # Performance detection
        if echo "$text_lower" | grep -qE "(latency|lcp|memory|slow|timeout|ms|seconds|kb|mb)"; then
            if echo "$text" | grep -qE "[0-9]+(\.[0-9]+)?\s*(ms|s|kb|mb|%)"; then
                signal_type="performance"
                destination="performance_delta"
                severity="MEDIUM"
            fi
        fi

        # Error detection
        if echo "$text_lower" | grep -qE "(error|failed|crash|bug|fix|broke)"; then
            signal_type="error"
            destination="pending_queue"
            severity="HIGH"
        fi

        # Convention detection
        if echo "$text_lower" | grep -qE "(naming|convention|structure|import|style)"; then
            signal_type="convention"
            destination="slop_ledger"
            severity="MEDIUM"
        fi

        cat << EOF
{
  "is_signal": true,
  "signal_type": "$signal_type",
  "destination": "$destination",
  "suggested_severity": "$severity"
}
EOF
    fi
}

# Check for duplicate entries in knowledge base
cmd_check_duplicate() {
    local title="${1:-}"

    if [[ -z "$title" ]]; then
        log_error "Usage: ./learnings.sh check-duplicate <title>"
        exit 1
    fi

    local knowledge_base="STUDIO_KNOWLEDGE_BASE.md"
    local found_duplicates=0

    echo ""
    echo -e "${MAGENTA}Checking for duplicates: ${CYAN}${title}${NC}"
    echo "─────────────────────────────────────────"

    # Normalize title for comparison
    local title_lower
    title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')

    # Extract key words (3+ chars, remove common words)
    local keywords
    keywords=$(echo "$title_lower" | tr -cs '[:alnum:]' '\n' | awk 'length >= 3' | grep -vE "^(the|and|for|with|from|that|this|have|been|were|are|was|has)$" | sort -u)

    # Search in knowledge base
    if [[ -f "$knowledge_base" ]]; then
        while IFS= read -r keyword; do
            if [[ -n "$keyword" ]]; then
                local matches
                matches=$(grep -i "$keyword" "$knowledge_base" 2>/dev/null | grep -E "^###" || true)
                if [[ -n "$matches" ]]; then
                    if [[ $found_duplicates -eq 0 ]]; then
                        echo -e "${YELLOW}Potential duplicates in STUDIO_KNOWLEDGE_BASE.md:${NC}"
                    fi
                    echo "$matches" | sed 's/^/  /' | head -5
                    found_duplicates=1
                fi
            fi
        done <<< "$keywords"
    fi

    # Search in domain learnings
    for domain in "${VALID_DOMAINS[@]}"; do
        local file="${LEARNINGS_DIR}/${domain}.md"
        if [[ -f "$file" ]]; then
            while IFS= read -r keyword; do
                if [[ -n "$keyword" ]]; then
                    local matches
                    matches=$(grep -i "$keyword" "$file" 2>/dev/null | grep -E "^##" || true)
                    if [[ -n "$matches" ]]; then
                        if [[ $found_duplicates -eq 0 ]]; then
                            echo -e "${YELLOW}Potential duplicates found:${NC}"
                        fi
                        echo -e "  ${CYAN}${domain}.md:${NC}"
                        echo "$matches" | sed 's/^/    /' | head -3
                        found_duplicates=1
                    fi
                fi
            done <<< "$keywords"
        fi
    done

    if [[ $found_duplicates -eq 0 ]]; then
        echo -e "${GREEN}No duplicates found. Safe to add.${NC}"
        echo '{"has_duplicate": false}'
    else
        echo ""
        echo '{"has_duplicate": true, "action": "review_above"}'
    fi
    echo ""
}

# Extract metrics from text (before/after values)
cmd_extract_metrics() {
    local text="${1:-}"

    if [[ -z "$text" ]]; then
        log_error "Usage: ./learnings.sh extract-metrics <text>"
        log_error "Extracts before/after metrics from text"
        exit 1
    fi

    echo ""
    echo -e "${MAGENTA}Extracting metrics from text...${NC}"
    echo "─────────────────────────────────────────"

    local found_metrics=0

    # Pattern: "from X to Y" or "X -> Y" or "X → Y"
    local from_to_pattern
    from_to_pattern=$(echo "$text" | grep -oE "from\s+[0-9]+(\.[0-9]+)?\s*(ms|s|kb|mb|gb|%|x)?\s+(to|->|→)\s+[0-9]+(\.[0-9]+)?\s*(ms|s|kb|mb|gb|%|x)?" || true)

    if [[ -n "$from_to_pattern" ]]; then
        echo -e "${CYAN}Found from/to pattern:${NC}"
        echo "  $from_to_pattern"
        found_metrics=1
    fi

    # Pattern: "reduced/increased by X%"
    local delta_pattern
    delta_pattern=$(echo "$text" | grep -oE "(reduced|increased|improved|decreased|cut|dropped)\s+(by\s+)?[0-9]+(\.[0-9]+)?\s*%" || true)

    if [[ -n "$delta_pattern" ]]; then
        echo -e "${CYAN}Found delta pattern:${NC}"
        echo "  $delta_pattern"
        found_metrics=1
    fi

    # Pattern: specific metrics (LCP, FCP, TTFB, etc.)
    local web_vitals
    web_vitals=$(echo "$text" | grep -oiE "(lcp|fcp|cls|inp|ttfb|tti)\s*[:\s]+[0-9]+(\.[0-9]+)?\s*(ms|s)?" || true)

    if [[ -n "$web_vitals" ]]; then
        echo -e "${CYAN}Found web vitals:${NC}"
        echo "  $web_vitals"
        found_metrics=1
    fi

    # Pattern: memory/size metrics
    local size_metrics
    size_metrics=$(echo "$text" | grep -oiE "[0-9]+(\.[0-9]+)?\s*(kb|mb|gb|bytes)" || true)

    if [[ -n "$size_metrics" ]]; then
        echo -e "${CYAN}Found size metrics:${NC}"
        echo "  $size_metrics"
        found_metrics=1
    fi

    # Pattern: time metrics
    local time_metrics
    time_metrics=$(echo "$text" | grep -oiE "[0-9]+(\.[0-9]+)?\s*(ms|milliseconds|seconds|s|minutes|min)" || true)

    if [[ -n "$time_metrics" ]]; then
        echo -e "${CYAN}Found time metrics:${NC}"
        echo "  $time_metrics"
        found_metrics=1
    fi

    if [[ $found_metrics -eq 0 ]]; then
        echo -e "${YELLOW}No metrics found in text.${NC}"
        echo '{"has_metrics": false}'
    else
        echo ""
        echo '{"has_metrics": true}'
    fi
    echo ""
}

# Show help
cmd_help() {
    cat << 'EOF'
STUDIO Learnings Utilities - Capture and Apply Project Learnings
=================================================================

"Learn once, apply forever."

Usage: ./learnings.sh <command> [arguments]

Commands:
  init                              Initialize learnings directory
  add <domain> <title> [body]       Add a learning entry
  list [domain]                     List learnings (all domains or specific)
  count                             Count learnings per domain
  read <domain>                     Read raw domain file contents
  inject [domains...]               Generate injection block for agent prompts
  detect <goal>                     Detect relevant domains from goal text
  search <query>                    Search learnings by keyword
  classify <text>                   Classify learning and determine destination
  check-duplicate <title>           Check for duplicate entries in knowledge base
  extract-metrics <text>            Extract before/after metrics from text
  help                              Show this help message

Domains:
  global       Project-wide patterns and conventions
  frontend     UI/component patterns, styling
  backend      API patterns, service architecture
  testing      Test strategies, coverage patterns
  security     Security patterns, vulnerability mitigations
  performance  Optimization patterns, efficiency lessons

Integrations:
  Use "integration:<name>" for library-specific learnings
  Example: ./learnings.sh add integration:nextjs "Server Actions" "..."

Classification Destinations:
  performance_delta   Metrics with before/after values → STUDIO_KNOWLEDGE_BASE.md
  pending_queue       Errors/constraints (1st occurrence) → STUDIO_KNOWLEDGE_BASE.md
  slop_ledger         Naming/structural issues → STUDIO_KNOWLEDGE_BASE.md
  domain_learnings    Reusable patterns → studio/learnings/{domain}.md

Examples:
  ./learnings.sh init
  ./learnings.sh add frontend "Form Validation Pattern" "**Context:** Building user registration..."
  ./learnings.sh add integration:prisma "Relation Loading" "Use include for eager loading..."
  ./learnings.sh list
  ./learnings.sh inject frontend backend
  ./learnings.sh detect "Create a React component for user profile"
  ./learnings.sh search "validation"
  ./learnings.sh classify "Fixed memory leak - heap reduced from 512MB to 128MB"
  ./learnings.sh check-duplicate "Memory Optimization Pattern"
  ./learnings.sh extract-metrics "LCP improved from 2.4s to 1.1s after lazy loading"

Environment Variables:
  STUDIO_DIR    Base directory for STUDIO state (default: studio)

EOF
}

# Main dispatch
main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init)
            cmd_init "$@"
            ;;
        add)
            cmd_add "$@"
            ;;
        list|ls)
            cmd_list "$@"
            ;;
        count)
            cmd_count "$@"
            ;;
        read|cat)
            cmd_read "$@"
            ;;
        inject)
            cmd_inject "$@"
            ;;
        detect)
            cmd_detect "$@"
            ;;
        search)
            cmd_search "$@"
            ;;
        classify)
            cmd_classify "$@"
            ;;
        check-duplicate|checkdup|dup)
            cmd_check_duplicate "$@"
            ;;
        extract-metrics|metrics)
            cmd_extract_metrics "$@"
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
