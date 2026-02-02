#!/usr/bin/env bats
# Integration tests for STUDIO orchestration workflow

load 'helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# FULL WORKFLOW TESTS
# =============================================================================

@test "full workflow: init -> route -> planner -> handoff -> builder" {
    # 1. Initialize orchestration
    session_id=$(run_orchestrator init "Add user authentication" implicit | grep -o 'orch_[0-9_a-f]*' | head -1)
    [[ "$session_id" =~ "orch_" ]]

    # 2. Route the goal (filter log lines to get JSON)
    routing=$(run_orchestrator route 2>/dev/null | grep -v '^\[Orchestrator\]')
    workflow=$(echo "$routing" | jq -r '.selected_workflow')
    [ "$workflow" = "plan_then_build" ]

    # 3. Start planner
    run run_orchestrator agent-start planner
    [ "$status" -eq 0 ]

    # 4. Complete planner with output
    run run_orchestrator agent-complete planner '{"plan_id":"bp_001","task_id":"task_001"}'
    [ "$status" -eq 0 ]

    # 5. Save checkpoint
    run run_orchestrator checkpoint "planner_complete"
    [ "$status" -eq 0 ]

    # 6. Handoff to builder
    run run_orchestrator handoff planner builder '{"task_id":"task_001","plan_path":".studio/tasks/task_001/plan.json"}'
    [ "$status" -eq 0 ]

    # 7. Start builder
    run run_orchestrator agent-start builder
    [ "$status" -eq 0 ]

    # 8. Builder retrieves handoff
    handoff=$(run_orchestrator get-handoff builder)
    task_id=$(echo "$handoff" | jq -r '.task_id')
    [ "$task_id" = "task_001" ]

    # 9. Complete builder
    run run_orchestrator agent-complete builder '{"success":true}'
    [ "$status" -eq 0 ]

    # 10. Verify final state
    state=$(run_orchestrator state)
    planner_status=$(echo "$state" | jq -r '.routing.agent_sequence[] | select(.agent == "planner") | .status')
    builder_status=$(echo "$state" | jq -r '.routing.agent_sequence[] | select(.agent == "builder") | .status')

    [ "$planner_status" = "completed" ]
    [ "$builder_status" = "completed" ]
}

@test "workflow: build_only for simple fix" {
    # Initialize with a fix goal
    run_orchestrator init "Fix typo in readme" implicit >/dev/null

    # Route should return build_only (filter log lines to get JSON)
    routing=$(run_orchestrator route 2>/dev/null | grep -v '^\[Orchestrator\]')
    workflow=$(echo "$routing" | jq -r '.selected_workflow')
    [ "$workflow" = "build_only" ]

    # Agent sequence should only have builder
    agent_count=$(echo "$routing" | jq '.agent_sequence | length')
    [ "$agent_count" -eq 1 ]

    first_agent=$(echo "$routing" | jq -r '.agent_sequence[0].agent')
    [ "$first_agent" = "builder" ]
}

# =============================================================================
# FAILURE AND RECOVERY WORKFLOW
# =============================================================================

@test "recovery workflow: retry on first failure" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start builder >/dev/null

    # First failure
    run_orchestrator agent-fail builder "Compilation error" >/dev/null

    # Check recovery decision (filter log lines to get JSON)
    recovery=$(run_orchestrator recover builder 2>/dev/null | grep -v '^\[')
    action=$(echo "$recovery" | jq -r '.action')
    [ "$action" = "retry" ]
}

@test "recovery workflow: replan after multiple failures" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start builder >/dev/null

    # Three failures
    run_orchestrator agent-fail builder "Error 1" >/dev/null
    run_orchestrator agent-fail builder "Error 2" >/dev/null
    run_orchestrator agent-fail builder "Error 3" >/dev/null

    # Should suggest replan (filter log lines to get JSON)
    recovery=$(run_orchestrator recover builder 2>/dev/null | grep -v '^\[')
    action=$(echo "$recovery" | jq -r '.action')
    [ "$action" = "replan" ]
}

@test "recovery workflow: escalate after many failures" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start builder >/dev/null

    # Five failures
    for i in 1 2 3 4 5; do
        run_orchestrator agent-fail builder "Error $i" >/dev/null
    done

    # Should escalate (filter log lines to get JSON)
    recovery=$(run_orchestrator recover builder 2>/dev/null | grep -v '^\[')
    action=$(echo "$recovery" | jq -r '.action')
    [ "$action" = "escalate" ]
}

# =============================================================================
# CHECKPOINT AND RESUME WORKFLOW
# =============================================================================

@test "checkpoint workflow: save and verify" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start planner >/dev/null
    run_orchestrator agent-complete planner >/dev/null

    # Save checkpoint
    checkpoint_output=$(run_orchestrator checkpoint "after_planner")
    checkpoint_id=$(echo "$checkpoint_output" | grep -o 'cp_[0-9]*')

    # Verify checkpoint exists
    state=$(run_orchestrator state)
    checkpoint_count=$(echo "$state" | jq '.checkpoints | length')
    [ "$checkpoint_count" -eq 1 ]

    checkpoint_name=$(echo "$state" | jq -r '.checkpoints[0].name')
    [ "$checkpoint_name" = "after_planner" ]
}

@test "multiple checkpoints are preserved" {
    run_orchestrator init "Test" implicit >/dev/null

    # Create multiple checkpoints
    run_orchestrator checkpoint "checkpoint_1" >/dev/null
    run_orchestrator checkpoint "checkpoint_2" >/dev/null
    run_orchestrator checkpoint "checkpoint_3" >/dev/null

    state=$(run_orchestrator state)
    checkpoint_count=$(echo "$state" | jq '.checkpoints | length')
    [ "$checkpoint_count" -eq 3 ]
}

# =============================================================================
# CONTEXT BUDGET INTEGRATION
# =============================================================================

@test "context budget tracks orchestration working pool" {
    # Initialize orchestration
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start planner >/dev/null

    # Budget should be trackable
    run run_context_manager budget working
    [ "$status" -eq 0 ]
}

# =============================================================================
# SKILL INTEGRATION (if yq available)
# =============================================================================

@test "skills integrate with security goal" {
    skip_if_no_yq

    # Detect skills for auth goal
    run run_skills detect "Add user authentication with JWT"
    [ "$status" -eq 0 ]

    # Should find security skill with high score
    security_score=$(echo "$output" | jq '[.[] | select(.skill == "security")] | .[0].score // 0')
    [ "$security_score" -gt 0 ]

    # Should be able to inject
    run run_skills inject security
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Security Guidelines" ]]
}

@test "skills integrate with frontend goal" {
    skip_if_no_yq

    # Detect skills for UI goal
    run run_skills detect "Create React component with Tailwind CSS"
    [ "$status" -eq 0 ]

    # Should find frontend skill
    has_frontend=$(echo "$output" | jq '[.[] | select(.skill == "frontend")] | length')
    [ "$has_frontend" -gt 0 ]
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

@test "orchestrator handles missing session gracefully" {
    # No session initialized
    run run_orchestrator state
    [ "$status" -eq 1 ]
    [[ "$output" =~ "No active session" ]]
}

@test "orchestrator handles invalid JSON gracefully" {
    run_orchestrator init "Test" implicit >/dev/null

    # Invalid JSON should be handled
    run run_orchestrator handoff planner builder "not valid json"
    [ "$status" -eq 0 ]  # Should succeed with empty object fallback
}

# =============================================================================
# CLEANUP
# =============================================================================

@test "cleanup removes all session data" {
    # Create session with data
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start planner >/dev/null
    run_orchestrator checkpoint "test" >/dev/null

    session_id=$(cat "$STUDIO_DIR/orchestration/.current")

    # Cleanup
    run run_orchestrator cleanup
    [ "$status" -eq 0 ]

    # Verify removal
    [ ! -d "$STUDIO_DIR/orchestration/$session_id" ]
    [ ! -f "$STUDIO_DIR/orchestration/.current" ]
}
