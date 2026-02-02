#!/usr/bin/env bash
# STUDIO Rollback System
# Git-based snapshots for task-level rollback
#
# Usage:
#   rollback.sh create <task_id>     Create snapshot before task
#   rollback.sh list                 List available rollback points
#   rollback.sh preview <task_id>    Show what would be reverted
#   rollback.sh to <task_id>         Rollback to pre-task state
#   rollback.sh cleanup [days]       Remove old snapshots

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Plugin source directory (for reading agents, playbooks, etc.)
STUDIO_DIR="${STUDIO_DIR:-studio}"
# Output directory in user's project (for writing data)
STUDIO_OUTPUT_DIR="${STUDIO_OUTPUT_DIR:-.studio}"

# Tag prefix for STUDIO snapshots
TAG_PREFIX="studio-task-"

# Colors
BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if we're in a git repo
check_git() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository" >&2
        exit 1
    fi
}

# Create snapshot before task execution
create_snapshot() {
    local task_id="$1"

    check_git

    local tag="${TAG_PREFIX}${task_id}"

    # Check if tag already exists
    if git rev-parse "$tag" > /dev/null 2>&1; then
        echo "Snapshot already exists for: $task_id" >&2
        exit 1
    fi

    # Stash any uncommitted changes first
    local stash_result
    stash_result=$(git stash push -m "studio-pre-${task_id}" 2>&1 || echo "no-stash")

    # Create tag at current HEAD
    git tag -a "$tag" -m "STUDIO snapshot before task: $task_id"

    # Record in snapshot log
    local log_file="${STUDIO_OUTPUT_DIR}/data/snapshots.json"
    mkdir -p "$(dirname "$log_file")"

    if [[ ! -f "$log_file" ]]; then
        echo '{"snapshots":[]}' > "$log_file"
    fi

    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit
    commit=$(git rev-parse HEAD)

    local tmp
    tmp=$(mktemp)
    jq --arg id "$task_id" \
       --arg tag "$tag" \
       --arg commit "$commit" \
       --arg time "$now" \
       '.snapshots += [{
         "task_id": $id,
         "tag": $tag,
         "commit": $commit,
         "created_at": $time
       }]' "$log_file" > "$tmp" && mv "$tmp" "$log_file"

    echo -e "${GREEN}Snapshot created:${NC} $tag"
    echo -e "  Commit: ${commit:0:8}"
    echo -e "  Task:   $task_id"
}

# List available snapshots
list_snapshots() {
    check_git

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}ROLLBACK POINTS${NC}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"

    local count=0
    git tag -l "${TAG_PREFIX}*" --sort=-creatordate | head -10 | while read -r tag; do
        count=$((count + 1))
        local task_id="${tag#$TAG_PREFIX}"
        local date
        date=$(git log -1 --format=%ci "$tag" 2>/dev/null | cut -d' ' -f1)
        local commit
        commit=$(git rev-parse "$tag" 2>/dev/null | cut -c1-8)

        # Get stats of changes since snapshot
        local stats
        stats=$(git diff --stat "${tag}..HEAD" 2>/dev/null | tail -1 || echo "no changes")

        echo -e "${BOLD}║${NC}  ${CYAN}${task_id}${NC}"
        echo -e "${BOLD}║${NC}  ├─ Date:   ${date}"
        echo -e "${BOLD}║${NC}  ├─ Commit: ${commit}"
        echo -e "${BOLD}║${NC}  └─ Since:  ${stats}"
        echo -e "${BOLD}║${NC}"
    done

    if [[ $count -eq 0 ]]; then
        echo -e "${BOLD}║${NC}  ${DIM}No snapshots available${NC}"
        echo -e "${BOLD}║${NC}"
    fi

    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Preview what would be reverted
preview_rollback() {
    local task_id="$1"

    check_git

    local tag="${TAG_PREFIX}${task_id}"

    if ! git rev-parse "$tag" > /dev/null 2>&1; then
        echo "Snapshot not found: $task_id" >&2
        exit 1
    fi

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${CYAN}ROLLBACK PREVIEW${NC}: ${task_id}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${BOLD}Files that would be reverted:${NC}"
    echo -e "${BOLD}║${NC}"

    git diff --name-status "${tag}..HEAD" 2>/dev/null | while IFS=$'\t' read -r status file; do
        local status_desc status_color
        case "$status" in
            A) status_desc="added"; status_color="${GREEN}" ;;
            M) status_desc="modified"; status_color="${YELLOW}" ;;
            D) status_desc="deleted"; status_color="${RED}" ;;
            R*) status_desc="renamed"; status_color="${CYAN}" ;;
            *) status_desc="$status"; status_color="${NC}" ;;
        esac
        echo -e "${BOLD}║${NC}    ${status_color}${status_desc}${NC}: ${file}"
    done

    echo -e "${BOLD}║${NC}"

    local stats
    stats=$(git diff --stat "${tag}..HEAD" 2>/dev/null | tail -1)
    echo -e "${BOLD}║${NC}  ${BOLD}Summary:${NC} ${stats}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Run 'rollback.sh to ${task_id}' to apply"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Perform rollback
rollback_to() {
    local task_id="$1"
    local force="${2:-}"

    check_git

    local tag="${TAG_PREFIX}${task_id}"

    if ! git rev-parse "$tag" > /dev/null 2>&1; then
        echo "Snapshot not found: $task_id" >&2
        exit 1
    fi

    # Check for uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
        if [[ "$force" != "--force" ]]; then
            echo "Commit or stash them first, or use --force to discard"
            exit 1
        fi
    fi

    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC}  ${YELLOW}ROLLBACK${NC}: ${task_id}"
    echo -e "${BOLD}╠══════════════════════════════════════════════════════════════╣${NC}"

    # Show what will be reverted
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  Files to be reverted:"
    git diff --name-only "${tag}..HEAD" | head -10 | while read -r file; do
        echo -e "${BOLD}║${NC}    - ${file}"
    done

    local file_count
    file_count=$(git diff --name-only "${tag}..HEAD" | wc -l)
    if [[ "$file_count" -gt 10 ]]; then
        echo -e "${BOLD}║${NC}    ... and $((file_count - 10)) more"
    fi

    echo -e "${BOLD}║${NC}"

    if [[ "$force" != "--force" ]]; then
        echo -e "${BOLD}║${NC}  ${YELLOW}This will revert ${file_count} files.${NC}"
        echo -e "${BOLD}║${NC}"
        echo -e "${BOLD}║${NC}  Add --force to confirm: rollback.sh to ${task_id} --force"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        exit 0
    fi

    # Perform the rollback
    echo -e "${BOLD}║${NC}  Performing rollback..."

    # Checkout files from the tag
    git checkout "$tag" -- . 2>/dev/null

    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${GREEN}Rollback complete!${NC}"
    echo -e "${BOLD}║${NC}  Reverted to state before: ${task_id}"
    echo -e "${BOLD}║${NC}"
    echo -e "${BOLD}║${NC}  ${DIM}Note: Changes are staged but not committed.${NC}"
    echo -e "${BOLD}║${NC}  ${DIM}Review and commit when ready.${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
}

# Cleanup old snapshots
cleanup_snapshots() {
    local days="${1:-30}"

    check_git

    echo ""
    echo -e "${BOLD}Cleaning up snapshots older than ${days} days...${NC}"

    local cutoff
    if [[ "$(uname)" == "Darwin" ]]; then
        cutoff=$(date -v-${days}d +%s)
    else
        cutoff=$(date -d "$days days ago" +%s)
    fi

    local removed=0
    git tag -l "${TAG_PREFIX}*" | while read -r tag; do
        local tag_date
        tag_date=$(git log -1 --format=%ct "$tag" 2>/dev/null || echo 0)

        if [[ "$tag_date" -lt "$cutoff" ]]; then
            echo "  Removing: $tag"
            git tag -d "$tag" > /dev/null 2>&1
            removed=$((removed + 1))
        fi
    done

    echo -e "${GREEN}Removed ${removed} old snapshots${NC}"
}

# Delete a specific snapshot
delete_snapshot() {
    local task_id="$1"

    check_git

    local tag="${TAG_PREFIX}${task_id}"

    if ! git rev-parse "$tag" > /dev/null 2>&1; then
        echo "Snapshot not found: $task_id" >&2
        exit 1
    fi

    git tag -d "$tag"
    echo -e "${GREEN}Deleted snapshot:${NC} $task_id"
}

# Main
case "${1:-list}" in
    create)
        shift
        create_snapshot "$@"
        ;;
    list)
        list_snapshots
        ;;
    preview)
        shift
        preview_rollback "$@"
        ;;
    to)
        shift
        rollback_to "$@"
        ;;
    cleanup)
        shift
        cleanup_snapshots "${1:-30}"
        ;;
    delete)
        shift
        delete_snapshot "$@"
        ;;
    help|--help|-h)
        cat << 'EOF'
STUDIO Rollback System

Usage:
  rollback.sh create <task_id>     Create snapshot before task starts
  rollback.sh list                 List available rollback points
  rollback.sh preview <task_id>    Preview what would be reverted
  rollback.sh to <task_id>         Rollback to pre-task state
  rollback.sh to <task_id> --force Rollback without confirmation
  rollback.sh cleanup [days]       Remove snapshots older than N days
  rollback.sh delete <task_id>     Delete a specific snapshot

How it works:
  - Snapshots are git tags created before each task starts
  - Rollback uses 'git checkout' to restore files
  - Changes are staged but not committed after rollback
  - Original snapshots are preserved for audit trail

Examples:
  rollback.sh create task_20260201_120000
  rollback.sh preview task_20260201_120000
  rollback.sh to task_20260201_120000 --force
EOF
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Use 'rollback.sh help' for usage" >&2
        exit 1
        ;;
esac
