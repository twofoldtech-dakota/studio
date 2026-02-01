#!/bin/bash
# check-stop.sh - Handles Stop hook, prevents infinite loops
# Called by Stop hook

set -e

# Read hook input
INPUT=$(cat)

# Check if this is a stop hook that already triggered continuation
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    # Allow stop to prevent infinite loop
    exit 0
fi

# For normal stops, just allow
# The agent-based hooks on SubagentStop handle actual verification
exit 0
