#!/usr/bin/env bash
#
# STUDIO Quality Gate Hook
# ========================
#
# Final validation hook that runs when Claude Code stops.
# Real-time quality assurance for build completion.
#
# This hook:
# 1. Checks if there's an active task awaiting quality gate
# 2. Runs the quality_gate.checks from the plan
# 3. Returns verdict (STRONG/SOUND/BLOCK)
#
# Exit codes:
#   0 - Allow stop (no active task or quality gate passed)
#   Returns JSON with decision:block if quality gate fails
#

set -euo pipefail

STUDIO_DIR="${STUDIO_DIR:-studio}"
PROJECTS_DIR="${STUDIO_DIR}/projects"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log completed build to analytics
log_to_analytics() {
    local manifest="$1"
    local verdict="$2"
    local status="${3:-COMPLETE}"

    local task_id duration_ms steps retries

    # Get task ID from manifest
    task_id=$(jq -r '.id // "unknown"' "$manifest")

    # Calculate duration from started_at to now
    local started
    started=$(jq -r '.started_at // empty' "$manifest")
    if [[ -n "$started" ]]; then
        local start_epoch end_epoch
        # Try GNU date first, then BSD date
        start_epoch=$(date -d "$started" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" +%s 2>/dev/null || echo 0)
        end_epoch=$(date +%s)
        duration_ms=$(( (end_epoch - start_epoch) * 1000 ))
    else
        duration_ms=0
    fi

    # Get step count and retry count
    steps=$(jq -r '.completed_steps | length // 0' "$manifest" 2>/dev/null || echo 0)
    retries=$(jq -r '.retry_count // 0' "$manifest" 2>/dev/null || echo 0)

    # Call analytics.sh log
    local analytics_script="${SCRIPT_DIR}/../analytics.sh"
    if [[ -x "$analytics_script" ]]; then
        "$analytics_script" log "$task_id" "$status" "$duration_ms" "$steps" "$retries" "$verdict" 2>/dev/null || true
    fi
}

# Read hook input
INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# Prevent infinite loops
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
    exit 0
fi

# Find task awaiting quality gate
find_awaiting_task() {
    if [[ ! -d "$PROJECTS_DIR" ]]; then
        return 1
    fi

    local task_dir
    # Search through all projects and tasks
    for task_dir in "$PROJECTS_DIR"/*/tasks/task_*/; do
        if [[ -d "$task_dir" ]]; then
            local manifest_file="${task_dir}manifest.json"
            if [[ -f "$manifest_file" ]]; then
                local status
                status=$(jq -r '.status // empty' "$manifest_file" 2>/dev/null)
                if [[ "$status" == "AWAITING_QUALITY_GATE" ]]; then
                    echo "${task_dir%/}"
                    return 0
                fi
            fi
        fi
    done

    return 1
}

run_quality_checks() {
    local plan_file="$1"
    local results=()
    local all_required_pass=true
    local any_optional_fail=false

    # Get quality gate checks from plan
    local checks
    checks=$(jq -c '.validation_hooks.quality_gate.checks[]?' "$plan_file" 2>/dev/null)

    if [[ -z "$checks" ]]; then
        # No quality gate defined, pass by default
        echo "STRONG"
        return 0
    fi

    while IFS= read -r check; do
        if [[ -z "$check" ]]; then
            continue
        fi

        local name
        local command
        local required

        name=$(echo "$check" | jq -r '.name // "Unnamed check"')
        command=$(echo "$check" | jq -r '.command // empty')
        required=$(echo "$check" | jq -r '.required // true')

        if [[ -z "$command" ]]; then
            continue
        fi

        # Run the check
        local result
        local exit_code
        result=$(eval "$command" 2>&1) || exit_code=$?
        exit_code=${exit_code:-0}

        if [[ $exit_code -eq 0 ]]; then
            results+=("PASS: $name")
        else
            results+=("FAIL: $name")
            if [[ "$required" == "true" ]]; then
                all_required_pass=false
            else
                any_optional_fail=true
            fi
        fi
    done <<< "$checks"

    # Determine verdict
    if [[ "$all_required_pass" == "true" ]]; then
        if [[ "$any_optional_fail" == "false" ]]; then
            echo "STRONG"
        else
            echo "SOUND"
        fi
    else
        echo "BLOCK"
    fi

    # Output results
    printf '%s\n' "${results[@]}" >&2
}

main() {
    # Find task awaiting quality gate
    local task_dir
    if ! task_dir=$(find_awaiting_task); then
        # No task awaiting quality gate, allow stop
        exit 0
    fi

    local plan_file="${task_dir}/plan.json"
    local manifest_file="${task_dir}/manifest.json"

    if [[ ! -f "$plan_file" ]]; then
        # No plan, allow stop
        exit 0
    fi

    # Run quality checks
    local verdict
    verdict=$(run_quality_checks "$plan_file")

    case "$verdict" in
        STRONG)
            # Perfect - all checks pass
            local tmp_state
            tmp_state=$(mktemp)
            jq '.status = "COMPLETE" | .quality_gate.result = "STRONG" | .quality_gate.triggered = true | .completed_at = now | .updated_at = now' "$manifest_file" > "$tmp_state" && mv "$tmp_state" "$manifest_file"

            # Log to analytics
            log_to_analytics "$manifest_file" "STRONG" "COMPLETE"

            # Allow stop
            exit 0
            ;;

        SOUND)
            # Good enough - required checks pass, optional warnings
            local tmp_state
            tmp_state=$(mktemp)
            jq '.status = "COMPLETE" | .quality_gate.result = "SOUND" | .quality_gate.triggered = true | .completed_at = now | .updated_at = now' "$manifest_file" > "$tmp_state" && mv "$tmp_state" "$manifest_file"

            # Log to analytics
            log_to_analytics "$manifest_file" "SOUND" "COMPLETE"

            # Allow stop
            exit 0
            ;;

        BLOCK)
            # Quality gate failed
            local tmp_state
            tmp_state=$(mktemp)
            jq '.quality_gate.result = "FAILED" | .quality_gate.triggered = true | .updated_at = now' "$manifest_file" > "$tmp_state" && mv "$tmp_state" "$manifest_file"

            # Log to analytics
            log_to_analytics "$manifest_file" "BLOCK" "FAILED"

            # Get failed checks for feedback
            local failed_checks
            failed_checks=$(jq -r '.validation_hooks.quality_gate.checks[] | select(.required == true) | .name' "$plan_file" 2>/dev/null | head -5)

            cat << EOF
{
  "decision": "block",
  "reason": "Quality gate failed. Required checks did not pass.",
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "QUALITY GATE FAILED\\n\\nRequired checks that may have failed:\\n$failed_checks\\n\\nFix the failing checks and try again. Run the individual check commands to diagnose issues."
  }
}
EOF
            exit 0
            ;;
    esac

    # Default: allow
    exit 0
}

main "$@"
