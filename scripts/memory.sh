#!/usr/bin/env bash
#
# STUDIO Memory Utilities - Persistent User Preferences
# ======================================================
#
# This script provides helper functions for managing the Memory system.
# It enables persistent user preferences and technical constraints across sessions.
#
# Usage:
#   ./memory.sh init                          Initialize memory directory
#   ./memory.sh add <domain> <rule> [cat]     Add a rule to a domain
#   ./memory.sh remove <domain> <pattern>     Remove rules matching pattern
#   ./memory.sh list [domain]                 List rules (all or specific domain)
#   ./memory.sh count                         Count rules per domain
#   ./memory.sh read <domain>                 Read domain file contents
#   ./memory.sh inject <domains...>           Output injection block for agents
#   ./memory.sh detect <goal>                 Detect relevant domains from goal
#   ./memory.sh history [n]                   Show last n rule changes
#   ./memory.sh clean                         Remove empty categories
#
# Rules are stored in studio/memory/ as human-readable Markdown files.
#
# Philosophy: "What is written shall be remembered. What is remembered shall guide."
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-studio}"
MEMORY_DIR="${STUDIO_DIR}/memory"
META_FILE="${MEMORY_DIR}/.memory-meta.json"

# Valid domains
VALID_DOMAINS=("global" "frontend" "backend" "testing" "security" "devops")

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
log_memory() {
    echo -e "${MAGENTA}[Memory]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[Memory]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[Memory]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[Memory]${NC} $*" >&2
}

# Get current timestamp in ISO format
get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
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

# Initialize the rules directory and files
cmd_init() {
    log_memory "Initializing rules directory..."

    mkdir -p "$MEMORY_DIR"

    local now
    now=$(get_timestamp)

    # Create domain files if they don't exist
    for domain in "${VALID_DOMAINS[@]}"; do
        local file="${MEMORY_DIR}/${domain}.md"
        if [[ ! -f "$file" ]]; then
            local title
            case "$domain" in
                global)   title="Global Rules" ;;
                frontend) title="Frontend Rules" ;;
                backend)  title="Backend Rules" ;;
                testing)  title="Testing Rules" ;;
                security) title="Security Rules" ;;
                devops)   title="DevOps Rules" ;;
            esac

            cat > "$file" << EOF
# ${title}

> Last updated: ${now}
> Rule count: 0

<!-- Add rules as bullet points under categorized headers -->
<!-- Example:
## Component Patterns
- Use functional components with hooks
- Prefer composition over inheritance
-->

EOF
            log_memory "Created ${domain}.md"
        fi
    done

    # Create metadata file if it doesn't exist
    if [[ ! -f "$META_FILE" ]]; then
        cat > "$META_FILE" << EOF
{
  "version": "1.0.0",
  "created_at": "${now}",
  "last_modified": "${now}",
  "rule_count": {
    "global": 0,
    "frontend": 0,
    "backend": 0,
    "testing": 0,
    "security": 0,
    "devops": 0
  },
  "history": []
}
EOF
        log_memory "Created metadata file"
    fi

    log_success "Rules directory initialized at ${MEMORY_DIR}/"
}

# Add a rule to a domain file
cmd_add() {
    local domain="${1:-}"
    local rule="${2:-}"
    local category="${3:-General}"

    if [[ -z "$domain" || -z "$rule" ]]; then
        log_error "Usage: ./memory.sh add <domain> <rule> [category]"
        log_error "Domains: ${VALID_DOMAINS[*]}"
        exit 1
    fi

    if ! validate_domain "$domain"; then
        log_error "Invalid domain: ${domain}"
        log_error "Valid domains: ${VALID_DOMAINS[*]}"
        exit 1
    fi

    local file="${MEMORY_DIR}/${domain}.md"

    if [[ ! -f "$file" ]]; then
        log_error "Domain file not found. Run './memory.sh init' first."
        exit 1
    fi

    local now
    now=$(get_timestamp)

    # Check if category exists, if not add it
    if ! grep -q "^## ${category}$" "$file"; then
        # Add category before the end of file
        echo "" >> "$file"
        echo "## ${category}" >> "$file"
    fi

    # Find the category and append the rule after it
    # Using a temp file for safe editing
    local tmp_file
    tmp_file=$(mktemp)
    local in_category=0
    local rule_added=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        echo "$line" >> "$tmp_file"

        if [[ "$line" == "## ${category}" ]]; then
            in_category=1
        elif [[ $in_category -eq 1 && $rule_added -eq 0 ]]; then
            # Add the rule right after the category header
            echo "- ${rule}" >> "$tmp_file"
            rule_added=1
            in_category=0
        fi
    done < "$file"

    # If rule wasn't added (category was at end of file), add it now
    if [[ $rule_added -eq 0 ]]; then
        echo "- ${rule}" >> "$tmp_file"
    fi

    mv "$tmp_file" "$file"

    # Update timestamp in file
    sed -i "s/^> Last updated:.*/> Last updated: ${now}/" "$file"

    # Update rule count in file
    local count
    count=$(grep -c "^- " "$file" 2>/dev/null || echo 0)
    sed -i "s/^> Rule count:.*/> Rule count: ${count}/" "$file"

    # Update metadata
    if command -v jq &> /dev/null && [[ -f "$META_FILE" ]]; then
        local meta_tmp
        meta_tmp=$(mktemp)
        jq --arg domain "$domain" \
           --arg rule "$rule" \
           --arg ts "$now" \
           --arg cat "$category" \
           '.last_modified = $ts |
            .rule_count[$domain] = (.rule_count[$domain] + 1) |
            .history += [{
                "timestamp": $ts,
                "domain": $domain,
                "action": "add",
                "rule": $rule,
                "category": $cat
            }]' "$META_FILE" > "$meta_tmp"
        mv "$meta_tmp" "$META_FILE"
    fi

    log_success "Rule added to ${domain}.md under [${category}]"
    echo -e "  ${CYAN}\"${rule}\"${NC}"
}

# Remove rules matching a pattern
cmd_remove() {
    local domain="${1:-}"
    local pattern="${2:-}"

    if [[ -z "$domain" || -z "$pattern" ]]; then
        log_error "Usage: ./memory.sh remove <domain> <pattern>"
        exit 1
    fi

    if ! validate_domain "$domain"; then
        log_error "Invalid domain: ${domain}"
        exit 1
    fi

    local file="${MEMORY_DIR}/${domain}.md"

    if [[ ! -f "$file" ]]; then
        log_error "Domain file not found: ${file}"
        exit 1
    fi

    local now
    now=$(get_timestamp)

    # Count matches before removal
    local before_count
    before_count=$(grep -c "^- .*${pattern}" "$file" 2>/dev/null || echo 0)

    if [[ $before_count -eq 0 ]]; then
        log_warn "No rules matching '${pattern}' found in ${domain}.md"
        return 0
    fi

    # Remove matching lines
    local tmp_file
    tmp_file=$(mktemp)
    grep -v "^- .*${pattern}" "$file" > "$tmp_file" || true
    mv "$tmp_file" "$file"

    # Update timestamp
    sed -i "s/^> Last updated:.*/> Last updated: ${now}/" "$file"

    # Update rule count
    local count
    count=$(grep -c "^- " "$file" 2>/dev/null || echo 0)
    sed -i "s/^> Rule count:.*/> Rule count: ${count}/" "$file"

    # Update metadata
    if command -v jq &> /dev/null && [[ -f "$META_FILE" ]]; then
        local meta_tmp
        meta_tmp=$(mktemp)
        jq --arg domain "$domain" \
           --arg pattern "$pattern" \
           --arg ts "$now" \
           --argjson removed "$before_count" \
           '.last_modified = $ts |
            .rule_count[$domain] = ([.rule_count[$domain] - $removed, 0] | max) |
            .history += [{
                "timestamp": $ts,
                "domain": $domain,
                "action": "remove",
                "rule": ("Removed \($removed) rules matching: " + $pattern)
            }]' "$META_FILE" > "$meta_tmp"
        mv "$meta_tmp" "$META_FILE"
    fi

    log_success "Removed ${before_count} rule(s) matching '${pattern}' from ${domain}.md"
}

# List rules
cmd_list() {
    local domain="${1:-all}"

    if [[ ! -d "$MEMORY_DIR" ]]; then
        log_error "Rules directory not found. Run './memory.sh init' first."
        exit 1
    fi

    echo ""
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}${BOLD}                         📜 MEMORY RULES                           ${NC}"
    echo -e "${MAGENTA}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ "$domain" == "all" ]]; then
        for d in "${VALID_DOMAINS[@]}"; do
            local file="${MEMORY_DIR}/${d}.md"
            if [[ -f "$file" ]]; then
                local count
                count=$(grep -c "^- " "$file" 2>/dev/null || echo 0)
                if [[ $count -gt 0 ]]; then
                    echo -e "${CYAN}━━━ ${d^^} (${count} rules) ━━━${NC}"
                    grep "^- " "$file" | sed 's/^/  /'
                    echo ""
                fi
            fi
        done
    else
        if ! validate_domain "$domain"; then
            log_error "Invalid domain: ${domain}"
            exit 1
        fi

        local file="${MEMORY_DIR}/${domain}.md"
        if [[ -f "$file" ]]; then
            cat "$file"
        else
            log_error "Domain file not found: ${file}"
            exit 1
        fi
    fi
}

# Count rules per domain
cmd_count() {
    if [[ ! -d "$MEMORY_DIR" ]]; then
        log_error "Rules directory not found. Run './memory.sh init' first."
        exit 1
    fi

    echo ""
    echo -e "${MAGENTA}MEMORY RULE COUNT${NC}"
    echo "─────────────────"

    local total=0

    for domain in "${VALID_DOMAINS[@]}"; do
        local file="${MEMORY_DIR}/${domain}.md"
        local count=0
        if [[ -f "$file" ]]; then
            count=$(grep -c "^- " "$file" 2>/dev/null || echo 0)
        fi
        printf "  %-12s %3d rules\n" "${domain}:" "$count"
        total=$((total + count))
    done

    echo "─────────────────"
    printf "  %-12s %3d rules\n" "TOTAL:" "$total"
    echo ""
}

# Read domain file contents (raw)
cmd_read() {
    local domain="${1:-}"

    if [[ -z "$domain" ]]; then
        log_error "Usage: ./memory.sh read <domain>"
        exit 1
    fi

    if ! validate_domain "$domain"; then
        log_error "Invalid domain: ${domain}"
        exit 1
    fi

    local file="${MEMORY_DIR}/${domain}.md"

    if [[ -f "$file" ]]; then
        cat "$file"
    else
        log_error "Domain file not found: ${file}"
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

    # Check if any rules exist
    local has_rules=0
    for domain in "${domains[@]}"; do
        local file="${MEMORY_DIR}/${domain}.md"
        if [[ -f "$file" ]]; then
            local count
            count=$(grep -c "^- " "$file" 2>/dev/null || echo 0)
            if [[ $count -gt 0 ]]; then
                has_rules=1
                break
            fi
        fi
    done

    if [[ $has_rules -eq 0 ]]; then
        return 0
    fi

    # Output injection block
    cat << 'EOF'

═══════════════════════════════════════════════════════════════════════════════
                     📜 MANDATORY USER PREFERENCES
                        (From The STUDIO Memory)
═══════════════════════════════════════════════════════════════════════════════

EOF

    for domain in "${domains[@]}"; do
        if ! validate_domain "$domain"; then
            continue
        fi

        local file="${MEMORY_DIR}/${domain}.md"
        if [[ -f "$file" ]]; then
            local count
            count=$(grep -c "^- " "$file" 2>/dev/null || echo 0)
            if [[ $count -gt 0 ]]; then
                local title
                case "$domain" in
                    global)   title="Global Rules" ;;
                    frontend) title="Frontend Rules" ;;
                    backend)  title="Backend Rules" ;;
                    testing)  title="Testing Rules" ;;
                    security) title="Security Rules" ;;
                    devops)   title="DevOps Rules" ;;
                esac

                echo "## ${title}"
                # Extract just the rules (lines starting with -)
                grep "^- " "$file"
                echo ""
            fi
        fi
    done

    cat << 'EOF'
═══════════════════════════════════════════════════════════════════════════════
IMPORTANT: These rules are NON-NEGOTIABLE. They represent user preferences
learned from previous sessions. Always follow these rules unless the user
explicitly overrides them for this specific task.
═══════════════════════════════════════════════════════════════════════════════

EOF
}

# Detect relevant domains from goal text
cmd_detect() {
    local goal="${1:-}"

    if [[ -z "$goal" ]]; then
        log_error "Usage: ./memory.sh detect <goal>"
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

    # DevOps signals
    if echo "$goal_lower" | grep -qE "(deploy|docker|ci|cd|cicd|pipeline|infrastructure|kubernetes|k8s|aws|azure|gcp|terraform|devops|container)"; then
        detected+=("devops")
    fi

    # Output detected domains (one per line for easy parsing)
    for d in "${detected[@]}"; do
        echo "$d"
    done
}

# Show history of rule changes
cmd_history() {
    local count="${1:-10}"

    if [[ ! -f "$META_FILE" ]]; then
        log_error "Metadata file not found. Run './memory.sh init' first."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required for history command"
        exit 1
    fi

    echo ""
    echo -e "${MAGENTA}MEMORY HISTORY${NC} (last ${count} changes)"
    echo "────────────────────────────────────────────────────────────────"

    jq -r --argjson n "$count" '
        .history |
        reverse |
        .[:$n] |
        .[] |
        "\(.timestamp) [\(.domain)] \(.action): \(.rule)"
    ' "$META_FILE" 2>/dev/null || echo "No history available."

    echo ""
}

# Clean empty categories
cmd_clean() {
    log_memory "Cleaning empty categories..."

    local cleaned=0

    for domain in "${VALID_DOMAINS[@]}"; do
        local file="${MEMORY_DIR}/${domain}.md"
        if [[ -f "$file" ]]; then
            # Remove empty category sections (## Header followed by another ## or EOF with no rules between)
            local tmp_file
            tmp_file=$(mktemp)

            awk '
                /^## / {
                    if (header != "" && rules == 0) {
                        # Previous header had no rules, skip it
                    } else if (header != "") {
                        print header
                        for (i = 1; i <= rules; i++) {
                            print rule_lines[i]
                        }
                    }
                    header = $0
                    rules = 0
                    delete rule_lines
                    next
                }
                /^- / {
                    rules++
                    rule_lines[rules] = $0
                    next
                }
                {
                    if (header != "" && rules > 0) {
                        print header
                        for (i = 1; i <= rules; i++) {
                            print rule_lines[i]
                        }
                        header = ""
                        rules = 0
                    }
                    print
                }
                END {
                    if (header != "" && rules > 0) {
                        print header
                        for (i = 1; i <= rules; i++) {
                            print rule_lines[i]
                        }
                    }
                }
            ' "$file" > "$tmp_file"

            if ! diff -q "$file" "$tmp_file" > /dev/null 2>&1; then
                mv "$tmp_file" "$file"
                ((cleaned++))
            else
                rm "$tmp_file"
            fi
        fi
    done

    log_success "Cleaned ${cleaned} file(s)"
}

# Show help
cmd_help() {
    cat << 'EOF'
STUDIO Memory Utilities - The Self-Learning Memory Module
=========================================================

"What is written shall be remembered. What is remembered shall guide."

Usage: ./memory.sh <command> [arguments]

Commands:
  init                          Initialize rules directory and domain files
  add <domain> <rule> [cat]     Add a rule to domain under optional category
  remove <domain> <pattern>     Remove rules matching pattern from domain
  list [domain]                 List rules (all domains or specific one)
  count                         Count rules per domain
  read <domain>                 Read raw domain file contents
  inject <domains...>           Generate injection block for agent prompts
  detect <goal>                 Detect relevant domains from goal text
  history [n]                   Show last n rule changes (default: 10)
  clean                         Remove empty categories from files
  help                          Show this help message

Domains:
  global      Project-wide patterns, tone, conventions
  frontend    UI/UX preferences, component patterns, styling
  backend     Architecture, API, data patterns
  testing     QA requirements, coverage rules
  security    Security constraints, auth patterns
  devops      Deployment, infrastructure preferences

Examples:
  ./memory.sh init
  ./memory.sh add frontend "Use functional components" "Component Patterns"
  ./memory.sh add backend "Use Prisma for ORM" "Data Layer"
  ./memory.sh list
  ./memory.sh inject frontend backend
  ./memory.sh detect "Create a React component for user profile"
  ./memory.sh remove frontend "class components"
  ./memory.sh history 5

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
        remove|rm)
            cmd_remove "$@"
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
        history)
            cmd_history "$@"
            ;;
        clean)
            cmd_clean "$@"
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
