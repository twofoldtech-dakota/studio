#!/usr/bin/env bash
# STUDIO Context Caching Hook
# Caches frequently-used context at session start for faster loading
#
# Cache includes:
# - Memory rules (global and domain-specific)
# - Tier1 team member definitions
# - Playbook skills
# - Brand context (if exists)
#
# Cache TTL: 1 hour (3600 seconds)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STUDIO_ROOT="${SCRIPT_DIR}/../.."
STUDIO_DIR="${STUDIO_DIR:-studio}"

CACHE_DIR="${STUDIO_DIR}/.cache"
CACHE_FILE="${CACHE_DIR}/context-cache.json"
CACHE_TTL=3600  # 1 hour in seconds

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Check if cache is still valid
is_cache_valid() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi

    local now
    local cache_time
    local age

    now=$(date +%s)

    # Get file modification time (cross-platform)
    if [[ "$(uname)" == "Darwin" ]]; then
        cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
    else
        cache_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    fi

    age=$((now - cache_time))

    if [[ $age -lt $CACHE_TTL ]]; then
        return 0
    fi

    return 1
}

# Build fresh cache
build_cache() {
    local cache='{"cached_at":"","memory_rules":{},"team":{},"playbooks":{},"brand":{}}'
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cache=$(echo "$cache" | jq --arg t "$now" '.cached_at = $t')

    # Cache memory rules
    if [[ -d "${STUDIO_DIR}/memory" ]]; then
        for rule_file in "${STUDIO_DIR}/memory"/*.md; do
            if [[ -f "$rule_file" ]]; then
                local name
                name=$(basename "$rule_file" .md)
                local content
                content=$(cat "$rule_file" | jq -Rs .)
                cache=$(echo "$cache" | jq --arg name "$name" --argjson content "$content" '.memory_rules[$name] = $content')
            fi
        done
    fi

    # Cache tier1 team members
    if [[ -d "${STUDIO_ROOT}/team/tier1" ]]; then
        for team_file in "${STUDIO_ROOT}/team/tier1"/*.md; do
            if [[ -f "$team_file" ]]; then
                local name
                name=$(basename "$team_file" .md)
                local content
                content=$(cat "$team_file" | jq -Rs .)
                cache=$(echo "$cache" | jq --arg name "$name" --argjson content "$content" '.team.tier1[$name] = $content')
            fi
        done
    fi

    # Cache playbook skills
    if [[ -d "${STUDIO_ROOT}/playbooks" ]]; then
        for skill_file in "${STUDIO_ROOT}/playbooks"/*/SKILL.md; do
            if [[ -f "$skill_file" ]]; then
                local name
                name=$(dirname "$skill_file" | xargs basename)
                local content
                content=$(cat "$skill_file" | jq -Rs .)
                cache=$(echo "$cache" | jq --arg name "$name" --argjson content "$content" '.playbooks[$name] = $content')
            fi
        done
    fi

    # Cache brand context if exists
    if [[ -f "brand/identity.yaml" ]]; then
        local content
        content=$(cat "brand/identity.yaml" | jq -Rs .)
        cache=$(echo "$cache" | jq --argjson content "$content" '.brand.identity = $content')
    fi

    if [[ -f "brand/voice.yaml" ]]; then
        local content
        content=$(cat "brand/voice.yaml" | jq -Rs .)
        cache=$(echo "$cache" | jq --argjson content "$content" '.brand.voice = $content')
    fi

    # Write cache
    echo "$cache" | jq '.' > "$CACHE_FILE"

    # Count cached items
    local memory_count
    local team_count
    local playbook_count

    memory_count=$(echo "$cache" | jq '.memory_rules | length')
    team_count=$(echo "$cache" | jq '.team.tier1 // {} | length')
    playbook_count=$(echo "$cache" | jq '.playbooks | length')

    echo "Context cached: ${memory_count} memory rules, ${team_count} team members, ${playbook_count} playbooks" >&2
}

# Main
main() {
    if is_cache_valid; then
        # Return cached context
        cat "$CACHE_FILE"
    else
        # Build fresh cache
        build_cache
        cat "$CACHE_FILE"
    fi
}

# Handle different invocation modes
case "${1:-load}" in
    load)
        main
        ;;
    invalidate)
        rm -f "$CACHE_FILE"
        echo "Cache invalidated" >&2
        ;;
    status)
        if is_cache_valid; then
            echo "Cache: valid"
            jq -r '"Cached at: \(.cached_at)\nMemory rules: \(.memory_rules | length)\nTeam members: \(.team.tier1 // {} | length)\nPlaybooks: \(.playbooks | length)"' "$CACHE_FILE"
        else
            echo "Cache: expired or missing"
        fi
        ;;
    *)
        echo "Usage: cache-context.sh {load|invalidate|status}" >&2
        exit 1
        ;;
esac
