#!/usr/bin/env bash
#
# STUDIO Skills Manager - Skill Detection and Loading
# ====================================================
#
# This script provides skill detection and loading utilities for the
# orchestration system. Skills are YAML files in skills/ that provide
# domain-specific guidance, team member references, and injection content.
#
# Usage:
#   ./skills.sh detect <goal>       Detect matching skills for a goal
#   ./skills.sh load <skill>        Load a skill's full content
#   ./skills.sh inject <skill>      Get injection content for a skill
#   ./skills.sh inject-all <skills> Get combined injection for multiple skills
#   ./skills.sh team <skill>        List team members for a skill
#   ./skills.sh list                List all available skills
#   ./skills.sh validate [skill]    Validate skill(s) against schema
#
# Environment:
#   STUDIO_DIR        Base directory for STUDIO state (default: .studio)
#   SKILLS_DIR        Directory containing skill YAMLs (default: skills)
#

set -euo pipefail

# Configuration
STUDIO_DIR="${STUDIO_DIR:-.studio}"
SKILLS_DIR="${SKILLS_DIR:-skills}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_PATH="${PROJECT_ROOT}/${SKILLS_DIR}"

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
log_skill() { echo -e "${MAGENTA}[Skills]${NC} $*"; }
log_success() { echo -e "${GREEN}[Skills]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[Skills]${NC} $*" >&2; }
log_error() { echo -e "${RED}[Skills]${NC} $*" >&2; }

# Check for yq (YAML processor)
check_yq() {
    if ! command -v yq &> /dev/null; then
        log_error "yq is required but not installed."
        log_error "Install with: brew install yq (macOS) or snap install yq (Linux)"
        exit 1
    fi
}

# ============================================================================
# SKILL DETECTION
# ============================================================================

# Detect skills matching a goal
# Returns JSON array of matching skills with scores
cmd_detect() {
    local goal="${1:-}"

    if [[ -z "$goal" ]]; then
        log_error "Usage: skills.sh detect <goal>"
        exit 1
    fi

    check_yq

    if [[ ! -d "$SKILLS_PATH" ]]; then
        log_warn "Skills directory not found: $SKILLS_PATH"
        echo "[]"
        return 0
    fi

    local goal_lower
    goal_lower=$(echo "$goal" | tr '[:upper:]' '[:lower:]')

    local matches="[]"

    # Iterate through all skill files
    for skill_file in "$SKILLS_PATH"/*.yaml; do
        if [[ ! -f "$skill_file" ]]; then
            continue
        fi

        local skill_name
        skill_name=$(yq -r '.name // ""' "$skill_file")

        if [[ -z "$skill_name" ]]; then
            continue
        fi

        local score=0
        local matched_triggers="[]"

        # Check keyword triggers
        local keywords
        keywords=$(yq -r '.triggers.keywords[]' "$skill_file" 2>/dev/null || echo "")

        for keyword in $keywords; do
            if echo "$goal_lower" | grep -qi "$keyword"; then
                score=$((score + 20))
                matched_triggers=$(echo "$matched_triggers" | jq --arg kw "$keyword" '. + ["keyword:" + $kw]')
            fi
        done

        # Check domain triggers
        local domains
        domains=$(yq -r '.triggers.domains[]' "$skill_file" 2>/dev/null || echo "")

        for domain in $domains; do
            if echo "$goal_lower" | grep -qi "$domain"; then
                score=$((score + 15))
                matched_triggers=$(echo "$matched_triggers" | jq --arg d "$domain" '. + ["domain:" + $d]')
            fi
        done

        # Get priority (default 50)
        local priority
        priority=$(yq -r '.priority // 50' "$skill_file" 2>/dev/null || echo "50")

        # Only include if there were actual keyword/domain matches
        # (not just priority bonus)
        if [[ $score -gt 0 ]]; then
            # Add priority bonus (scaled to 0-10 range) only if there were matches
            local priority_bonus=$((priority / 10))
            score=$((score + priority_bonus))
            local description
            description=$(yq -r '.description // ""' "$skill_file")

            matches=$(echo "$matches" | jq \
                --arg name "$skill_name" \
                --argjson score "$score" \
                --argjson priority "$priority" \
                --arg desc "$description" \
                --argjson triggers "$matched_triggers" \
                '. + [{
                    "skill": $name,
                    "score": $score,
                    "priority": $priority,
                    "description": $desc,
                    "matched_triggers": $triggers
                }]')
        fi
    done

    # Sort by score descending
    echo "$matches" | jq 'sort_by(-.score)'
}

# ============================================================================
# SKILL LOADING
# ============================================================================

# Load full skill content as JSON
cmd_load() {
    local skill="${1:-}"

    if [[ -z "$skill" ]]; then
        log_error "Usage: skills.sh load <skill>"
        exit 1
    fi

    check_yq

    local skill_file="${SKILLS_PATH}/${skill}.yaml"

    if [[ ! -f "$skill_file" ]]; then
        log_error "Skill not found: $skill"
        exit 1
    fi

    # Convert YAML to JSON
    yq -o=json '.' "$skill_file"
}

# ============================================================================
# INJECTION CONTENT
# ============================================================================

# Get injection content for a single skill
cmd_inject() {
    local skill="${1:-}"

    if [[ -z "$skill" ]]; then
        log_error "Usage: skills.sh inject <skill>"
        exit 1
    fi

    check_yq

    local skill_file="${SKILLS_PATH}/${skill}.yaml"

    if [[ ! -f "$skill_file" ]]; then
        log_error "Skill not found: $skill"
        exit 1
    fi

    local name
    name=$(yq -r '.name // ""' "$skill_file")

    local questions
    questions=$(yq -r '.injection.questions // ""' "$skill_file")

    local guidelines
    guidelines=$(yq -r '.injection.guidelines // ""' "$skill_file")

    local checklist
    checklist=$(yq -r '.injection.checklist[]' "$skill_file" 2>/dev/null || echo "")

    # Build injection content
    echo "---"
    echo "## Skill: ${name}"
    echo ""

    if [[ -n "$questions" ]]; then
        echo "$questions"
        echo ""
    fi

    if [[ -n "$guidelines" ]]; then
        echo "$guidelines"
        echo ""
    fi

    if [[ -n "$checklist" ]]; then
        echo "### Verification Checklist"
        echo ""
        while IFS= read -r item; do
            if [[ -n "$item" ]]; then
                echo "- [ ] $item"
            fi
        done <<< "$checklist"
        echo ""
    fi

    echo "---"
}

# Get combined injection for multiple skills
cmd_inject_all() {
    local skills="${1:-}"

    if [[ -z "$skills" ]]; then
        log_error "Usage: skills.sh inject-all <skill1,skill2,...>"
        exit 1
    fi

    check_yq

    # Parse comma-separated skills
    IFS=',' read -ra skill_list <<< "$skills"

    echo "# Active Skills: ${skills}"
    echo ""

    for skill in "${skill_list[@]}"; do
        skill=$(echo "$skill" | tr -d ' ')  # Trim whitespace
        local skill_file="${SKILLS_PATH}/${skill}.yaml"

        if [[ -f "$skill_file" ]]; then
            cmd_inject "$skill"
            echo ""
        else
            log_warn "Skill not found: $skill"
        fi
    done
}

# ============================================================================
# TEAM MEMBERS
# ============================================================================

# List team members for a skill
cmd_team() {
    local skill="${1:-}"

    if [[ -z "$skill" ]]; then
        log_error "Usage: skills.sh team <skill>"
        exit 1
    fi

    check_yq

    local skill_file="${SKILLS_PATH}/${skill}.yaml"

    if [[ ! -f "$skill_file" ]]; then
        log_error "Skill not found: $skill"
        exit 1
    fi

    # Extract team members as JSON
    yq -o=json '.team_members // []' "$skill_file"
}

# ============================================================================
# LIST SKILLS
# ============================================================================

# List all available skills
cmd_list() {
    check_yq

    if [[ ! -d "$SKILLS_PATH" ]]; then
        log_warn "Skills directory not found: $SKILLS_PATH"
        echo "[]"
        return 0
    fi

    local skills="[]"

    for skill_file in "$SKILLS_PATH"/*.yaml; do
        if [[ ! -f "$skill_file" ]]; then
            continue
        fi

        local name
        name=$(yq -r '.name // ""' "$skill_file")

        local description
        description=$(yq -r '.description // ""' "$skill_file")

        local priority
        priority=$(yq -r '.priority // 50' "$skill_file")

        local keyword_count
        keyword_count=$(yq -r '.triggers.keywords | length // 0' "$skill_file")

        if [[ -n "$name" ]]; then
            skills=$(echo "$skills" | jq \
                --arg name "$name" \
                --arg desc "$description" \
                --argjson priority "$priority" \
                --argjson keywords "$keyword_count" \
                '. + [{
                    "name": $name,
                    "description": $desc,
                    "priority": $priority,
                    "keyword_count": $keywords
                }]')
        fi
    done

    # Sort by priority descending
    echo "$skills" | jq 'sort_by(-.priority)'
}

# ============================================================================
# VALIDATION
# ============================================================================

# Validate skill(s) against schema
cmd_validate() {
    local skill="${1:-}"

    check_yq

    local schema_file="${PROJECT_ROOT}/schemas/skill.schema.json"

    if [[ ! -f "$schema_file" ]]; then
        log_error "Schema file not found: $schema_file"
        exit 1
    fi

    local files_to_check=()

    if [[ -z "$skill" ]]; then
        # Validate all skills
        for f in "$SKILLS_PATH"/*.yaml; do
            [[ -f "$f" ]] && files_to_check+=("$f")
        done
    else
        files_to_check=("${SKILLS_PATH}/${skill}.yaml")
    fi

    local all_valid=true

    for skill_file in "${files_to_check[@]}"; do
        if [[ ! -f "$skill_file" ]]; then
            log_error "File not found: $skill_file"
            all_valid=false
            continue
        fi

        local skill_name
        skill_name=$(basename "$skill_file" .yaml)

        # Check required fields
        local name
        name=$(yq -r '.name // ""' "$skill_file")

        local description
        description=$(yq -r '.description // ""' "$skill_file")

        if [[ -z "$name" ]]; then
            log_error "$skill_name: Missing required field 'name'"
            all_valid=false
        fi

        if [[ -z "$description" ]]; then
            log_error "$skill_name: Missing required field 'description'"
            all_valid=false
        fi

        # Validate name pattern
        if [[ -n "$name" ]] && ! [[ "$name" =~ ^[a-z][a-z0-9-]*$ ]]; then
            log_error "$skill_name: 'name' must match pattern ^[a-z][a-z0-9-]*$"
            all_valid=false
        fi

        # Validate priority range
        local priority
        priority=$(yq -r '.priority // 50' "$skill_file")
        if [[ $priority -lt 1 || $priority -gt 100 ]]; then
            log_error "$skill_name: 'priority' must be between 1 and 100"
            all_valid=false
        fi

        # Validate team member tiers
        local tiers
        tiers=$(yq -r '.team_members[].tier' "$skill_file" 2>/dev/null || echo "")
        for tier in $tiers; do
            if [[ "$tier" != "tier1" && "$tier" != "tier2" && "$tier" != "tier3" ]]; then
                log_error "$skill_name: Invalid team member tier '$tier'"
                all_valid=false
            fi
        done

        if [[ "$all_valid" == "true" ]]; then
            log_success "$skill_name: Valid"
        fi
    done

    if [[ "$all_valid" == "true" ]]; then
        log_success "All skills valid"
        return 0
    else
        log_error "Validation failed"
        return 1
    fi
}

# ============================================================================
# HELP
# ============================================================================

cmd_help() {
    cat << 'EOF'
STUDIO Skills Manager - Skill Detection and Loading
====================================================

Manages skill detection, loading, and injection for domain-specific guidance.

Usage: skills.sh <command> [arguments]

Commands:
  detect <goal>          Detect skills matching a goal (returns JSON)
  load <skill>           Load full skill content as JSON
  inject <skill>         Get injection content (questions, guidelines, checklist)
  inject-all <skills>    Get combined injection for comma-separated skills
  team <skill>           List team members for a skill
  list                   List all available skills
  validate [skill]       Validate skill(s) against schema

Detection Scoring:
  - Keyword match: +20 points per match
  - Domain match:  +15 points per match
  - Priority bonus: priority / 10

Skill Structure (YAML):
  name: skill-name
  description: What this skill provides
  team_members:
    - tier: tier1
      member: expert-name
      focus: Area of expertise
  triggers:
    keywords: [auth, login, ...]
    domains: [backend, api, ...]
    file_patterns: ["**/auth/**", ...]
  injection:
    questions: |
      Markdown questions to consider
    guidelines: |
      Markdown guidelines and best practices
    checklist:
      - Verification item 1
      - Verification item 2
  priority: 90  # 1-100, higher = more important

Examples:
  ./skills.sh detect "Add user authentication with JWT"
  ./skills.sh inject security
  ./skills.sh inject-all security,backend
  ./skills.sh team frontend
  ./skills.sh list
  ./skills.sh validate

EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        detect)     cmd_detect "$@" ;;
        load)       cmd_load "$@" ;;
        inject)     cmd_inject "$@" ;;
        inject-all) cmd_inject_all "$@" ;;
        team)       cmd_team "$@" ;;
        list)       cmd_list "$@" ;;
        validate)   cmd_validate "$@" ;;
        help|--help|-h) cmd_help ;;
        *)
            log_error "Unknown command: $cmd"
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
