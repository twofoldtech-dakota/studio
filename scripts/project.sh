#!/usr/bin/env bash
# STUDIO Project Orchestration
# Manage multiple related tasks as a project with dependencies
# Integrates with backlog.sh for Epic > Feature > Task hierarchy
#
# Usage:
#   project.sh init <name>
#   project.sh task <goal>
#   project.sh status
#   project.sh run [task_id]
#   project.sh graph
#   project.sh backlog-init       # Initialize backlog integration
#   project.sh backlog-status     # Show backlog dashboard

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_DIR="${STUDIO_DIR:-studio}"
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"
PROJECTS_DIR="${STUDIO_OUTPUT_DIR}/projects"
BACKLOG_SCRIPT="${SCRIPT_DIR}/backlog.sh"

# Colors
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Get current project
get_current_project() {
    local current_file="${STUDIO_OUTPUT_DIR}/.current_project"
    if [[ -f "$current_file" ]]; then
        cat "$current_file"
    else
        echo ""
    fi
}

# Set current project
set_current_project() {
    local project_id="$1"
    mkdir -p "${STUDIO_OUTPUT_DIR}"
    echo "$project_id" > "${STUDIO_OUTPUT_DIR}/.current_project"
}

# Generate project ID
generate_project_id() {
    local name="$1"
    local date_part
    date_part=$(date +%Y%m%d)
    local safe_name
    safe_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')
    echo "proj_${date_part}_${safe_name:0:20}"
}

# Initialize a new project
init_project() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Usage: project.sh init <project-name>" >&2
        exit 1
    fi

    local project_id
    project_id=$(generate_project_id "$name")
    local project_dir="${PROJECTS_DIR}/${project_id}"

    if [[ -d "$project_dir" ]]; then
        echo "Project already exists: $project_id" >&2
        exit 1
    fi

    mkdir -p "${project_dir}/tasks"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "${project_dir}/project.json" << EOF
{
  "id": "${project_id}",
  "name": "${name}",
  "created_at": "${now}",
  "updated_at": "${now}",
  "status": "ACTIVE",
  "tasks": [],
  "shared_context": {
    "tech_stack": null,
    "patterns": {},
    "decisions": []
  },
  "execution_order": [],
  "backlog_enabled": true
}
EOF

    set_current_project "$project_id"

    # Also initialize the backlog
    init_backlog_integration "$name"

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${GREEN}PROJECT INITIALIZED${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ID:       ${CYAN}${project_id}${NC}"
    echo -e "${BOLD}║${NC}  Name:     ${name}"
    echo -e "${BOLD}║${NC}  Location: ${project_dir}"
    echo -e "${BOLD}║${NC}  Backlog:  ${STUDIO_OUTPUT_DIR}/backlog.json"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Next steps:"
    echo -e "${BOLD}║${NC}  1. Decompose: /plan \"goal\""
    echo -e "${BOLD}║${NC}  2. Build:     /build"
    echo -e "${BOLD}║${NC}  3. Status:    /status"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Initialize backlog integration
init_backlog_integration() {
    local name="${1:-$(basename "$(pwd)")}"

    if [[ -f "${BACKLOG_SCRIPT}" ]]; then
        "${BACKLOG_SCRIPT}" init "$name" 2>/dev/null || true
    fi
}

# Show backlog status
show_backlog_status() {
    local filter_id="${1:-}"

    if [[ -f "${BACKLOG_SCRIPT}" ]]; then
        "${BACKLOG_SCRIPT}" status "$filter_id"
    else
        echo "Backlog script not found at ${BACKLOG_SCRIPT}" >&2
        exit 1
    fi
}

# Get next task from backlog
get_next_backlog_task() {
    if [[ -f "${BACKLOG_SCRIPT}" ]]; then
        "${BACKLOG_SCRIPT}" next-task
    fi
}

# Resolve ID (short, full, or fuzzy)
resolve_backlog_id() {
    local id="$1"
    local type="${2:-any}"

    if [[ -f "${BACKLOG_SCRIPT}" ]]; then
        "${BACKLOG_SCRIPT}" resolve-id "$id" "$type"
    fi
}

# Check if backlog exists
backlog_exists() {
    [[ -f "${STUDIO_OUTPUT_DIR}/backlog.json" ]]
}

# Add a task to current project
add_task() {
    local goal="$1"
    local depends_on="${2:-}"

    local project_id
    project_id=$(get_current_project)

    if [[ -z "$project_id" ]]; then
        echo "No active project. Run: project.sh init <name>" >&2
        exit 1
    fi

    local project_file="${PROJECTS_DIR}/${project_id}/project.json"

    if [[ ! -f "$project_file" ]]; then
        echo "Project not found: $project_id" >&2
        exit 1
    fi

    # Generate task ID
    local task_count
    task_count=$(jq '.tasks | length' "$project_file")
    local task_num=$((task_count + 1))
    local task_id="task_$(date +%Y%m%d%H%M%S)"

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Parse depends_on
    local deps_array="[]"
    if [[ -n "$depends_on" ]]; then
        deps_array=$(echo "$depends_on" | tr ',' '\n' | jq -R . | jq -s .)
    fi

    # Add task to project
    local tmp
    tmp=$(mktemp)
    jq --arg id "$task_id" \
       --arg goal "$goal" \
       --argjson deps "$deps_array" \
       --arg now "$now" \
       '
       .tasks += [{
         "id": $id,
         "goal": $goal,
         "status": "PENDING",
         "depends_on": $deps,
         "created_at": $now
       }] |
       .updated_at = $now
       ' "$project_file" > "$tmp" && mv "$tmp" "$project_file"

    # Create task directory
    mkdir -p "${PROJECTS_DIR}/${project_id}/tasks/${task_id}"

    echo ""
    echo -e "${GREEN}Task added:${NC} ${task_id}"
    echo -e "  Goal: ${goal}"
    if [[ -n "$depends_on" ]]; then
        echo -e "  Depends on: ${depends_on}"
    fi
    echo ""
    echo "Run '/project:status' to see project tasks"
}

# Show project status
show_status() {
    local project_id
    project_id=$(get_current_project)

    if [[ -z "$project_id" ]]; then
        echo "No active project. Run: project.sh init <name>" >&2
        exit 1
    fi

    local project_file="${PROJECTS_DIR}/${project_id}/project.json"

    if [[ ! -f "$project_file" ]]; then
        echo "Project not found: $project_id" >&2
        exit 1
    fi

    local name
    name=$(jq -r '.name' "$project_file")
    local status
    status=$(jq -r '.status' "$project_file")
    local task_count
    task_count=$(jq '.tasks | length' "$project_file")

    # Count by status
    local pending complete building
    pending=$(jq '[.tasks[] | select(.status == "PENDING")] | length' "$project_file")
    complete=$(jq '[.tasks[] | select(.status == "COMPLETE")] | length' "$project_file")
    building=$(jq '[.tasks[] | select(.status == "BUILDING")] | length' "$project_file")

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}PROJECT STATUS${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Project: ${BOLD}${name}${NC}"
    echo -e "${BOLD}║${NC}  ID:      ${project_id}"
    echo -e "${BOLD}║${NC}  Status:  ${status}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Tasks: ${task_count} total"
    echo -e "${BOLD}║${NC}  ├─ ${GREEN}Complete${NC}:  ${complete}"
    echo -e "${BOLD}║${NC}  ├─ ${YELLOW}Building${NC}:  ${building}"
    echo -e "${BOLD}║${NC}  └─ ${DIM}Pending${NC}:   ${pending}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}  ${BOLD}TASKS${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"

    # List tasks
    jq -r '.tasks[] | "\(.id)|\(.status)|\(.goal)|\(.depends_on | join(","))"' "$project_file" | while IFS='|' read -r id task_status goal deps; do
        local status_icon status_color
        case "$task_status" in
            COMPLETE) status_icon="✓"; status_color="${GREEN}" ;;
            BUILDING) status_icon="⟳"; status_color="${YELLOW}" ;;
            PENDING)  status_icon="○"; status_color="${DIM}" ;;
            FAILED)   status_icon="✗"; status_color="${RED}" ;;
            *)        status_icon="?"; status_color="${NC}" ;;
        esac

        echo -e "${BOLD}║${NC}  ${status_color}${status_icon}${NC} ${id}"
        echo -e "${BOLD}║${NC}    ${goal:0:50}"
        if [[ -n "$deps" ]]; then
            echo -e "${BOLD}║${NC}    ${DIM}depends on: ${deps}${NC}"
        fi
    done

    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Show dependency graph
show_graph() {
    local project_id
    project_id=$(get_current_project)

    if [[ -z "$project_id" ]]; then
        echo "No active project. Run: project.sh init <name>" >&2
        exit 1
    fi

    local project_file="${PROJECTS_DIR}/${project_id}/project.json"

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}DEPENDENCY GRAPH${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"

    # Simple ASCII graph
    jq -r '
      .tasks | to_entries | .[] |
      if .value.depends_on | length == 0 then
        "║  [\(.value.id | .[0:15])] <- ROOT"
      else
        "║  [\(.value.id | .[0:15])] <- \(.value.depends_on | join(", "))"
      end
    ' "$project_file" | while read -r line; do
        echo -e "${BOLD}${line}${NC}"
    done

    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${DIM}Legend: ROOT = no dependencies, can run first${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Calculate execution order
calc_execution_order() {
    local project_id
    project_id=$(get_current_project)
    local project_file="${PROJECTS_DIR}/${project_id}/project.json"

    # Topological sort of tasks based on dependencies
    jq '
      def topo_sort:
        . as $tasks |
        reduce range(length) as $i (
          {order: [], remaining: $tasks};
          .remaining as $rem |
          ($rem | map(select(.depends_on | all(. as $d | $rem | map(.id) | index($d) == null)))) as $ready |
          if ($ready | length) == 0 and ($rem | length) > 0 then
            error("Circular dependency detected")
          else
            .order += ($ready | map(.id)) |
            .remaining = ($rem | map(select(.id as $id | $ready | map(.id) | index($id) == null)))
          end
        ) |
        .order;

      .tasks | topo_sort
    ' "$project_file"
}

# Run project tasks
run_project() {
    local start_task="${1:-}"

    local project_id
    project_id=$(get_current_project)

    if [[ -z "$project_id" ]]; then
        echo "No active project. Run: project.sh init <name>" >&2
        exit 1
    fi

    local project_file="${PROJECTS_DIR}/${project_id}/project.json"

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}PROJECT EXECUTION${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"

    # Get execution order
    local order
    order=$(calc_execution_order)

    echo -e "${BOLD}║${NC}  Execution order:"
    echo "$order" | jq -r '.[]' | nl -w2 -s'. ' | while read -r line; do
        echo -e "${BOLD}║${NC}    ${line}"
    done

    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Ready to execute. Run each task with /build"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# List all projects
list_projects() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}ALL PROJECTS${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"

    local current
    current=$(get_current_project)

    for proj_dir in "${PROJECTS_DIR}"/*/; do
        if [[ -d "$proj_dir" ]]; then
            local proj_file="${proj_dir}project.json"
            if [[ -f "$proj_file" ]]; then
                local id name task_count status
                id=$(jq -r '.id' "$proj_file")
                name=$(jq -r '.name' "$proj_file")
                task_count=$(jq '.tasks | length' "$proj_file")
                status=$(jq -r '.status' "$proj_file")

                local marker=""
                [[ "$id" == "$current" ]] && marker="${GREEN}*${NC} "

                echo -e "${BOLD}║${NC}  ${marker}${BOLD}${name}${NC}"
                echo -e "${BOLD}║${NC}    ID: ${id}"
                echo -e "${BOLD}║${NC}    Tasks: ${task_count} | Status: ${status}"
                echo -e "${BOLD}║${NC}"
            fi
        fi
    done

    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Switch to a project
switch_project() {
    local project_id="$1"
    local project_dir="${PROJECTS_DIR}/${project_id}"

    if [[ ! -d "$project_dir" ]]; then
        echo "Project not found: $project_id" >&2
        exit 1
    fi

    set_current_project "$project_id"
    echo "Switched to project: $project_id"
}

# Main
case "${1:-status}" in
    init)
        shift
        init_project "$@"
        ;;
    task|add)
        shift
        add_task "$@"
        ;;
    status)
        show_status
        ;;
    graph)
        show_graph
        ;;
    run)
        shift
        run_project "$@"
        ;;
    list)
        list_projects
        ;;
    switch)
        shift
        switch_project "$@"
        ;;
    order)
        calc_execution_order
        ;;
    # Backlog integration commands
    backlog-init)
        shift
        init_backlog_integration "${1:-}"
        ;;
    backlog-status)
        shift
        show_backlog_status "${1:-}"
        ;;
    backlog-next)
        get_next_backlog_task
        ;;
    backlog-resolve)
        shift
        resolve_backlog_id "$@"
        ;;
    backlog-exists)
        backlog_exists && echo "true" || echo "false"
        ;;
    help|--help|-h)
        cat << 'EOF'
STUDIO Project Orchestration

Usage:
  project.sh init <name>           Initialize a new project (+ backlog)
  project.sh task <goal> [deps]    Add a task (deps: comma-separated task IDs)
  project.sh status                Show project status
  project.sh graph                 Show dependency graph
  project.sh run [task_id]         Run project tasks
  project.sh list                  List all projects
  project.sh switch <project_id>   Switch active project

Backlog Integration:
  project.sh backlog-init [name]   Initialize backlog separately
  project.sh backlog-status [id]   Show backlog dashboard
  project.sh backlog-next          Get next ready task
  project.sh backlog-resolve <id>  Resolve short/fuzzy ID
  project.sh backlog-exists        Check if backlog exists

ID Formats (for backlog):
  Short: E1, F1, T1
  Full: EPIC-001, FEAT-001, task_20260201_120000
  Fuzzy: "login" matches "User Login"

Examples:
  project.sh init "E-commerce Platform"
  project.sh backlog-status
  project.sh backlog-next
  project.sh backlog-resolve T7
EOF
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Use 'project.sh help' for usage" >&2
        exit 1
        ;;
esac
