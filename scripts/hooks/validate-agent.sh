#!/usr/bin/env bash
#
# STUDIO Subagent Stop Validator
# =============================
#
# Validates that STUDIO agents have properly written their JSON outputs.
# This script is called by the SubagentStop hook.
#
# Arguments:
#   $1 - Agent name (smith, forgemaster, temperer)
#
# Exit codes:
#   0 - Approved (JSON files written correctly)
#   2 - Blocked (missing or invalid JSON files)
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
CASTS_DIR="${STUDIO_DIR}/casts"

# Find the active cast directory
find_active_cast() {
    if [[ ! -d "$CASTS_DIR" ]]; then
        return 1
    fi

    # Find cast with non-complete status
    local cast_dir
    for cast_dir in "$CASTS_DIR"/cast_*/; do
        if [[ -d "$cast_dir" ]]; then
            local state_file="${cast_dir}state.json"
            if [[ -f "$state_file" ]]; then
                local status
                status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
                if [[ "$status" != "COMPLETE" && "$status" != "FAILED" && "$status" != "ABORTED" ]]; then
                    echo "${cast_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

# Validate Smith (Blueprinting) output
validate_smith() {
    local cast_dir="$1"
    local blueprint_file="${cast_dir}/blueprint.json"
    local state_file="${cast_dir}/state.json"

    # Check if blueprint.json exists
    if [[ ! -f "$blueprint_file" ]]; then
        echo '{"decision": "block", "reason": "Blueprint JSON not written: blueprint.json is missing"}'
        exit 0
    fi

    # Check if blueprint has required fields
    if ! grep -q '"id"' "$blueprint_file" || ! grep -q '"cast_id"' "$blueprint_file"; then
        echo '{"decision": "block", "reason": "Blueprint JSON invalid: missing id or cast_id"}'
        exit 0
    fi

    # Check if state.json has blueprint_id
    if [[ -f "$state_file" ]] && ! grep -q '"blueprint_id"' "$state_file"; then
        echo '{"decision": "block", "reason": "State not updated: blueprint_id not set"}'
        exit 0
    fi

    # Blueprint valid, allow stopping
    exit 0
}

# Validate Forgemaster output
validate_forgemaster() {
    local cast_dir="$1"
    local forge_log="${cast_dir}/forge-log.json"

    # Check if forge-log.json exists
    if [[ ! -f "$forge_log" ]]; then
        echo '{"decision": "block", "reason": "Forge log JSON not written: forge-log.json is missing"}'
        exit 0
    fi

    # Check if forge log has required fields
    if ! grep -q '"blueprint_id"' "$forge_log" || ! grep -q '"records"' "$forge_log"; then
        echo '{"decision": "block", "reason": "Forge log JSON invalid: missing blueprint_id or records"}'
        exit 0
    fi

    # Forge log valid, allow stopping
    exit 0
}

# Validate Temperer output
validate_temperer() {
    local cast_dir="$1"
    local temper_report="${cast_dir}/temper-report.json"

    # Check if temper-report.json exists
    if [[ ! -f "$temper_report" ]]; then
        echo '{"decision": "block", "reason": "Temper report JSON not written: temper-report.json is missing"}'
        exit 0
    fi

    # Check if temper report has verdict
    local verdict
    verdict=$(grep -o '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "$temper_report" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

    if [[ -z "$verdict" ]]; then
        echo '{"decision": "block", "reason": "Temper report JSON invalid: missing verdict"}'
        exit 0
    fi

    # Temper report valid, allow stopping
    exit 0
}

# Main
main() {
    local agent_name="${1:-}"

    # Normalize agent name to lowercase
    agent_name=$(echo "$agent_name" | tr '[:upper:]' '[:lower:]')

    # Find active cast
    local cast_dir
    if ! cast_dir=$(find_active_cast); then
        # No active cast found, allow stopping
        exit 0
    fi

    case "$agent_name" in
        smith)
            validate_smith "$cast_dir"
            ;;
        forgemaster)
            validate_forgemaster "$cast_dir"
            ;;
        temperer)
            validate_temperer "$cast_dir"
            ;;
        *)
            # Unknown agent, allow stopping
            exit 0
            ;;
    esac
}

main "$@"
