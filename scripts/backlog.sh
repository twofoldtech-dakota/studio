#!/usr/bin/env bash
# STUDIO Backlog Management
# Enterprise project decomposition with Epic > Feature > Task hierarchy
# CRITICAL: All operations are APPEND-ONLY for immutability
#
# Usage:
#   backlog.sh init [project-name]
#   backlog.sh add-epic <name> [description]
#   backlog.sh add-feature <epic-id> <name> [description]
#   backlog.sh add-task <feature-id> <name> [description]
#   backlog.sh update-status <id> <status> [reason]
#   backlog.sh get <id>
#   backlog.sh resolve-id <short-or-full-id>
#   backlog.sh ready-tasks
#   backlog.sh next-task
#   backlog.sh score-task <task-id>
#   backlog.sh status [epic-id|feature-id]
#   backlog.sh search <query>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"
BACKLOG_FILE="${STUDIO_OUTPUT_DIR}/backlog.json"
ID_MAP_FILE="${STUDIO_OUTPUT_DIR}/id-map.json"

# Colors (respect NO_COLOR)
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

# Generate hex ID
generate_hex() {
    local length="${1:-8}"
    head -c 32 /dev/urandom | shasum | head -c "$length"
}

# Get current timestamp
now_iso() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get task ID timestamp
task_timestamp() {
    date +"%Y%m%d_%H%M%S"
}

# Initialize backlog
init_backlog() {
    local project_name="${1:-$(basename "$(pwd)")}"

    mkdir -p "$STUDIO_OUTPUT_DIR"

    if [[ -f "$BACKLOG_FILE" ]]; then
        echo "Backlog already exists at $BACKLOG_FILE" >&2
        echo "Use 'backlog.sh status' to view current state" >&2
        return 1
    fi

    local project_id="proj_$(generate_hex 8)"
    local now
    now=$(now_iso)

    cat > "$BACKLOG_FILE" << EOF
{
  "project_id": "${project_id}",
  "project_name": "${project_name}",
  "created_at": "${now}",
  "updated_at": "${now}",
  "description": "",
  "epics": [],
  "id_counter": {
    "epic": 0,
    "feature": 0,
    "task": 0
  },
  "metrics": {
    "total_epics": 0,
    "total_features": 0,
    "total_tasks": 0,
    "completed_tasks": 0,
    "completion_percentage": 0
  }
}
EOF

    # Initialize ID map
    cat > "$ID_MAP_FILE" << 'EOF'
{
  "epics": {},
  "features": {},
  "tasks": {}
}
EOF

    echo -e "${GREEN}Backlog initialized${NC}"
    echo -e "  Project: ${BOLD}${project_name}${NC}"
    echo -e "  ID: ${CYAN}${project_id}${NC}"
    echo -e "  Location: ${BACKLOG_FILE}"
}

# Add changelog entry (internal helper)
add_changelog_entry() {
    local action="$1"
    local actor="${2:-architect}"
    local prev_value="${3:-null}"
    local new_value="${4:-null}"
    local reason="${5:-}"

    local now
    now=$(now_iso)

    jq -n \
        --arg ts "$now" \
        --arg action "$action" \
        --arg actor "$actor" \
        --argjson prev "$prev_value" \
        --argjson new "$new_value" \
        --arg reason "$reason" \
        '{
            timestamp: $ts,
            action: $action,
            actor: $actor,
            previous_value: $prev,
            new_value: $new,
            reason: $reason
        }'
}

# Add an epic
add_epic() {
    local name="$1"
    local description="${2:-}"
    local priority="${3:-3}"
    local business_value="${4:-medium}"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found. Run: backlog.sh init" >&2
        return 1
    fi

    # Get next counter and increment
    local counter
    counter=$(jq '.id_counter.epic' "$BACKLOG_FILE")
    local next=$((counter + 1))

    local full_id
    printf -v full_id "EPIC-%03d" "$next"
    local short_id="E${next}"

    local now
    now=$(now_iso)

    local changelog
    changelog=$(add_changelog_entry "CREATED" "architect" "null" '{"status":"PENDING"}' "Initial creation")

    # Update backlog
    local tmp
    tmp=$(mktemp)
    jq \
        --arg id "$full_id" \
        --arg short "$short_id" \
        --arg name "$name" \
        --arg desc "$description" \
        --argjson priority "$priority" \
        --arg bv "$business_value" \
        --arg now "$now" \
        --argjson changelog "[$changelog]" \
        '
        .epics += [{
            id: $id,
            short_id: $short,
            name: $name,
            description: $desc,
            status: "PENDING",
            priority: $priority,
            business_value: $bv,
            features: [],
            source_paths: [],
            changelog: $changelog,
            created_at: $now
        }] |
        .id_counter.epic = (.id_counter.epic + 1) |
        .metrics.total_epics = (.epics | length) |
        .updated_at = $now
        ' "$BACKLOG_FILE" > "$tmp" && mv "$tmp" "$BACKLOG_FILE"

    # Update ID map
    tmp=$(mktemp)
    jq \
        --arg short "$short_id" \
        --arg full "$full_id" \
        '
        .epics[$short] = $full |
        .epics[$full] = $full
        ' "$ID_MAP_FILE" > "$tmp" && mv "$tmp" "$ID_MAP_FILE"

    echo -e "${GREEN}Epic added:${NC} ${short_id} (${full_id})"
    echo -e "  Name: ${name}"
}

# Add a feature to an epic
add_feature() {
    local epic_id="$1"
    local name="$2"
    local description="${3:-}"
    local priority="${4:-3}"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found. Run: backlog.sh init" >&2
        return 1
    fi

    # Resolve epic ID
    local resolved_epic
    resolved_epic=$(resolve_id "$epic_id" "epic")
    if [[ -z "$resolved_epic" ]]; then
        echo "Epic not found: $epic_id" >&2
        return 1
    fi

    # Get next counter and increment
    local counter
    counter=$(jq '.id_counter.feature' "$BACKLOG_FILE")
    local next=$((counter + 1))

    local full_id
    printf -v full_id "FEAT-%03d" "$next"
    local short_id="F${next}"

    local now
    now=$(now_iso)

    local changelog
    changelog=$(add_changelog_entry "CREATED" "architect" "null" '{"status":"PENDING"}' "Initial creation")

    # Update backlog
    local tmp
    tmp=$(mktemp)
    jq \
        --arg epic_id "$resolved_epic" \
        --arg id "$full_id" \
        --arg short "$short_id" \
        --arg name "$name" \
        --arg desc "$description" \
        --argjson priority "$priority" \
        --arg now "$now" \
        --argjson changelog "[$changelog]" \
        '
        (.epics[] | select(.id == $epic_id).features) += [{
            id: $id,
            short_id: $short,
            name: $name,
            description: $desc,
            status: "PENDING",
            priority: $priority,
            tasks: [],
            acceptance_criteria: [],
            source_paths: [],
            changelog: $changelog,
            created_at: $now
        }] |
        .id_counter.feature = (.id_counter.feature + 1) |
        .metrics.total_features = ([.epics[].features | length] | add // 0) |
        .updated_at = $now
        ' "$BACKLOG_FILE" > "$tmp" && mv "$tmp" "$BACKLOG_FILE"

    # Update ID map
    tmp=$(mktemp)
    jq \
        --arg short "$short_id" \
        --arg full "$full_id" \
        '
        .features[$short] = $full |
        .features[$full] = $full
        ' "$ID_MAP_FILE" > "$tmp" && mv "$tmp" "$ID_MAP_FILE"

    echo -e "${GREEN}Feature added:${NC} ${short_id} (${full_id})"
    echo -e "  Name: ${name}"
    echo -e "  Epic: ${epic_id}"
}

# Add a task to a feature
add_task() {
    local feature_id="$1"
    local name="$2"
    local description="${3:-}"
    local priority="${4:-3}"
    local effort_size="${5:-M}"
    local effort_confidence="${6:-medium}"
    local depends_on="${7:-}"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found. Run: backlog.sh init" >&2
        return 1
    fi

    # Resolve feature ID
    local resolved_feature
    resolved_feature=$(resolve_id "$feature_id" "feature")
    if [[ -z "$resolved_feature" ]]; then
        echo "Feature not found: $feature_id" >&2
        return 1
    fi

    # Get next counter and increment
    local counter
    counter=$(jq '.id_counter.task' "$BACKLOG_FILE")
    local next=$((counter + 1))

    local full_id="task_$(task_timestamp)"
    local short_id="T${next}"

    local now
    now=$(now_iso)

    local changelog
    changelog=$(add_changelog_entry "CREATED" "architect" "null" '{"status":"PENDING"}' "Initial creation")

    # Parse depends_on
    local deps_array="[]"
    if [[ -n "$depends_on" ]]; then
        deps_array=$(echo "$depends_on" | tr ',' '\n' | jq -R . | jq -s .)
    fi

    # Update backlog
    local tmp
    tmp=$(mktemp)
    jq \
        --arg feat_id "$resolved_feature" \
        --arg id "$full_id" \
        --arg short "$short_id" \
        --arg name "$name" \
        --arg desc "$description" \
        --argjson priority "$priority" \
        --arg size "$effort_size" \
        --arg confidence "$effort_confidence" \
        --argjson deps "$deps_array" \
        --arg now "$now" \
        --argjson changelog "[$changelog]" \
        '
        (.epics[].features[] | select(.id == $feat_id).tasks) += [{
            id: $id,
            short_id: $short,
            name: $name,
            description: $desc,
            status: "PENDING",
            priority: $priority,
            effort: {
                size: $size,
                confidence: $confidence
            },
            depends_on: $deps,
            blocks: [],
            actor: "architect",
            changelog: $changelog,
            created_at: $now
        }] |
        .id_counter.task = (.id_counter.task + 1) |
        .metrics.total_tasks = ([.epics[].features[].tasks | length] | add // 0) |
        .updated_at = $now
        ' "$BACKLOG_FILE" > "$tmp" && mv "$tmp" "$BACKLOG_FILE"

    # Update ID map
    tmp=$(mktemp)
    jq \
        --arg short "$short_id" \
        --arg full "$full_id" \
        '
        .tasks[$short] = $full |
        .tasks[$full] = $full
        ' "$ID_MAP_FILE" > "$tmp" && mv "$tmp" "$ID_MAP_FILE"

    echo -e "${GREEN}Task added:${NC} ${short_id} (${full_id})"
    echo -e "  Name: ${name}"
    echo -e "  Feature: ${feature_id}"
    if [[ -n "$depends_on" ]]; then
        echo -e "  Depends on: ${depends_on}"
    fi
}

# Resolve short/full/fuzzy ID to full ID
resolve_id() {
    local input="$1"
    local type="${2:-any}"  # epic, feature, task, any

    if [[ ! -f "$ID_MAP_FILE" ]]; then
        return 1
    fi

    local result=""

    # Try direct lookup in ID map
    case "$type" in
        epic)
            result=$(jq -r --arg id "$input" '.epics[$id] // empty' "$ID_MAP_FILE")
            ;;
        feature)
            result=$(jq -r --arg id "$input" '.features[$id] // empty' "$ID_MAP_FILE")
            ;;
        task)
            result=$(jq -r --arg id "$input" '.tasks[$id] // empty' "$ID_MAP_FILE")
            ;;
        any)
            result=$(jq -r --arg id "$input" '
                .epics[$id] // .features[$id] // .tasks[$id] // empty
            ' "$ID_MAP_FILE")
            ;;
    esac

    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    fi

    # Try fuzzy match on names
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        return 1
    fi

    local query
    query=$(echo "$input" | tr '[:upper:]' '[:lower:]')

    # Fuzzy match in backlog
    result=$(jq -r --arg q "$query" '
        # Search epics
        (.epics[] | select(.name | ascii_downcase | contains($q)) | .id) //
        # Search features
        (.epics[].features[] | select(.name | ascii_downcase | contains($q)) | .id) //
        # Search tasks
        (.epics[].features[].tasks[] | select(.name | ascii_downcase | contains($q)) | .id) //
        empty
    ' "$BACKLOG_FILE" | head -1)

    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    fi

    return 1
}

# Update item status (with immutable changelog)
update_status() {
    local id="$1"
    local new_status="$2"
    local reason="${3:-Status update}"
    local actor="${4:-system}"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi

    # Validate status
    case "$new_status" in
        PENDING|IN_PROGRESS|COMPLETE|CANCELLED|BLOCKED) ;;
        *)
            echo "Invalid status: $new_status" >&2
            echo "Valid: PENDING, IN_PROGRESS, COMPLETE, CANCELLED, BLOCKED" >&2
            return 1
            ;;
    esac

    local now
    now=$(now_iso)

    # Determine item type and update
    local resolved_id
    local item_type=""

    if resolved_id=$(resolve_id "$id" "epic"); then
        item_type="epic"
    elif resolved_id=$(resolve_id "$id" "feature"); then
        item_type="feature"
    elif resolved_id=$(resolve_id "$id" "task"); then
        item_type="task"
    else
        echo "Item not found: $id" >&2
        return 1
    fi

    local tmp
    tmp=$(mktemp)

    case "$item_type" in
        epic)
            jq \
                --arg id "$resolved_id" \
                --arg status "$new_status" \
                --arg reason "$reason" \
                --arg actor "$actor" \
                --arg now "$now" \
                '
                (.epics[] | select(.id == $id)) |= (
                    .changelog += [{
                        timestamp: $now,
                        action: "STATUS_CHANGED",
                        actor: $actor,
                        previous_value: .status,
                        new_value: $status,
                        reason: $reason
                    }] |
                    .status = $status |
                    if $status == "COMPLETE" then .completed_at = $now else . end
                ) |
                .updated_at = $now
                ' "$BACKLOG_FILE" > "$tmp" && mv "$tmp" "$BACKLOG_FILE"
            ;;
        feature)
            jq \
                --arg id "$resolved_id" \
                --arg status "$new_status" \
                --arg reason "$reason" \
                --arg actor "$actor" \
                --arg now "$now" \
                '
                (.epics[].features[] | select(.id == $id)) |= (
                    .changelog += [{
                        timestamp: $now,
                        action: "STATUS_CHANGED",
                        actor: $actor,
                        previous_value: .status,
                        new_value: $status,
                        reason: $reason
                    }] |
                    .status = $status |
                    if $status == "COMPLETE" then .completed_at = $now else . end
                ) |
                .updated_at = $now
                ' "$BACKLOG_FILE" > "$tmp" && mv "$tmp" "$BACKLOG_FILE"
            ;;
        task)
            jq \
                --arg id "$resolved_id" \
                --arg status "$new_status" \
                --arg reason "$reason" \
                --arg actor "$actor" \
                --arg now "$now" \
                '
                (.epics[].features[].tasks[] | select(.id == $id)) |= (
                    .changelog += [{
                        timestamp: $now,
                        action: "STATUS_CHANGED",
                        actor: $actor,
                        previous_value: .status,
                        new_value: $status,
                        reason: $reason
                    }] |
                    .status = $status |
                    if $status == "IN_PROGRESS" then .started_at = $now else . end |
                    if $status == "COMPLETE" then .completed_at = $now else . end
                ) |
                .metrics.completed_tasks = ([.epics[]?.features[]?.tasks[]? | select(.status == "COMPLETE")] | length) |
                .metrics.completion_percentage = (
                    if .metrics.total_tasks > 0 then
                        (.metrics.completed_tasks / .metrics.total_tasks * 100 | floor)
                    else 0 end
                ) |
                .updated_at = $now
                ' "$BACKLOG_FILE" > "$tmp" && mv "$tmp" "$BACKLOG_FILE"
            ;;
    esac

    echo -e "${GREEN}Status updated:${NC} $id → $new_status"
}

# Get item details
get_item() {
    local id="$1"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi

    local resolved_id
    local item_type=""

    if resolved_id=$(resolve_id "$id" "epic"); then
        item_type="epic"
        jq --arg id "$resolved_id" '.epics[] | select(.id == $id)' "$BACKLOG_FILE"
    elif resolved_id=$(resolve_id "$id" "feature"); then
        item_type="feature"
        jq --arg id "$resolved_id" '.epics[].features[] | select(.id == $id)' "$BACKLOG_FILE"
    elif resolved_id=$(resolve_id "$id" "task"); then
        item_type="task"
        jq --arg id "$resolved_id" '.epics[].features[].tasks[] | select(.id == $id)' "$BACKLOG_FILE"
    else
        echo "Item not found: $id" >&2
        return 1
    fi
}

# Get all ready tasks (dependencies satisfied)
get_ready_tasks() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi

    jq '
        # Get all completed task IDs
        [.epics[]?.features[]?.tasks[]? | select(.status == "COMPLETE") | .id, .short_id] as $completed |

        # Find tasks where all dependencies are in completed list
        [.epics[]?.features[]?.tasks[]? |
            select(.status == "PENDING") |
            select(
                (.depends_on | length == 0) or
                (.depends_on | all(. as $dep | $completed | index($dep) != null))
            )
        ] |
        sort_by(.priority)
    ' "$BACKLOG_FILE"
}

# Score a task for prioritization
score_task() {
    local task_id="$1"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi

    local resolved_id
    resolved_id=$(resolve_id "$task_id" "task")
    if [[ -z "$resolved_id" ]]; then
        echo "Task not found: $task_id" >&2
        return 1
    fi

    jq --arg id "$resolved_id" '
        # Get the task
        (.epics[]?.features[]?.tasks[]? | select(.id == $id)) as $task |

        # Get parent feature and epic for context
        (.epics[]? | select(.features[]?.tasks[]?.id == $id)) as $epic |
        ($epic.features[]? | select(.tasks[]?.id == $id)) as $feature |

        # Get all completed task IDs
        [.epics[]?.features[]?.tasks[]? | select(.status == "COMPLETE") | .id, .short_id] as $completed |

        # Check if all dependencies satisfied (readiness)
        (if ($task.depends_on | length == 0) or
            ($task.depends_on | all(. as $dep | $completed | index($dep) != null))
         then 100 else 0 end) as $readiness |

        # Count how many tasks this unblocks (dependency_unlock)
        ([.epics[]?.features[]?.tasks[]? |
            select(.depends_on | index($task.id) != null or index($task.short_id) != null)
        ] | length * 20 | if . > 100 then 100 else . end) as $unlock |

        # Business value from epic
        (if $epic.business_value == "critical" then 100
         elif $epic.business_value == "high" then 75
         elif $epic.business_value == "medium" then 50
         else 25 end) as $business |

        # Priority score (1 = highest priority = 100 points)
        ((6 - $task.priority) * 20) as $priority |

        # Calculate final score
        (($priority * 0.35) + ($unlock * 0.25) + ($business * 0.20) + ($readiness * 0.20)) as $score |

        {
            task_id: $task.id,
            short_id: $task.short_id,
            name: $task.name,
            score: ($score | floor),
            breakdown: {
                priority: ($priority | floor),
                dependency_unlock: ($unlock | floor),
                business_value: ($business | floor),
                readiness: ($readiness | floor)
            },
            ready: ($readiness == 100)
        }
    ' "$BACKLOG_FILE"
}

# Get next highest-priority ready task
get_next_task() {
    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi

    # Get all ready tasks with scores
    jq '
        # Get all completed task IDs
        [.epics[]?.features[]?.tasks[]? | select(.status == "COMPLETE") | .id, .short_id] as $completed |

        # Get parent epic for each task
        [.epics[]? as $epic | $epic.features[]? as $feat | $feat.tasks[]? |
            select(.status == "PENDING") |
            select(
                (.depends_on | length == 0) or
                (.depends_on | all(. as $dep | $completed | index($dep) != null))
            ) |
            . + {epic_business_value: $epic.business_value}
        ] |

        # Score each task
        map(
            # Business value from epic
            (if .epic_business_value == "critical" then 100
             elif .epic_business_value == "high" then 75
             elif .epic_business_value == "medium" then 50
             else 25 end) as $business |

            # Priority score
            ((6 - .priority) * 20) as $priority |

            # Simplified score (readiness is 100 since we filtered)
            . + {score: (($priority * 0.35) + ($business * 0.20) + 20) | floor}
        ) |

        # Sort by score descending
        sort_by(-.score) |

        # Return top task
        first
    ' "$BACKLOG_FILE"
}

# Show backlog status
show_status() {
    local filter_id="${1:-}"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found. Run: backlog.sh init" >&2
        return 1
    fi

    local project_name
    project_name=$(jq -r '.project_name' "$BACKLOG_FILE")

    if [[ -z "$filter_id" ]]; then
        # Full dashboard
        local metrics
        metrics=$(jq '.metrics' "$BACKLOG_FILE")

        local total_tasks completed_tasks pct
        total_tasks=$(echo "$metrics" | jq -r '.total_tasks')
        completed_tasks=$(echo "$metrics" | jq -r '.completed_tasks')
        pct=$(echo "$metrics" | jq -r '.completion_percentage')

        # Build progress bar
        local bar_width=20
        local filled=$((pct * bar_width / 100))
        local empty=$((bar_width - filled))
        local bar=""
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done

        echo ""
        echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║${NC}  ${PURPLE}PROJECT:${NC} ${BOLD}${project_name}${NC}"
        echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BOLD}║${NC}"
        echo -e "${BOLD}║${NC}  Progress: ${bar} ${pct}%"
        echo -e "${BOLD}║${NC}"
        echo -e "${BOLD}║${NC}  Epics:"

        # List epics with progress
        jq -r '
            .epics[] | {
                short_id,
                name,
                status,
                done: ([.features[]?.tasks[]? | select(.status == "COMPLETE")] | length),
                total: ([.features[]?.tasks[]?] | length)
            } |
            .pct = (if .total > 0 then (.done * 100 / .total | floor) else 0 end) |
            "\(.short_id)|\(.name)|\(.status)|\(.pct)"
        ' "$BACKLOG_FILE" | while IFS='|' read -r short name status epic_pct; do
            local epic_bar=""
            local filled=$((epic_pct * 10 / 100))
            local empty=$((10 - filled))
            for ((i=0; i<filled; i++)); do epic_bar+="█"; done
            for ((i=0; i<empty; i++)); do epic_bar+="░"; done

            local status_icon
            case "$status" in
                COMPLETE) status_icon="${GREEN}✓${NC}" ;;
                IN_PROGRESS) status_icon="${YELLOW}⟳${NC}" ;;
                PENDING) status_icon="${DIM}○${NC}" ;;
                *) status_icon="?" ;;
            esac

            echo -e "${BOLD}║${NC}  ${status_icon} ${short} ${name}"
            echo -e "${BOLD}║${NC}      [${epic_bar}] ${epic_pct}%"
        done

        echo -e "${BOLD}║${NC}"

        # Show next task
        local next_task
        next_task=$(get_next_task 2>/dev/null || echo "")
        if [[ -n "$next_task" && "$next_task" != "null" ]]; then
            local next_short next_name
            next_short=$(echo "$next_task" | jq -r '.short_id')
            next_name=$(echo "$next_task" | jq -r '.name')
            echo -e "${BOLD}║${NC}  Active: ${CYAN}${next_short}${NC} - ${next_name}"
        fi

        echo -e "${BOLD}║${NC}"
        echo -e "${BOLD}║${NC}  Backlog: ${total_tasks} total, ${completed_tasks} completed"
        echo -e "${BOLD}║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

    else
        # Filtered view for specific epic/feature
        local resolved_id
        if resolved_id=$(resolve_id "$filter_id" "epic"); then
            # Show epic detail
            jq --arg id "$resolved_id" '
                .epics[] | select(.id == $id)
            ' "$BACKLOG_FILE"
        elif resolved_id=$(resolve_id "$filter_id" "feature"); then
            # Show feature detail
            jq --arg id "$resolved_id" '
                .epics[].features[] | select(.id == $id)
            ' "$BACKLOG_FILE"
        else
            echo "Item not found: $filter_id" >&2
            return 1
        fi
    fi
}

# Search items by name
search_items() {
    local query="$1"

    if [[ ! -f "$BACKLOG_FILE" ]]; then
        echo "No backlog found" >&2
        return 1
    fi

    local q
    q=$(echo "$query" | tr '[:upper:]' '[:lower:]')

    jq --arg q "$q" '
        {
            epics: [.epics[] | select(.name | ascii_downcase | contains($q)) | {id, short_id, name, status}],
            features: [.epics[].features[] | select(.name | ascii_downcase | contains($q)) | {id, short_id, name, status}],
            tasks: [.epics[].features[].tasks[] | select(.name | ascii_downcase | contains($q)) | {id, short_id, name, status}]
        }
    ' "$BACKLOG_FILE"
}

# Check if backlog exists
backlog_exists() {
    [[ -f "$BACKLOG_FILE" ]]
}

# Main
case "${1:-status}" in
    init)
        shift
        init_backlog "${1:-}"
        ;;
    add-epic)
        shift
        add_epic "$@"
        ;;
    add-feature)
        shift
        add_feature "$@"
        ;;
    add-task)
        shift
        add_task "$@"
        ;;
    update-status)
        shift
        update_status "$@"
        ;;
    get)
        shift
        get_item "$@"
        ;;
    resolve-id)
        shift
        resolve_id "$@"
        ;;
    ready-tasks)
        get_ready_tasks
        ;;
    next-task)
        get_next_task
        ;;
    score-task)
        shift
        score_task "$@"
        ;;
    status)
        shift
        show_status "${1:-}"
        ;;
    search)
        shift
        search_items "$@"
        ;;
    exists)
        backlog_exists && echo "true" || echo "false"
        ;;
    help|--help|-h)
        cat << 'EOF'
STUDIO Backlog Management

Usage:
  backlog.sh init [project-name]              Initialize backlog
  backlog.sh add-epic <name> [desc]           Add an epic
  backlog.sh add-feature <epic> <name>        Add a feature to epic
  backlog.sh add-task <feature> <name>        Add a task to feature
  backlog.sh update-status <id> <status>      Update item status
  backlog.sh get <id>                         Get item details
  backlog.sh resolve-id <id>                  Resolve short/fuzzy to full ID
  backlog.sh ready-tasks                      List ready tasks
  backlog.sh next-task                        Get highest priority ready task
  backlog.sh score-task <id>                  Calculate task priority score
  backlog.sh status [id]                      Show status dashboard
  backlog.sh search <query>                   Search by name

ID Formats:
  Short: E1, F1, T1
  Full: EPIC-001, FEAT-001, task_20260201_120000
  Fuzzy: "login" matches "User Login" feature

Status Values:
  PENDING, IN_PROGRESS, COMPLETE, CANCELLED, BLOCKED

Examples:
  backlog.sh init "My Project"
  backlog.sh add-epic "User Management"
  backlog.sh add-feature E1 "Authentication"
  backlog.sh add-task F1 "Create login API"
  backlog.sh update-status T1 IN_PROGRESS
  backlog.sh next-task
EOF
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Use 'backlog.sh help' for usage" >&2
        exit 1
        ;;
esac
