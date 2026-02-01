#!/usr/bin/env bash
#
# STUDIO Cast Validator
# ====================
#
# Validates that the Caster agent has properly executed all steps
# before allowing it to stop.
#
# Exit codes:
#   0 - Approved (cast complete or awaiting quality gate)
#   Returns JSON with decision:block if incomplete
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
CASTS_DIR="${STUDIO_DIR}/casts"

# Find active cast
find_active_cast() {
    if [[ ! -d "$CASTS_DIR" ]]; then
        return 1
    fi

    local cast_dir
    for cast_dir in "$CASTS_DIR"/cast_*/; do
        if [[ -d "$cast_dir" ]]; then
            local state_file="${cast_dir}state.json"
            if [[ -f "$state_file" ]]; then
                local status
                status=$(jq -r '.status // empty' "$state_file" 2>/dev/null)
                if [[ "$status" == "CASTING" || "$status" == "FORGING" || "$status" == "in_progress" ]]; then
                    echo "${cast_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

main() {
    # Find active cast
    local cast_dir
    if ! cast_dir=$(find_active_cast); then
        # No active cast, allow
        exit 0
    fi

    local state_file="${cast_dir}/state.json"
    local blueprint_file="${cast_dir}/blueprint.json"

    # Check state exists
    if [[ ! -f "$state_file" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Cast state not found. The Caster must maintain state.json."
}
EOF
        exit 0
    fi

    # Get cast status
    local status
    status=$(jq -r '.status // empty' "$state_file" 2>/dev/null)

    # If status is AWAITING_QUALITY_GATE or COMPLETE, allow
    if [[ "$status" == "AWAITING_QUALITY_GATE" || "$status" == "COMPLETE" ]]; then
        exit 0
    fi

    # If status is HALTED, allow (intentional halt)
    if [[ "$status" == "HALTED" ]]; then
        exit 0
    fi

    # Check if blueprint exists
    if [[ ! -f "$blueprint_file" ]]; then
        cat << EOF
{
  "decision": "block",
  "reason": "Blueprint not found. Cannot validate cast completion."
}
EOF
        exit 0
    fi

    # Get total steps from blueprint
    local total_steps
    total_steps=$(jq -r '.steps | length' "$blueprint_file" 2>/dev/null)

    # Count completed steps from state
    local completed_steps=0
    local failed_steps=0
    local skipped_steps=0

    for ((i=1; i<=total_steps; i++)); do
        local step_status
        step_status=$(jq -r ".steps.\"step_$i\".status // empty" "$state_file" 2>/dev/null)

        case "$step_status" in
            success|completed)
                ((completed_steps++))
                ;;
            failed)
                ((failed_steps++))
                ;;
            skipped)
                ((skipped_steps++))
                ;;
        esac
    done

    local processed_steps=$((completed_steps + skipped_steps))

    # If all steps processed, should be awaiting quality gate
    if [[ $processed_steps -eq $total_steps ]]; then
        # Update status and allow
        local tmp_state
        tmp_state=$(mktemp)
        jq '.status = "AWAITING_QUALITY_GATE" | .all_steps_complete = true' "$state_file" > "$tmp_state" && mv "$tmp_state" "$state_file"
        exit 0
    fi

    # Steps incomplete
    local current_step
    current_step=$(jq -r '.current_step // "unknown"' "$state_file" 2>/dev/null)

    cat << EOF
{
  "decision": "block",
  "reason": "Cast incomplete. $processed_steps/$total_steps steps processed.",
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "CAST INCOMPLETE\\n\\nTotal steps: $total_steps\\nCompleted: $completed_steps\\nSkipped: $skipped_steps\\nFailed: $failed_steps\\nCurrent step: $current_step\\n\\nContinue executing steps until all are processed."
  }
}
EOF
    exit 0
}

main "$@"
