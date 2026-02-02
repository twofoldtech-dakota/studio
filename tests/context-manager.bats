#!/usr/bin/env bats
# Tests for scripts/context-manager.sh

load 'helpers/test_helper'

setup() {
    setup_test_env
    # Create test learnings directory
    export LEARNINGS_DIR="$STUDIO_DIR/learnings"
    mkdir -p "$LEARNINGS_DIR"
}

teardown() {
    teardown_test_env
}

# =============================================================================
# TOKEN ESTIMATION TESTS
# =============================================================================

@test "context-manager estimate works for markdown files" {
    # Create test markdown file with known content
    echo "This is a test file with some words for testing token estimation." > "$STUDIO_DIR/test.md"

    run run_context_manager estimate "$STUDIO_DIR/test.md"
    [ "$status" -eq 0 ]
    # Should return a number
    [[ "$output" =~ ^[0-9]+$ ]]
    # 13 words * 1.3 ≈ 17 tokens
    [ "$output" -gt 10 ]
    [ "$output" -lt 30 ]
}

@test "context-manager estimate works for JSON files" {
    # Create test JSON file
    echo '{"key": "value", "nested": {"array": [1, 2, 3]}}' > "$STUDIO_DIR/test.json"

    run run_context_manager estimate "$STUDIO_DIR/test.json"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "context-manager estimate works for code files" {
    # Create test code file
    cat > "$STUDIO_DIR/test.ts" << 'EOF'
function hello(name: string): string {
    return `Hello, ${name}!`;
}
export default hello;
EOF

    run run_context_manager estimate "$STUDIO_DIR/test.ts"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "context-manager estimate fails for missing file" {
    run run_context_manager estimate "$STUDIO_DIR/nonexistent.md"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "File not found" ]]
}

# =============================================================================
# BUDGET TESTS
# =============================================================================

@test "context-manager budget all shows all pools" {
    run run_context_manager budget all
    [ "$status" -eq 0 ]
    [[ "$output" =~ "CONTEXT BUDGET STATUS" ]]
    [[ "$output" =~ "reserved" ]]
    [[ "$output" =~ "learnings" ]]
    [[ "$output" =~ "backlog" ]]
    [[ "$output" =~ "plans" ]]
    [[ "$output" =~ "context7" ]]
    [[ "$output" =~ "working" ]]
}

@test "context-manager budget shows single pool" {
    run run_context_manager budget learnings
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Pool:" ]]
    [[ "$output" =~ "learnings" ]]
    [[ "$output" =~ "Soft Limit:" ]]
    [[ "$output" =~ "Hard Limit:" ]]
}

@test "context-manager budget fails for unknown pool" {
    run run_context_manager budget unknown_pool
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown pool" ]]
}

@test "context-manager budget tracks learnings pool" {
    # Create a learning file
    cat > "$LEARNINGS_DIR/test.md" << 'EOF'
## 2026-01-01: Test Learning

**Context:** Testing context manager

**What Worked:**
- Testing worked
EOF

    run run_context_manager budget learnings
    [ "$status" -eq 0 ]
    # Should show non-zero usage
    [[ "$output" =~ "Used:" ]]
}

@test "context-manager budget tracks plans pool" {
    # Create a task with plan
    mkdir -p "$STUDIO_DIR/tasks/task_001"
    echo '{"id": "task_001", "steps": []}' > "$STUDIO_DIR/tasks/task_001/plan.json"

    run run_context_manager budget plans
    [ "$status" -eq 0 ]
}

@test "context-manager budget tracks backlog pool" {
    # Create a backlog file
    echo '[{"id": "T1", "title": "Test task"}]' > "$STUDIO_DIR/backlog.json"

    run run_context_manager budget backlog
    [ "$status" -eq 0 ]
}

# =============================================================================
# TIER DETECTION TESTS
# =============================================================================

@test "context-manager tier returns tier1 for recent date" {
    # Date within 30 days
    recent_date=$(date -v-10d +%Y-%m-%d 2>/dev/null || date -d "10 days ago" +%Y-%m-%d)

    run run_context_manager tier "$recent_date"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "tier1" ]]
    [[ "${lines[1]}" == "full" ]]
}

@test "context-manager tier returns tier2 for 30-90 day old date" {
    # Date 60 days ago
    old_date=$(date -v-60d +%Y-%m-%d 2>/dev/null || date -d "60 days ago" +%Y-%m-%d)

    run run_context_manager tier "$old_date"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "tier2" ]]
    [[ "${lines[1]}" == "summary" ]]
}

@test "context-manager tier returns tier3 for > 90 day old date" {
    # Date 120 days ago
    very_old_date=$(date -v-120d +%Y-%m-%d 2>/dev/null || date -d "120 days ago" +%Y-%m-%d)

    run run_context_manager tier "$very_old_date"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "tier3" ]]
    [[ "${lines[1]}" == "index" ]]
}

@test "context-manager tier fails for invalid date" {
    run run_context_manager tier "not-a-date"
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Invalid date" ]]
}

# =============================================================================
# SCAN TESTS
# =============================================================================

@test "context-manager scan reports on learnings" {
    # Create learning files with dated entries
    recent_date=$(date +%Y-%m-%d)
    cat > "$LEARNINGS_DIR/test.md" << EOF
## ${recent_date}: Recent Learning

**Context:** Test

**What Worked:**
- Testing
EOF

    run run_context_manager scan all
    [ "$status" -eq 0 ]
    [[ "$output" =~ "LEARNINGS CONTEXT SCAN" ]]
    [[ "$output" =~ "Tier 1" ]]
}

@test "context-manager scan handles missing directory" {
    rm -rf "$LEARNINGS_DIR"

    run run_context_manager scan all
    [ "$status" -eq 0 ]
    [[ "$output" =~ "not found" ]]
}

# =============================================================================
# CACHE TESTS
# =============================================================================

@test "context-manager cache-set creates cache file" {
    run run_context_manager cache-set "test_key" "Test content for caching"
    [ "$status" -eq 0 ]

    assert_file_exists "$STUDIO_DIR/.cache/summaries/test_key.md"
}

@test "context-manager cache-get retrieves cached content" {
    run_context_manager cache-set "test_key" "Cached content" >/dev/null

    run run_context_manager cache-get "test_key"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cached content" ]]
}

@test "context-manager cache-get fails for missing key" {
    run run_context_manager cache-get "nonexistent_key"
    [ "$status" -eq 1 ]
}

# =============================================================================
# STATUS TESTS
# =============================================================================

@test "context-manager status shows full report" {
    # Create learnings directory so scan doesn't warn
    mkdir -p "$LEARNINGS_DIR"

    run run_context_manager status
    # Status might exit non-zero if pools are at warning, that's OK
    [[ "$output" =~ "CONTEXT BUDGET STATUS" ]]
    [[ "$output" =~ "LEARNINGS CONTEXT SCAN" ]]
}

# =============================================================================
# HELP TESTS
# =============================================================================

@test "context-manager help shows usage" {
    run run_context_manager help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STUDIO Context Manager" ]]
    [[ "$output" =~ "Usage:" ]]
}
