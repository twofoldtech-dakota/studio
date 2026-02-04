#!/usr/bin/env bash
# STUDIO Dependency Graph & Critical Path Analysis
# Visualize task dependencies, calculate critical path, identify parallel opportunities
#
# Usage:
#   dependency-graph.sh visualize              # ASCII visualization of task graph
#   dependency-graph.sh critical-path          # Show longest dependency chain
#   dependency-graph.sh parallel-batches       # Group tasks that can run in parallel
#   dependency-graph.sh impact <task-id>       # Show what depends on this task
#   dependency-graph.sh blockers <task-id>     # Show what blocks this task
#   dependency-graph.sh validate               # Check for cycles and issues

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-.studio}"
BACKLOG_FILE="${STUDIO_DIR}/backlog.json"
GRAPH_CACHE="${STUDIO_DIR}/.cache/dependency-graph.json"

# Colors
if [[ -z "${NO_COLOR:-}" ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    PURPLE='\033[0;35m'
    NC='\033[0m'
else
    BOLD='' DIM='' RED='' GREEN='' YELLOW='' CYAN='' PURPLE='' NC=''
fi

# Build dependency graph from backlog
build_graph() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi
    
    mkdir -p "$(dirname "$GRAPH_CACHE")"
    
    # Extract all tasks and their dependencies
    jq '
    {
        nodes: [.epics[].features[].tasks[] | {
            id: .id,
            short_id: .short_id,
            name: .name,
            status: .status,
            depends_on: (.depends_on // []),
            blocks: (.blocks // []),
            effort: .effort
        }],
        edges: [.epics[].features[].tasks[] | 
            . as $task | 
            (.depends_on // [])[] | 
            {from: ., to: $task.id, type: "depends_on"}
        ]
    }' "$BACKLOG_FILE" > "$GRAPH_CACHE"
    
    echo "$GRAPH_CACHE"
}

# Visualize the dependency graph as ASCII
cmd_visualize() {
    build_graph > /dev/null
    
    echo -e "${BOLD}Dependency Graph${NC}"
    echo ""
    
    local tasks
    tasks=$(jq -r '.nodes[] | "\(.short_id):\(.name):\(.status):\(.depends_on | join(","))"' "$GRAPH_CACHE")
    
    if [[ -z "$tasks" ]]; then
        echo -e "  ${DIM}No tasks in backlog${NC}"
        return
    fi
    
    # Group by dependency level
    declare -A levels
    declare -A task_names
    declare -A task_status
    declare -A task_deps
    
    while IFS=: read -r id name status deps; do
        task_names["$id"]="$name"
        task_status["$id"]="$status"
        task_deps["$id"]="$deps"
        
        if [[ -z "$deps" ]]; then
            levels["0"]+="$id "
        fi
    done <<< "$tasks"
    
    # Calculate levels for tasks with dependencies
    local max_level=0
    local changed=true
    while [[ "$changed" == "true" ]]; do
        changed=false
        while IFS=: read -r id name status deps; do
            if [[ -n "$deps" ]] && [[ -z "${levels[$id]:-}" ]]; then
                local max_dep_level=-1
                local all_deps_resolved=true
                
                IFS=',' read -ra dep_array <<< "$deps"
                for dep in "${dep_array[@]}"; do
                    [[ -z "$dep" ]] && continue
                    local dep_level=-1
                    for lvl in "${!levels[@]}"; do
                        if [[ " ${levels[$lvl]} " == *" $dep "* ]]; then
                            dep_level=$lvl
                            break
                        fi
                    done
                    if [[ $dep_level -eq -1 ]]; then
                        all_deps_resolved=false
                        break
                    fi
                    ((dep_level > max_dep_level)) && max_dep_level=$dep_level
                done
                
                if [[ "$all_deps_resolved" == "true" ]]; then
                    local new_level=$((max_dep_level + 1))
                    levels["$new_level"]+="$id "
                    ((new_level > max_level)) && max_level=$new_level
                    changed=true
                fi
            fi
        done <<< "$tasks"
    done
    
    # Display by level
    for ((lvl=0; lvl<=max_level; lvl++)); do
        echo -e "${CYAN}Level $lvl:${NC}"
        for id in ${levels[$lvl]:-}; do
            local status_icon="○"
            case "${task_status[$id]:-}" in
                COMPLETE*) status_icon="${GREEN}✓${NC}" ;;
                IN_PROGRESS) status_icon="${YELLOW}◐${NC}" ;;
                BLOCKED) status_icon="${RED}✗${NC}" ;;
            esac
            local deps_str=""
            [[ -n "${task_deps[$id]:-}" ]] && deps_str=" ${DIM}← ${task_deps[$id]}${NC}"
            echo -e "  $status_icon ${BOLD}$id${NC}: ${task_names[$id]:-}${deps_str}"
        done
        echo ""
    done
}

# Find the critical path (longest dependency chain)
cmd_critical_path() {
    build_graph > /dev/null
    
    echo -e "${BOLD}Critical Path Analysis${NC}"
    echo ""
    
    # Find all paths and their lengths
    local nodes
    nodes=$(jq -r '.nodes[].short_id' "$GRAPH_CACHE")
    
    # Find root nodes (no dependencies)
    local roots
    roots=$(jq -r '.nodes[] | select(.depends_on | length == 0) | .short_id' "$GRAPH_CACHE")
    
    # Find leaf nodes (nothing depends on them)
    local all_deps
    all_deps=$(jq -r '[.nodes[].depends_on[]] | unique | .[]' "$GRAPH_CACHE")
    
    local longest_path=""
    local longest_length=0
    
    # DFS to find longest path
    find_longest_path() {
        local current="$1"
        local path="$2"
        local length="$3"
        
        local dependents
        dependents=$(jq -r --arg id "$current" '.nodes[] | select(.depends_on[] == $id) | .short_id' "$GRAPH_CACHE" 2>/dev/null || echo "")
        
        if [[ -z "$dependents" ]]; then
            # Leaf node
            if ((length > longest_length)); then
                longest_length=$length
                longest_path="$path"
            fi
        else
            for dep in $dependents; do
                find_longest_path "$dep" "$path → $dep" $((length + 1))
            done
        fi
    }
    
    for root in $roots; do
        find_longest_path "$root" "$root" 1
    done
    
    if [[ -n "$longest_path" ]]; then
        echo -e "  ${YELLOW}Critical Path:${NC} $longest_path"
        echo -e "  ${YELLOW}Length:${NC} $longest_length tasks"
        echo ""
        echo -e "  ${DIM}This is the longest chain - delays here delay the project${NC}"
    else
        echo -e "  ${GREEN}No dependencies - all tasks can run in parallel${NC}"
    fi
}

# Group tasks into parallel batches
cmd_parallel_batches() {
    build_graph > /dev/null
    
    echo -e "${BOLD}Parallel Execution Batches${NC}"
    echo ""
    
    local batch=1
    local completed=""
    local remaining
    remaining=$(jq -r '.nodes[].short_id' "$GRAPH_CACHE")
    
    while [[ -n "$remaining" ]]; do
        echo -e "${CYAN}Batch $batch:${NC}"
        local batch_tasks=""
        
        for task in $remaining; do
            local deps
            deps=$(jq -r --arg id "$task" '.nodes[] | select(.short_id == $id) | .depends_on[]' "$GRAPH_CACHE" 2>/dev/null || echo "")
            
            local all_deps_done=true
            for dep in $deps; do
                if [[ " $completed " != *" $dep "* ]]; then
                    all_deps_done=false
                    break
                fi
            done
            
            if [[ "$all_deps_done" == "true" ]]; then
                local name
                name=$(jq -r --arg id "$task" '.nodes[] | select(.short_id == $id) | .name' "$GRAPH_CACHE")
                echo -e "  • ${BOLD}$task${NC}: $name"
                batch_tasks+="$task "
            fi
        done
        
        if [[ -z "$batch_tasks" ]]; then
            echo -e "  ${RED}Cycle detected - cannot resolve remaining tasks${NC}"
            break
        fi
        
        completed+="$batch_tasks"
        remaining=$(echo "$remaining" | tr ' ' '\n' | grep -v -F "$(echo "$batch_tasks" | tr ' ' '\n')" | tr '\n' ' ')
        
        echo ""
        ((batch++))
    done
    
    echo -e "${DIM}Tasks in the same batch can be executed in parallel${NC}"
}

# Show what depends on a task (impact analysis)
cmd_impact() {
    local task_id="${1:-}"
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: dependency-graph.sh impact <task-id>" >&2
        return 1
    fi
    
    build_graph > /dev/null
    
    echo -e "${BOLD}Impact Analysis: $task_id${NC}"
    echo ""
    
    # Find all tasks that depend on this one (direct and transitive)
    local direct
    direct=$(jq -r --arg id "$task_id" '.nodes[] | select(.depends_on[] | contains($id)) | .short_id' "$GRAPH_CACHE" 2>/dev/null || echo "")
    
    if [[ -z "$direct" ]]; then
        echo -e "  ${GREEN}No tasks depend on $task_id${NC}"
        echo -e "  ${DIM}Changes to this task won't block other work${NC}"
        return
    fi
    
    echo -e "  ${YELLOW}Direct dependents:${NC}"
    for dep in $direct; do
        local name
        name=$(jq -r --arg id "$dep" '.nodes[] | select(.short_id == $id) | .name' "$GRAPH_CACHE")
        echo -e "    → ${BOLD}$dep${NC}: $name"
    done
    
    # Find transitive dependents
    local all_dependents="$direct"
    local to_check="$direct"
    
    while [[ -n "$to_check" ]]; do
        local new_deps=""
        for task in $to_check; do
            local deps
            deps=$(jq -r --arg id "$task" '.nodes[] | select(.depends_on[] | contains($id)) | .short_id' "$GRAPH_CACHE" 2>/dev/null || echo "")
            for d in $deps; do
                if [[ " $all_dependents " != *" $d "* ]]; then
                    new_deps+="$d "
                    all_dependents+="$d "
                fi
            done
        done
        to_check="$new_deps"
    done
    
    local transitive
    transitive=$(echo "$all_dependents" | tr ' ' '\n' | grep -v -F "$(echo "$direct" | tr ' ' '\n')" | tr '\n' ' ')
    
    if [[ -n "$transitive" ]]; then
        echo ""
        echo -e "  ${YELLOW}Transitive dependents:${NC}"
        for dep in $transitive; do
            local name
            name=$(jq -r --arg id "$dep" '.nodes[] | select(.short_id == $id) | .name' "$GRAPH_CACHE")
            echo -e "    ⇢ ${DIM}$dep${NC}: $name"
        done
    fi
    
    echo ""
    local count
    count=$(echo "$all_dependents" | wc -w | tr -d ' ')
    echo -e "  ${RED}⚠ Changes to $task_id affect $count downstream tasks${NC}"
}

# Show what blocks a task
cmd_blockers() {
    local task_id="${1:-}"
    
    if [[ -z "$task_id" ]]; then
        echo "Usage: dependency-graph.sh blockers <task-id>" >&2
        return 1
    fi
    
    build_graph > /dev/null
    
    echo -e "${BOLD}Blockers for: $task_id${NC}"
    echo ""
    
    local deps
    deps=$(jq -r --arg id "$task_id" '.nodes[] | select(.short_id == $id) | .depends_on[]' "$GRAPH_CACHE" 2>/dev/null || echo "")
    
    if [[ -z "$deps" ]]; then
        echo -e "  ${GREEN}No blockers - $task_id can start immediately${NC}"
        return
    fi
    
    local blocked_count=0
    for dep in $deps; do
        local status
        status=$(jq -r --arg id "$dep" '.nodes[] | select(.short_id == $id) | .status' "$GRAPH_CACHE")
        local name
        name=$(jq -r --arg id "$dep" '.nodes[] | select(.short_id == $id) | .name' "$GRAPH_CACHE")
        
        local status_icon="○"
        case "$status" in
            COMPLETE*) status_icon="${GREEN}✓${NC}" ;;
            IN_PROGRESS) status_icon="${YELLOW}◐${NC}"; ((blocked_count++)) ;;
            *) status_icon="${RED}✗${NC}"; ((blocked_count++)) ;;
        esac
        
        echo -e "  $status_icon ${BOLD}$dep${NC}: $name ${DIM}($status)${NC}"
    done
    
    echo ""
    if ((blocked_count > 0)); then
        echo -e "  ${YELLOW}$blocked_count blocking tasks must complete first${NC}"
    else
        echo -e "  ${GREEN}All dependencies complete - ready to start${NC}"
    fi
}

# Validate graph for cycles and issues
cmd_validate() {
    build_graph > /dev/null
    
    echo -e "${BOLD}Dependency Graph Validation${NC}"
    echo ""
    
    local issues=0
    
    # Check for cycles using DFS
    echo -e "${CYAN}Checking for cycles...${NC}"
    local nodes
    nodes=$(jq -r '.nodes[].short_id' "$GRAPH_CACHE")
    
    detect_cycle() {
        local node="$1"
        local path="$2"
        
        if [[ " $path " == *" $node "* ]]; then
            echo -e "  ${RED}✗ Cycle detected: $path → $node${NC}"
            return 1
        fi
        
        local deps
        deps=$(jq -r --arg id "$node" '.nodes[] | select(.short_id == $id) | .depends_on[]' "$GRAPH_CACHE" 2>/dev/null || echo "")
        
        for dep in $deps; do
            detect_cycle "$dep" "$path $node" || return 1
        done
        return 0
    }
    
    local has_cycle=false
    for node in $nodes; do
        if ! detect_cycle "$node" ""; then
            has_cycle=true
            ((issues++))
        fi
    done
    
    [[ "$has_cycle" == "false" ]] && echo -e "  ${GREEN}✓ No cycles detected${NC}"
    
    # Check for missing dependencies
    echo ""
    echo -e "${CYAN}Checking for missing references...${NC}"
    local all_ids
    all_ids=$(jq -r '.nodes[].short_id' "$GRAPH_CACHE")
    
    for node in $nodes; do
        local deps
        deps=$(jq -r --arg id "$node" '.nodes[] | select(.short_id == $id) | .depends_on[]' "$GRAPH_CACHE" 2>/dev/null || echo "")
        
        for dep in $deps; do
            if [[ " $all_ids " != *" $dep "* ]]; then
                echo -e "  ${RED}✗ $node depends on unknown task: $dep${NC}"
                ((issues++))
            fi
        done
    done
    
    ((issues == 0)) && echo -e "  ${GREEN}✓ All references valid${NC}"
    
    # Check for orphaned tasks
    echo ""
    echo -e "${CYAN}Checking for isolated tasks...${NC}"
    local isolated=0
    for node in $nodes; do
        local deps
        deps=$(jq -r --arg id "$node" '.nodes[] | select(.short_id == $id) | .depends_on | length' "$GRAPH_CACHE")
        local dependents
        dependents=$(jq -r --arg id "$node" '[.nodes[] | select(.depends_on[] == $id)] | length' "$GRAPH_CACHE" 2>/dev/null || echo "0")
        
        if [[ "$deps" == "0" ]] && [[ "$dependents" == "0" ]]; then
            echo -e "  ${YELLOW}○ $node is isolated (no dependencies, nothing depends on it)${NC}"
            ((isolated++))
        fi
    done
    
    ((isolated == 0)) && echo -e "  ${GREEN}✓ All tasks connected${NC}"
    
    echo ""
    if ((issues > 0)); then
        echo -e "${RED}Found $issues issues${NC}"
        return 1
    else
        echo -e "${GREEN}Graph is valid${NC}"
    fi
}

# Main dispatch
main() {
    local cmd="${1:-visualize}"
    shift || true
    
    case "$cmd" in
        visualize|viz|v)
            cmd_visualize
            ;;
        critical-path|critical|cp)
            cmd_critical_path
            ;;
        parallel-batches|parallel|pb)
            cmd_parallel_batches
            ;;
        impact|i)
            cmd_impact "$@"
            ;;
        blockers|b)
            cmd_blockers "$@"
            ;;
        validate|check)
            cmd_validate
            ;;
        -h|--help|help)
            echo "Usage: dependency-graph.sh <command> [args]"
            echo ""
            echo "Commands:"
            echo "  visualize          ASCII visualization of task dependencies"
            echo "  critical-path      Show longest dependency chain"
            echo "  parallel-batches   Group tasks that can run in parallel"
            echo "  impact <task-id>   Show what depends on this task"
            echo "  blockers <task-id> Show what blocks this task"
            echo "  validate           Check for cycles and issues"
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            return 1
            ;;
    esac
}

main "$@"
