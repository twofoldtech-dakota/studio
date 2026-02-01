#!/usr/bin/env bash
#
# STUDIO Stop Hook Validator
# =========================
#
# Validates that STUDIO casts are properly completed before stopping.
# This script is called by the Stop hook to ensure tempering was performed.
#
# Exit codes:
#   0 - Approved (not an STUDIO cast, or properly completed)
#   2 - Blocked (STUDIO cast incomplete or failed tempering)
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
CASTS_DIR="${STUDIO_DIR}/casts"

# Check if this is an STUDIO session by looking for active casts
check_studio_session() {
    if [[ ! -d "$CASTS_DIR" ]]; then
        # No STUDIO casts directory, allow stopping
        exit 0
    fi

    # Find the most recent cast directory
    local latest_cast
    latest_cast=$(find "$CASTS_DIR" -maxdepth 1 -type d -name "cast_*" 2>/dev/null | sort -r | head -1)

    if [[ -z "$latest_cast" ]]; then
        # No STUDIO casts found, allow stopping
        exit 0
    fi

    echo "$latest_cast"
}

# Validate a cast's completion state
validate_cast() {
    local cast_dir="$1"
    local state_file="${cast_dir}/state.json"
    local temper_file="${cast_dir}/temper-report.json"

    # Check if state.json exists
    if [[ ! -f "$state_file" ]]; then
        # No active cast state, allow stopping
        exit 0
    fi

    # Read the status from state.json
    local status
    status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$state_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

    # If status is COMPLETE, we're good
    if [[ "$status" == "COMPLETE" ]]; then
        # Exit 0 with no decision = allow stopping
        exit 0
    fi

    # If status is INITIALIZING, BLUEPRINTING, or FORGING, check if user is abandoning
    case "$status" in
        INITIALIZING|BLUEPRINTING|FORGING)
            # Allow stopping during these phases (user may want to cancel)
            exit 0
            ;;
        TEMPERING)
            # During tempering, check if temper report exists
            if [[ ! -f "$temper_file" ]]; then
                echo '{"decision": "block", "reason": "STUDIO cast incomplete: Tempering phase in progress. Please wait for tempering to complete."}'
                exit 0
            fi
            ;;
        FAILED|ABORTED)
            # Allow stopping if cast already failed or aborted
            exit 0
            ;;
    esac

    # Check temper report if it exists
    if [[ -f "$temper_file" ]]; then
        local verdict
        verdict=$(grep -o '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "$temper_file" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

        case "$verdict" in
            STRONG|SOUND)
                # Cast verified successfully, allow stopping
                exit 0
                ;;
            BRITTLE)
                echo '{"decision": "block", "reason": "STUDIO cast incomplete: BRITTLE verdict - Issues need to be fixed before completion."}'
                exit 0
                ;;
            CRACKED)
                echo '{"decision": "block", "reason": "STUDIO cast incomplete: CRACKED verdict - Critical issues prevent completion."}'
                exit 0
                ;;
        esac
    fi

    # Default: allow if we can't determine state
    exit 0
}

# Main
main() {
    local cast_dir
    cast_dir=$(check_studio_session)

    # If check_studio_session exited, we're done
    # Otherwise, validate the cast
    if [[ -n "$cast_dir" && -d "$cast_dir" ]]; then
        validate_cast "$cast_dir"
    fi
}

main
