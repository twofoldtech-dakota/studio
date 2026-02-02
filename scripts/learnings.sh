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

Examples:
  ./learnings.sh init
  ./learnings.sh add frontend "Form Validation Pattern" "**Context:** Building user registration..."
  ./learnings.sh add integration:prisma "Relation Loading" "Use include for eager loading..."
  ./learnings.sh list
  ./learnings.sh inject frontend backend
  ./learnings.sh detect "Create a React component for user profile"
  ./learnings.sh search "validation"

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
