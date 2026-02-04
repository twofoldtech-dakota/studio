#!/usr/bin/env bash
# STUDIO Change Impact Analysis
# Detect conflicts and hidden dependencies when plans change
#
# Usage:
#   impact-analysis.sh file <filepath>      # Analyze impact of changing a file
#   impact-analysis.sh task <task-id>       # Analyze impact of task changes
#   impact-analysis.sh conflicts            # Detect conflicts between active tasks
#   impact-analysis.sh dependencies <path>  # Find hidden dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
BACKLOG_FILE="${STUDIO_DIR}/backlog.json"

# Colors
if [[ -z "${NO_COLOR:-}" ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Analyze impact of changing a file
cmd_file() {
    local filepath="${1:-}"
    
    if [[ -z "$filepath" ]]; then
        echo "Usage: impact-analysis.sh file <filepath>" >&2
        return 1
    fi
    
    echo -e "${BOLD}Impact Analysis: $filepath${NC}"
    echo ""
    
    # Find what imports/requires this file
    local basename
    basename=$(basename "$filepath" | sed 's/\.[^.]*$//')
    local dirname
    dirname=$(dirname "$filepath")
    
    echo -e "${CYAN}Direct Dependencies (files that import this)${NC}"
    local importers
    importers=$(grep -rl "from.*['\"].*${basename}['\"]" . --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v node_modules | grep -v ".studio" || echo "")
    
    if [[ -n "$importers" ]]; then
        echo "$importers" | while read -r file; do
            echo -e "  ${YELLOW}→${NC} $file"
        done
    else
        echo -e "  ${DIM}No direct importers found${NC}"
    fi
    
    echo ""
    
    # Find what this file imports
    echo -e "${CYAN}This File Depends On${NC}"
    if [[ -f "$filepath" ]]; then
        local imports
        imports=$(grep -E "^import|^from|require\(" "$filepath" 2>/dev/null | head -10 || echo "")
        if [[ -n "$imports" ]]; then
            echo "$imports" | while read -r line; do
                echo -e "  ${DIM}$line${NC}"
            done
        else
            echo -e "  ${DIM}No imports found${NC}"
        fi
    fi
    
    echo ""
    
    # Check if any tasks reference this file
    if [[ -f "$BACKLOG_FILE" ]]; then
        echo -e "${CYAN}Tasks Affecting This File${NC}"
        local related_tasks
        related_tasks=$(jq -r --arg path "$filepath" --arg base "$basename" '
            .epics[].features[].tasks[] |
            select(.name | ascii_downcase | contains($base | ascii_downcase)) |
            "\(.short_id): \(.name)"
        ' "$BACKLOG_FILE" 2>/dev/null || echo "")
        
        if [[ -n "$related_tasks" ]]; then
            echo "$related_tasks" | while read -r task; do
                echo -e "  ${YELLOW}⚠${NC} $task"
            done
        else
            echo -e "  ${DIM}No tasks directly reference this file${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}Risk Assessment${NC}"
    
    local risk="LOW"
    local importer_count
    importer_count=$(echo "$importers" | grep -c . || echo "0")
    
    if ((importer_count > 10)); then
        risk="HIGH"
        echo -e "  ${RED}HIGH RISK${NC} - $importer_count files depend on this"
    elif ((importer_count > 5)); then
        risk="MEDIUM"
        echo -e "  ${YELLOW}MEDIUM RISK${NC} - $importer_count files depend on this"
    else
        echo -e "  ${GREEN}LOW RISK${NC} - Few dependencies"
    fi
    
    # Check for specific patterns
    if [[ "$filepath" == *"types"* ]] || [[ "$filepath" == *"interface"* ]]; then
        echo -e "  ${YELLOW}⚠${NC} Type/interface file - changes may require updates in many places"
    fi
    if [[ "$filepath" == *"config"* ]] || [[ "$filepath" == *"constant"* ]]; then
        echo -e "  ${YELLOW}⚠${NC} Configuration file - changes affect system-wide behavior"
    fi
    if [[ "$filepath" == *"util"* ]] || [[ "$filepath" == *"helper"* ]]; then
        echo -e "  ${YELLOW}⚠${NC} Utility file - widely used across codebase"
    fi
}

# Analyze impact of task changes
cmd_task() {
    local task_id="${1:-}"
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: impact-analysis.sh task <task-id>" >&2
        return 1
    fi
    
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    local task
    task=$(jq -r --arg id "$task_id" '
        .epics[].features[].tasks[] |
        select(.id == $id or .short_id == $id) |
        "\(.name)|\(.description // "")"
    ' "$BACKLOG_FILE" | head -1)
    
    if [[ -z "$task" ]]; then
        echo "Task not found: $task_id" >&2
        return 1
    fi
    
    IFS='|' read -r name description <<< "$task"
    
    echo -e "${BOLD}Task Impact Analysis: $task_id${NC}"
    echo -e "Task: $name"
    echo ""
    
    # Find dependent tasks
    echo -e "${CYAN}Tasks That Depend On This${NC}"
    local dependents
    dependents=$(jq -r --arg id "$task_id" '
        .epics[].features[].tasks[] |
        select(.depends_on[]? == $id) |
        "\(.short_id): \(.name)"
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$dependents" ]]; then
        echo "$dependents" | while read -r dep; do
            echo -e "  ${YELLOW}→${NC} $dep"
        done
    else
        echo -e "  ${DIM}No dependent tasks${NC}"
    fi
    
    echo ""
    
    # Find tasks this depends on
    echo -e "${CYAN}This Task Depends On${NC}"
    local dependencies
    dependencies=$(jq -r --arg id "$task_id" '
        .epics[].features[].tasks[] |
        select(.id == $id or .short_id == $id) |
        .depends_on[]?
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$dependencies" ]]; then
        for dep_id in $dependencies; do
            local dep_name
            dep_name=$(jq -r --arg id "$dep_id" '
                .epics[].features[].tasks[] |
                select(.short_id == $id) |
                .name
            ' "$BACKLOG_FILE" 2>/dev/null || echo "Unknown")
            echo -e "  ${DIM}←${NC} $dep_id: $dep_name"
        done
    else
        echo -e "  ${DIM}No dependencies${NC}"
    fi
    
    echo ""
    
    # Check for potential conflicts with in-progress tasks
    echo -e "${CYAN}Potential Conflicts${NC}"
    local in_progress
    in_progress=$(jq -r '
        .epics[].features[].tasks[] |
        select(.status == "IN_PROGRESS") |
        "\(.short_id)|\(.name)"
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -n "$in_progress" ]]; then
        # Simple keyword overlap detection
        local task_keywords
        task_keywords=$(echo "$name $description" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u)
        
        while IFS='|' read -r other_id other_name; do
            [[ -z "$other_id" ]] && continue
            [[ "$other_id" == "$task_id" ]] && continue
            
            local other_keywords
            other_keywords=$(echo "$other_name" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u)
            
            local overlap
            overlap=$(comm -12 <(echo "$task_keywords") <(echo "$other_keywords") | wc -l | tr -d ' ')
            
            if ((overlap > 2)); then
                echo -e "  ${YELLOW}⚠${NC} $other_id: $other_name ${DIM}(keyword overlap)${NC}"
            fi
        done <<< "$in_progress"
    else
        echo -e "  ${GREEN}No in-progress tasks to conflict with${NC}"
    fi
}

# Detect conflicts between active tasks
cmd_conflicts() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    echo -e "${BOLD}Conflict Detection${NC}"
    echo ""
    
    # Get all in-progress tasks
    local tasks
    tasks=$(jq -r '
        .epics[].features[].tasks[] |
        select(.status == "IN_PROGRESS") |
        "\(.short_id)|\(.name)"
    ' "$BACKLOG_FILE" 2>/dev/null || echo "")
    
    if [[ -z "$tasks" ]]; then
        echo -e "  ${GREEN}No tasks in progress - no conflicts possible${NC}"
        return
    fi
    
    local conflict_count=0
    
    # Check each pair of tasks
    local task_array=()
    while IFS='|' read -r id name; do
        [[ -n "$id" ]] && task_array+=("$id|$name")
    done <<< "$tasks"
    
    for ((i=0; i<${#task_array[@]}; i++)); do
        for ((j=i+1; j<${#task_array[@]}; j++)); do
            IFS='|' read -r id1 name1 <<< "${task_array[$i]}"
            IFS='|' read -r id2 name2 <<< "${task_array[$j]}"
            
            # Check for file path conflicts (if tasks specify affected files)
            # Check for keyword overlap
            local keywords1
            keywords1=$(echo "$name1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u)
            local keywords2
            keywords2=$(echo "$name2" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' | sort -u)
            
            local overlap
            overlap=$(comm -12 <(echo "$keywords1") <(echo "$keywords2") | grep -v '^$' | wc -l | tr -d ' ')
            
            if ((overlap > 3)); then
                echo -e "${YELLOW}⚠ Potential Conflict:${NC}"
                echo -e "  Task 1: ${BOLD}$id1${NC} - $name1"
                echo -e "  Task 2: ${BOLD}$id2${NC} - $name2"
                echo -e "  ${DIM}Reason: Significant keyword overlap${NC}"
                echo ""
                ((conflict_count++))
            fi
        done
    done
    
    if ((conflict_count == 0)); then
        echo -e "${GREEN}✓ No conflicts detected between active tasks${NC}"
    else
        echo -e "${YELLOW}Found $conflict_count potential conflicts${NC}"
        echo -e "${DIM}Consider sequencing these tasks or coordinating changes${NC}"
    fi
}

# Find hidden dependencies in code
cmd_dependencies() {
    local path="${1:-.}"
    
    echo -e "${BOLD}Hidden Dependency Analysis: $path${NC}"
    echo ""
    
    # Find circular imports
    echo -e "${CYAN}Checking for Circular Dependencies${NC}"
    
    # Simple check: find files that import each other
    local ts_files
    ts_files=$(find "$path" -name "*.ts" -o -name "*.tsx" 2>/dev/null | grep -v node_modules | grep -v ".studio" | head -100)
    
    local circular_count=0
    
    for file_a in $ts_files; do
        local base_a
        base_a=$(basename "$file_a" | sed 's/\.[^.]*$//')
        
        # Find what this file imports
        local imports_a
        imports_a=$(grep -oE "from ['\"]\..*['\"]" "$file_a" 2>/dev/null | sed "s/from ['\"]//;s/['\"]$//" || echo "")
        
        for import in $imports_a; do
            local imported_base
            imported_base=$(basename "$import" | sed 's/\.[^.]*$//')
            
            # Check if the imported file imports back
            local imported_file
            imported_file=$(find "$path" -name "${imported_base}.ts" -o -name "${imported_base}.tsx" 2>/dev/null | grep -v node_modules | head -1)
            
            if [[ -n "$imported_file" ]] && [[ -f "$imported_file" ]]; then
                if grep -q "$base_a" "$imported_file" 2>/dev/null; then
                    echo -e "  ${RED}⚠${NC} Circular: $file_a ↔ $imported_file"
                    ((circular_count++))
                fi
            fi
        done
    done
    
    if ((circular_count == 0)); then
        echo -e "  ${GREEN}✓ No circular dependencies detected${NC}"
    fi
    
    echo ""
    
    # Find deeply nested dependencies
    echo -e "${CYAN}Deep Dependency Chains${NC}"
    
    # Count import depth for each file
    local max_depth=0
    local deepest_file=""
    
    for file in $ts_files; do
        local import_count
        import_count=$(grep -c "^import" "$file" 2>/dev/null || echo "0")
        
        if ((import_count > max_depth)); then
            max_depth=$import_count
            deepest_file="$file"
        fi
        
        if ((import_count > 20)); then
            echo -e "  ${YELLOW}⚠${NC} $file has $import_count imports"
        fi
    done
    
    if [[ -n "$deepest_file" ]]; then
        echo -e "  ${DIM}Most imports: $deepest_file ($max_depth)${NC}"
    fi
    
    echo ""
    
    # Find shared state/singletons
    echo -e "${CYAN}Shared State (Potential Hidden Deps)${NC}"
    local shared_state
    shared_state=$(grep -rl "export const\|export let\|createContext\|useState\|useReducer" "$path" --include="*.ts" --include="*.tsx" 2>/dev/null | grep -v node_modules | grep -v ".studio" | head -10 || echo "")
    
    if [[ -n "$shared_state" ]]; then
        echo "$shared_state" | while read -r file; do
            echo -e "  ${DIM}•${NC} $file"
        done
    else
        echo -e "  ${DIM}No shared state patterns found${NC}"
    fi
}

# Main dispatch
main() {
    local cmd="${1:-conflicts}"
    shift || true
    
    case "$cmd" in
        file|f)
            cmd_file "$@"
            ;;
        task|t)
            cmd_task "$@"
            ;;
        conflicts|c)
            cmd_conflicts
            ;;
        dependencies|deps|d)
            cmd_dependencies "$@"
            ;;
        -h|--help|help)
            echo "Usage: impact-analysis.sh <command> [args]"
            echo ""
            echo "Commands:"
            echo "  file <filepath>      Analyze impact of changing a file"
            echo "  task <task-id>       Analyze impact of task changes"
            echo "  conflicts            Detect conflicts between active tasks"
            echo "  dependencies [path]  Find hidden dependencies in code"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            return 1
            ;;
    esac
}

main "$@"
