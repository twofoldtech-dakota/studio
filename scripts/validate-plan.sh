#!/usr/bin/env bash
#
# STUDIO Plan Validation - Verify plan integrity before build
# ===========================================================
#
# Validates that a plan is ready for execution by checking:
# - Required fields exist
# - All steps have success criteria
# - All acceptance criteria have verification methods
# - Dependencies are valid
# - Estimated complexity matches step count
#
# Usage:
#   ./validate-plan.sh --task-id <task_id>
#   ./validate-plan.sh --file <plan.json>
#   ./validate-plan.sh --all                  # Validate all pending plans
#
# Returns:
#   0 - Plan is valid
#   1 - Plan has errors (shows what's wrong)
#   2 - Plan file not found
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STUDIO_DIR="${STUDIO_DIR:-.studio}"

# Source output utilities
source_output() {
    if [[ -f "$SCRIPT_DIR/output.sh" ]]; then
        # We'll call output.sh directly instead of sourcing
        OUTPUT_SH="$SCRIPT_DIR/output.sh"
    else
        OUTPUT_SH=""
    fi
}

source_output

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

# Logging
log_error() { echo -e "${RED}✗${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}⚠${NC} $*" >&2; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_info() { echo -e "${BLUE}→${NC} $*"; }

# Validation result tracking
ERRORS=()
WARNINGS=()

add_error() {
    ERRORS+=("$1")
}

add_warning() {
    WARNINGS+=("$1")
}

# ============================================================================
# VALIDATION CHECKS
# ============================================================================

# Check required top-level fields
check_required_fields() {
    local plan_file="$1"
    local required_fields=("id" "task_id" "goal" "steps")
    
    for field in "${required_fields[@]}"; do
        local value
        value=$(jq -r ".$field // empty" "$plan_file")
        if [[ -z "$value" ]]; then
            add_error "Missing required field: $field"
        fi
    done
    
    # Check steps is an array with items
    local step_count
    step_count=$(jq '.steps | length' "$plan_file" 2>/dev/null || echo "0")
    if [[ "$step_count" -eq 0 ]]; then
        add_error "Plan has no steps defined"
    fi
}

# Check each step has required fields
check_steps() {
    local plan_file="$1"
    local step_count
    step_count=$(jq '.steps | length' "$plan_file")
    
    for ((i=0; i<step_count; i++)); do
        local step_id step_name has_criteria
        step_id=$(jq -r ".steps[$i].id // \"step_$i\"" "$plan_file")
        step_name=$(jq -r ".steps[$i].name // empty" "$plan_file")
        
        # Check step has a name
        if [[ -z "$step_name" ]]; then
            add_warning "Step $step_id missing name"
        fi
        
        # Check step has success criteria
        has_criteria=$(jq ".steps[$i].success_criteria | length // 0" "$plan_file")
        if [[ "$has_criteria" -eq 0 ]]; then
            add_error "Step '$step_id' has no success criteria - cannot verify completion"
        fi
        
        # Check step has action
        local action
        action=$(jq -r ".steps[$i].action // empty" "$plan_file")
        if [[ -z "$action" ]]; then
            add_error "Step '$step_id' has no action defined"
        fi
    done
}

# Check acceptance criteria have verification methods
check_acceptance_criteria() {
    local plan_file="$1"
    local ac_count
    ac_count=$(jq '.acceptance_criteria | length // 0' "$plan_file")
    
    if [[ "$ac_count" -eq 0 ]]; then
        add_warning "No acceptance criteria defined - build completion cannot be verified"
        return
    fi
    
    for ((i=0; i<ac_count; i++)); do
        local ac_id criterion has_verification verification_type
        ac_id=$(jq -r ".acceptance_criteria[$i].id // \"AC-$i\"" "$plan_file")
        criterion=$(jq -r ".acceptance_criteria[$i].criterion // empty" "$plan_file")
        
        if [[ -z "$criterion" ]]; then
            add_error "Acceptance criteria '$ac_id' has no criterion text"
            continue
        fi
        
        # Check verification exists
        has_verification=$(jq ".acceptance_criteria[$i].verification // null" "$plan_file")
        if [[ "$has_verification" == "null" ]]; then
            add_error "Acceptance criteria '$ac_id' has no verification method"
            continue
        fi
        
        # Check verification has type
        verification_type=$(jq -r ".acceptance_criteria[$i].verification.type // empty" "$plan_file")
        if [[ -z "$verification_type" ]]; then
            add_error "Acceptance criteria '$ac_id' verification missing type"
        fi
        
        # Validate verification type has required fields
        case "$verification_type" in
            command)
                local cmd
                cmd=$(jq -r ".acceptance_criteria[$i].verification.command // empty" "$plan_file")
                if [[ -z "$cmd" ]]; then
                    add_error "AC '$ac_id': type=command but no command specified"
                fi
                ;;
            file_exists)
                local path
                path=$(jq -r ".acceptance_criteria[$i].verification.path // empty" "$plan_file")
                if [[ -z "$path" ]]; then
                    add_error "AC '$ac_id': type=file_exists but no path specified"
                fi
                ;;
            file_contains)
                local path pattern
                path=$(jq -r ".acceptance_criteria[$i].verification.path // empty" "$plan_file")
                pattern=$(jq -r ".acceptance_criteria[$i].verification.pattern // empty" "$plan_file")
                if [[ -z "$path" || -z "$pattern" ]]; then
                    add_error "AC '$ac_id': type=file_contains requires path and pattern"
                fi
                ;;
            test_passes)
                local test_cmd
                test_cmd=$(jq -r ".acceptance_criteria[$i].verification.test_command // empty" "$plan_file")
                if [[ -z "$test_cmd" ]]; then
                    add_error "AC '$ac_id': type=test_passes but no test_command specified"
                fi
                ;;
            playwright)
                local url
                url=$(jq -r ".acceptance_criteria[$i].verification.url // empty" "$plan_file")
                if [[ -z "$url" ]]; then
                    add_error "AC '$ac_id': type=playwright but no url specified"
                fi
                ;;
        esac
    done
}

# Check for circular dependencies in steps
check_dependencies() {
    local plan_file="$1"
    local step_count
    step_count=$(jq '.steps | length' "$plan_file")
    
    # Build dependency map
    declare -A deps
    declare -A step_ids
    
    for ((i=0; i<step_count; i++)); do
        local step_id
        step_id=$(jq -r ".steps[$i].id // \"step_$i\"" "$plan_file")
        step_ids["$step_id"]=1
        
        local dep_list
        dep_list=$(jq -r ".steps[$i].depends_on // [] | .[]" "$plan_file" 2>/dev/null || true)
        deps["$step_id"]="$dep_list"
    done
    
    # Check dependencies reference valid steps
    for step_id in "${!deps[@]}"; do
        for dep in ${deps[$step_id]}; do
            if [[ -z "${step_ids[$dep]:-}" ]]; then
                add_error "Step '$step_id' depends on unknown step '$dep'"
            fi
        done
    done
    
    # Simple cycle detection (check if any step depends on itself)
    for step_id in "${!deps[@]}"; do
        for dep in ${deps[$step_id]}; do
            if [[ "$dep" == "$step_id" ]]; then
                add_error "Step '$step_id' has circular dependency on itself"
            fi
        done
    done
}

# Check quality gates are defined
check_quality_gates() {
    local plan_file="$1"
    local has_gates
    has_gates=$(jq '.quality_gates // null' "$plan_file")
    
    if [[ "$has_gates" == "null" ]]; then
        add_warning "No quality gates defined - build will skip quality checks"
    fi
}

# Check complexity estimate matches step count
check_complexity() {
    local plan_file="$1"
    local step_count estimated_complexity
    step_count=$(jq '.steps | length' "$plan_file")
    estimated_complexity=$(jq -r '.estimated_complexity // empty' "$plan_file")
    
    if [[ -z "$estimated_complexity" ]]; then
        return  # No estimate to check
    fi
    
    case "$estimated_complexity" in
        trivial)
            if [[ "$step_count" -gt 3 ]]; then
                add_warning "Complexity 'trivial' but has $step_count steps (expected ≤3)"
            fi
            ;;
        simple)
            if [[ "$step_count" -gt 5 ]]; then
                add_warning "Complexity 'simple' but has $step_count steps (expected ≤5)"
            fi
            ;;
        moderate)
            if [[ "$step_count" -gt 10 ]]; then
                add_warning "Complexity 'moderate' but has $step_count steps (expected ≤10)"
            fi
            ;;
        complex)
            if [[ "$step_count" -gt 20 ]]; then
                add_warning "Complexity 'complex' but has $step_count steps (expected ≤20)"
            fi
            ;;
    esac
}

# ============================================================================
# MAIN VALIDATION LOGIC
# ============================================================================

validate_plan() {
    local plan_file="$1"
    
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        return 2
    fi
    
    # Check it's valid JSON
    if ! jq . "$plan_file" >/dev/null 2>&1; then
        log_error "Plan file is not valid JSON: $plan_file"
        return 1
    fi
    
    log_info "Validating plan: $plan_file"
    echo ""
    
    # Run all checks
    check_required_fields "$plan_file"
    check_steps "$plan_file"
    check_acceptance_criteria "$plan_file"
    check_dependencies "$plan_file"
    check_quality_gates "$plan_file"
    check_complexity "$plan_file"
    
    # Report results
    local exit_code=0
    
    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo -e "${BOLD}${RED}Errors (${#ERRORS[@]}):${NC}"
        for error in "${ERRORS[@]}"; do
            log_error "$error"
        done
        echo ""
        exit_code=1
    fi
    
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "${BOLD}${YELLOW}Warnings (${#WARNINGS[@]}):${NC}"
        for warning in "${WARNINGS[@]}"; do
            log_warn "$warning"
        done
        echo ""
    fi
    
    if [[ ${#ERRORS[@]} -eq 0 ]]; then
        local step_count ac_count
        step_count=$(jq '.steps | length' "$plan_file")
        ac_count=$(jq '.acceptance_criteria | length // 0' "$plan_file")
        
        echo -e "${BOLD}${GREEN}Plan is valid!${NC}"
        echo "  Steps: $step_count"
        echo "  Acceptance Criteria: $ac_count"
        echo "  Warnings: ${#WARNINGS[@]}"
        echo ""
        log_success "Ready to build: /build $(jq -r '.task_id' "$plan_file")"
    else
        echo -e "${BOLD}${RED}Plan has errors and cannot be executed.${NC}"
        echo "Fix the errors above and re-validate."
    fi
    
    return $exit_code
}

validate_all_plans() {
    local tasks_dir="$STUDIO_DIR/tasks"
    local total=0
    local valid=0
    local invalid=0
    
    if [[ ! -d "$tasks_dir" ]]; then
        log_info "No tasks directory found"
        return 0
    fi
    
    for task_dir in "$tasks_dir"/task_*; do
        if [[ -d "$task_dir" ]]; then
            local plan_file="$task_dir/plan.json"
            if [[ -f "$plan_file" ]]; then
                ((total++))
                
                # Reset errors/warnings for each plan
                ERRORS=()
                WARNINGS=()
                
                if validate_plan "$plan_file"; then
                    ((valid++))
                else
                    ((invalid++))
                fi
                echo ""
                echo "────────────────────────────────────────"
                echo ""
            fi
        fi
    done
    
    echo ""
    echo -e "${BOLD}Summary:${NC}"
    echo "  Total plans: $total"
    echo "  Valid: $valid"
    echo "  Invalid: $invalid"
    
    [[ "$invalid" -eq 0 ]]
}

# ============================================================================
# CLI
# ============================================================================

show_help() {
    cat << 'EOF'
STUDIO Plan Validation
======================

Validates plan integrity before build execution.

Usage:
  ./validate-plan.sh --task-id <task_id>    Validate specific task's plan
  ./validate-plan.sh --file <plan.json>     Validate specific plan file
  ./validate-plan.sh --all                  Validate all pending plans
  ./validate-plan.sh --help                 Show this help

Validation Checks:
  • Required fields (id, task_id, goal, steps)
  • Every step has success criteria
  • Every acceptance criterion has verification method
  • Dependencies reference valid steps
  • No circular dependencies
  • Quality gates defined
  • Complexity matches step count

Exit Codes:
  0 - Plan is valid
  1 - Plan has validation errors
  2 - Plan file not found

Examples:
  ./validate-plan.sh --task-id task_20260203_120000
  ./validate-plan.sh --file .studio/tasks/task_xxx/plan.json
  ./validate-plan.sh --all

EOF
}

main() {
    local task_id=""
    local plan_file=""
    local validate_all=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task-id)
                task_id="$2"
                shift 2
                ;;
            --file)
                plan_file="$2"
                shift 2
                ;;
            --all)
                validate_all=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ "$validate_all" == "true" ]]; then
        validate_all_plans
    elif [[ -n "$plan_file" ]]; then
        validate_plan "$plan_file"
    elif [[ -n "$task_id" ]]; then
        plan_file="$STUDIO_DIR/tasks/$task_id/plan.json"
        validate_plan "$plan_file"
    else
        log_error "No plan specified. Use --task-id, --file, or --all"
        show_help
        exit 1
    fi
}

main "$@"
