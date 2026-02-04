#!/usr/bin/env bash
# ============================================================================
# error-matcher.sh - Error Pattern Matcher
# ============================================================================
# Matches build/command output against known error patterns and returns
# fix suggestions. Uses data/error-patterns.yaml as the pattern database.
#
# Usage:
#   ./scripts/error-matcher.sh --input "error output text"
#   ./scripts/error-matcher.sh --file /path/to/error.log
#   echo "error text" | ./scripts/error-matcher.sh --stdin
#   ./scripts/error-matcher.sh --list-categories
#
# Output: JSON with matched patterns and fix suggestions
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_FILE="${SCRIPT_DIR}/../data/error-patterns.yaml"
STUDIO_DIR="${STUDIO_DIR:-.studio}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# HELP
# ============================================================================

show_help() {
    cat << 'EOF'
error-matcher.sh - Error Pattern Matcher

USAGE:
    ./scripts/error-matcher.sh --input "error output text"
    ./scripts/error-matcher.sh --file /path/to/error.log
    echo "error text" | ./scripts/error-matcher.sh --stdin
    ./scripts/error-matcher.sh --list-categories

OPTIONS:
    --input <text>        Error text to match against patterns
    --file <path>         File containing error output to match
    --stdin               Read error output from stdin
    --json                Output only JSON, no formatted display
    --category <cat>      Only match patterns in this category
    --list-categories     List all available error categories
    --show-pattern <id>   Show details for a specific pattern
    --help                Show this help message

OUTPUT (JSON):
    {
        "matched": true,
        "matches": [
            {
                "id": "npm_module_not_found",
                "category": "dependency",
                "pattern": "Cannot find module '(.+)'",
                "why": "A required package is not installed...",
                "fix": "1. Check if the package...",
                "auto_fix": "npm install",
                "captures": ["lodash"],
                "line": "Cannot find module 'lodash'"
            }
        ],
        "unmatched_lines": ["some other error"]
    }

EXAMPLES:
    # Match error text directly
    ./scripts/error-matcher.sh --input "Cannot find module 'lodash'"

    # Match from a file
    ./scripts/error-matcher.sh --file build-error.log

    # Pipe from a command
    npm run build 2>&1 | ./scripts/error-matcher.sh --stdin

    # Only dependency errors
    ./scripts/error-matcher.sh --input "error text" --category dependency
EOF
}

# ============================================================================
# PATTERN LOADING
# ============================================================================

# Check if yq is available
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo "Error: yq is required for parsing YAML patterns" >&2
        echo "Install with: brew install yq (macOS) or apt install yq (Linux)" >&2
        exit 1
    fi
}

# Load patterns from YAML file
load_patterns() {
    if [[ ! -f "$PATTERNS_FILE" ]]; then
        echo "Error: Patterns file not found: $PATTERNS_FILE" >&2
        exit 1
    fi
    
    # Convert YAML patterns to JSON for easier processing
    yq -o=json '.patterns' "$PATTERNS_FILE"
}

# List all categories
list_categories() {
    if [[ ! -f "$PATTERNS_FILE" ]]; then
        echo "Error: Patterns file not found: $PATTERNS_FILE" >&2
        exit 1
    fi
    
    echo -e "${BLUE}Available Error Categories:${NC}"
    echo ""
    yq -o=json '.categories' "$PATTERNS_FILE" | jq -r 'to_entries[] | "  \(.key): \(.value)"'
}

# Show details for a specific pattern
show_pattern() {
    local pattern_id="$1"
    
    local pattern_json
    pattern_json=$(yq -o=json ".patterns[] | select(.id == \"$pattern_id\")" "$PATTERNS_FILE" 2>/dev/null)
    
    if [[ -z "$pattern_json" || "$pattern_json" == "null" ]]; then
        echo "Error: Pattern not found: $pattern_id" >&2
        exit 1
    fi
    
    local id category pattern why fix auto_fix
    id=$(echo "$pattern_json" | jq -r '.id')
    category=$(echo "$pattern_json" | jq -r '.category')
    pattern=$(echo "$pattern_json" | jq -r '.pattern')
    why=$(echo "$pattern_json" | jq -r '.why')
    fix=$(echo "$pattern_json" | jq -r '.fix')
    auto_fix=$(echo "$pattern_json" | jq -r '.auto_fix // "none"')
    
    echo -e "${BLUE}Pattern: ${CYAN}$id${NC}"
    echo -e "${YELLOW}Category:${NC} $category"
    echo -e "${YELLOW}Regex:${NC} $pattern"
    echo ""
    echo -e "${YELLOW}Why this happens:${NC}"
    echo "$why"
    echo ""
    echo -e "${YELLOW}How to fix:${NC}"
    echo "$fix"
    echo ""
    if [[ "$auto_fix" != "none" ]]; then
        echo -e "${GREEN}Auto-fix command:${NC} $auto_fix"
    fi
}

# ============================================================================
# PATTERN MATCHING
# ============================================================================

# Match input against all patterns
match_patterns() {
    local input="$1"
    local category_filter="${2:-}"
    local json_only="${3:-false}"
    
    check_yq
    
    local patterns_json
    patterns_json=$(load_patterns)
    
    local matches=()
    local unmatched_lines=()
    local matched_lines=()
    
    # Process each line of input
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        
        local line_matched="false"
        
        # Check against each pattern
        local pattern_count
        pattern_count=$(echo "$patterns_json" | jq 'length')
        
        for ((i=0; i<pattern_count; i++)); do
            local pattern_obj
            pattern_obj=$(echo "$patterns_json" | jq ".[$i]")
            
            local id category pattern why fix auto_fix
            id=$(echo "$pattern_obj" | jq -r '.id')
            category=$(echo "$pattern_obj" | jq -r '.category')
            pattern=$(echo "$pattern_obj" | jq -r '.pattern')
            why=$(echo "$pattern_obj" | jq -r '.why')
            fix=$(echo "$pattern_obj" | jq -r '.fix')
            auto_fix=$(echo "$pattern_obj" | jq -r '.auto_fix // null')
            
            # Skip if category filter doesn't match
            if [[ -n "$category_filter" && "$category" != "$category_filter" ]]; then
                continue
            fi
            
            # Try to match the pattern
            if echo "$line" | grep -qE "$pattern" 2>/dev/null; then
                line_matched="true"
                
                # Extract capture groups
                local captures
                captures=$(echo "$line" | grep -oE "$pattern" 2>/dev/null | head -1 || echo "")
                
                # Build match object
                local match_obj
                match_obj=$(jq -n \
                    --arg id "$id" \
                    --arg category "$category" \
                    --arg pattern "$pattern" \
                    --arg why "$why" \
                    --arg fix "$fix" \
                    --arg auto_fix "$auto_fix" \
                    --arg captures "$captures" \
                    --arg line "$line" \
                    '{
                        id: $id,
                        category: $category,
                        pattern: $pattern,
                        why: $why,
                        fix: $fix,
                        auto_fix: (if $auto_fix == "null" then null else $auto_fix end),
                        captures: $captures,
                        line: $line
                    }')
                
                matches+=("$match_obj")
                matched_lines+=("$line")
                break  # Only match first pattern per line
            fi
        done
        
        if [[ "$line_matched" == "false" ]]; then
            unmatched_lines+=("$line")
        fi
    done <<< "$input"
    
    # Build result JSON
    local matches_json="[]"
    for m in "${matches[@]:-}"; do
        [[ -z "$m" ]] && continue
        matches_json=$(echo "$matches_json" | jq --argjson m "$m" '. + [$m]')
    done
    
    local unmatched_json="[]"
    for u in "${unmatched_lines[@]:-}"; do
        [[ -z "$u" ]] && continue
        unmatched_json=$(echo "$unmatched_json" | jq --arg u "$u" '. + [$u]')
    done
    
    local has_matches="false"
    if [[ ${#matches[@]} -gt 0 ]]; then
        has_matches="true"
    fi
    
    local result
    result=$(jq -n \
        --argjson matched "$has_matches" \
        --argjson matches "$matches_json" \
        --argjson unmatched "$unmatched_json" \
        '{
            matched: $matched,
            match_count: ($matches | length),
            matches: $matches,
            unmatched_lines: $unmatched
        }')
    
    if [[ "$json_only" == "true" ]]; then
        echo "$result"
    else
        display_matches "$result"
    fi
}

# ============================================================================
# DISPLAY
# ============================================================================

display_matches() {
    local result_json="$1"
    
    local matched match_count
    matched=$(echo "$result_json" | jq -r '.matched')
    match_count=$(echo "$result_json" | jq '.match_count')
    
    if [[ "$matched" == "false" ]]; then
        echo -e "${YELLOW}No known error patterns matched.${NC}"
        echo ""
        echo "Unmatched lines:"
        echo "$result_json" | jq -r '.unmatched_lines[]' | head -10
        return
    fi
    
    echo -e "${RED}Found $match_count matching error pattern(s):${NC}"
    echo ""
    
    # Display each match
    echo "$result_json" | jq -c '.matches[]' | while read -r match; do
        local id category why fix auto_fix line
        id=$(echo "$match" | jq -r '.id')
        category=$(echo "$match" | jq -r '.category')
        why=$(echo "$match" | jq -r '.why')
        fix=$(echo "$match" | jq -r '.fix')
        auto_fix=$(echo "$match" | jq -r '.auto_fix // "none"')
        line=$(echo "$match" | jq -r '.line')
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}Error:${NC} $line"
        echo -e "${BLUE}Pattern:${NC} $id (${category})"
        echo ""
        echo -e "${YELLOW}Why:${NC} $why"
        echo ""
        echo -e "${GREEN}Fix:${NC}"
        echo "$fix" | sed 's/^/  /'
        
        if [[ "$auto_fix" != "none" && "$auto_fix" != "null" ]]; then
            echo ""
            echo -e "${GREEN}Auto-fix:${NC} $auto_fix"
        fi
        echo ""
    done
    
    # Output JSON at the end for programmatic use
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}JSON Output:${NC}"
    echo "$result_json"
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

main() {
    local input=""
    local file=""
    local use_stdin="false"
    local json_only="false"
    local category=""
    local list_cats="false"
    local show_pat=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --input)
                input="$2"
                shift 2
                ;;
            --file)
                file="$2"
                shift 2
                ;;
            --stdin)
                use_stdin="true"
                shift
                ;;
            --json)
                json_only="true"
                shift
                ;;
            --category)
                category="$2"
                shift 2
                ;;
            --list-categories)
                list_cats="true"
                shift
                ;;
            --show-pattern)
                show_pat="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # Handle list categories
    if [[ "$list_cats" == "true" ]]; then
        check_yq
        list_categories
        exit 0
    fi
    
    # Handle show pattern
    if [[ -n "$show_pat" ]]; then
        check_yq
        show_pattern "$show_pat"
        exit 0
    fi
    
    # Get input from file or stdin
    if [[ -n "$file" ]]; then
        if [[ ! -f "$file" ]]; then
            echo "Error: File not found: $file" >&2
            exit 1
        fi
        input=$(cat "$file")
    elif [[ "$use_stdin" == "true" ]]; then
        input=$(cat)
    fi
    
    # Validate we have input
    if [[ -z "$input" ]]; then
        echo "Error: No input provided. Use --input, --file, or --stdin" >&2
        show_help
        exit 1
    fi
    
    # Run matching
    match_patterns "$input" "$category" "$json_only"
}

main "$@"
