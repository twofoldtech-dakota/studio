#!/usr/bin/env bats
# Tests for scripts/orchestrator.sh

load 'helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

@test "orchestrator init creates session" {
    run run_orchestrator init "Test goal" implicit
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Orchestration session initialized" ]]
    [[ "$output" =~ "orch_" ]]
}

@test "orchestrator init creates state file" {
    run run_orchestrator init "Test goal" implicit
    [ "$status" -eq 0 ]

    # Extract session ID from output
    session_id=$(echo "$output" | grep -o 'orch_[0-9_a-f]*' | head -1)
    assert_file_exists "$STUDIO_DIR/orchestration/$session_id/state.json"
}

@test "orchestrator init sets .current file" {
    run run_orchestrator init "Test goal" implicit
    [ "$status" -eq 0 ]

    assert_file_exists "$STUDIO_DIR/orchestration/.current"
    session_id=$(cat "$STUDIO_DIR/orchestration/.current")
    [[ "$session_id" =~ ^orch_ ]]
}

@test "orchestrator init stores goal in state" {
    run run_orchestrator init "Add user authentication" implicit
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    assert_json_field "$state" '.goal' "Add user authentication"
}

@test "orchestrator init sets mode correctly" {
    run run_orchestrator init "Test" explicit
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    assert_json_field "$state" '.mode' "explicit"
}

@test "orchestrator init without goal fails" {
    run run_orchestrator init
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

# =============================================================================
# ROUTING TESTS
# =============================================================================

@test "orchestrator route returns plan_then_build for 'add' goal" {
    run_orchestrator init "Add user authentication" implicit >/dev/null

    run run_orchestrator route
    [ "$status" -eq 0 ]
    [[ "$output" =~ "plan_then_build" ]]
}

@test "orchestrator route returns build_only for 'fix' goal" {
    run_orchestrator init "Fix typo in readme" implicit >/dev/null

    run run_orchestrator route
    [ "$status" -eq 0 ]
    [[ "$output" =~ "build_only" ]]
}

@test "orchestrator route returns plan_then_build for 'refactor' goal" {
    run_orchestrator init "Refactor authentication module" implicit >/dev/null

    run run_orchestrator route
    [ "$status" -eq 0 ]
    [[ "$output" =~ "plan_then_build" ]]
    [[ "$output" =~ "0.9" ]]  # Higher confidence for refactor
}

@test "orchestrator route sets agent sequence" {
    run_orchestrator init "Add feature" implicit >/dev/null
    run_orchestrator route >/dev/null

    state=$(run_orchestrator state)

    # Check planner is in sequence
    planner=$(echo "$state" | jq '.routing.agent_sequence[] | select(.agent == "planner")')
    [ -n "$planner" ]

    # Check builder is in sequence
    builder=$(echo "$state" | jq '.routing.agent_sequence[] | select(.agent == "builder")')
    [ -n "$builder" ]
}

# =============================================================================
# AGENT LIFECYCLE TESTS
# =============================================================================

@test "orchestrator agent-start marks agent as active" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator route >/dev/null

    run run_orchestrator agent-start planner
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    status_val=$(echo "$state" | jq -r '.routing.agent_sequence[] | select(.agent == "planner") | .status')
    [ "$status_val" = "active" ]
}

@test "orchestrator agent-start adds to agent_states" {
    run_orchestrator init "Test" implicit >/dev/null

    run run_orchestrator agent-start planner
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    agent_state=$(echo "$state" | jq '.agent_states[] | select(.agent_name == "planner")')
    [ -n "$agent_state" ]

    status_val=$(echo "$agent_state" | jq -r '.status')
    [ "$status_val" = "active" ]
}

@test "orchestrator agent-complete marks agent as completed" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator route >/dev/null
    run_orchestrator agent-start planner >/dev/null

    run run_orchestrator agent-complete planner
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    status_val=$(echo "$state" | jq -r '.routing.agent_sequence[] | select(.agent == "planner") | .status')
    [ "$status_val" = "completed" ]
}

@test "orchestrator agent-complete stores output" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start planner >/dev/null

    run run_orchestrator agent-complete planner '{"plan_id":"bp_001"}'
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    plan_id=$(echo "$state" | jq -r '.agent_states[] | select(.agent_name == "planner") | .output.plan_id')
    [ "$plan_id" = "bp_001" ]
}

@test "orchestrator agent-fail records failure" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start builder >/dev/null

    run run_orchestrator agent-fail builder "Test compilation error"
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    failure_count=$(echo "$state" | jq '.failures | length')
    [ "$failure_count" -eq 1 ]

    error_msg=$(echo "$state" | jq -r '.failures[0].error_message')
    [ "$error_msg" = "Test compilation error" ]
}

# =============================================================================
# HANDOFF TESTS
# =============================================================================

@test "orchestrator handoff records context" {
    run_orchestrator init "Test" implicit >/dev/null

    run run_orchestrator handoff planner builder '{"task_id":"task_001"}'
    [ "$status" -eq 0 ]

    state=$(run_orchestrator state)
    handoff_count=$(echo "$state" | jq '.handoffs | length')
    [ "$handoff_count" -eq 1 ]

    task_id=$(echo "$state" | jq -r '.handoffs[0].context_passed.task_id')
    [ "$task_id" = "task_001" ]
}

@test "orchestrator get-handoff retrieves context" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator handoff planner builder '{"task_id":"task_002","plan_path":"test.json"}' >/dev/null

    run run_orchestrator get-handoff builder
    [ "$status" -eq 0 ]

    task_id=$(echo "$output" | jq -r '.task_id')
    [ "$task_id" = "task_002" ]

    plan_path=$(echo "$output" | jq -r '.plan_path')
    [ "$plan_path" = "test.json" ]
}

@test "orchestrator get-handoff returns empty for no handoff" {
    run_orchestrator init "Test" implicit >/dev/null

    run run_orchestrator get-handoff builder
    [ "$status" -eq 0 ]
    [ "$output" = "{}" ]
}

# =============================================================================
# CHECKPOINT TESTS
# =============================================================================

@test "orchestrator checkpoint saves state" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start planner >/dev/null
    run_orchestrator agent-complete planner >/dev/null

    run run_orchestrator checkpoint "planner_complete"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "cp_" ]]

    state=$(run_orchestrator state)
    checkpoint_count=$(echo "$state" | jq '.checkpoints | length')
    [ "$checkpoint_count" -eq 1 ]
}

@test "orchestrator checkpoint creates checkpoint file" {
    run_orchestrator init "Test" implicit >/dev/null

    output=$(run_orchestrator checkpoint "test_checkpoint")
    checkpoint_id=$(echo "$output" | grep -o 'cp_[0-9]*' | head -1)

    session_id=$(cat "$STUDIO_DIR/orchestration/.current")
    assert_file_exists "$STUDIO_DIR/orchestration/$session_id/${checkpoint_id}.json"
}

# =============================================================================
# RECOVERY TESTS
# =============================================================================

@test "orchestrator recover returns retry for < 3 failures" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start builder >/dev/null
    run_orchestrator agent-fail builder "Error 1" >/dev/null

    run run_orchestrator recover builder
    [ "$status" -eq 0 ]

    # Extract JSON by filtering out log lines (lines starting with [)
    json_output=$(echo "$output" | grep -v '^\[')
    action=$(echo "$json_output" | jq -r '.action')
    [ "$action" = "retry" ]
}

@test "orchestrator recover returns replan for 3-4 failures" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start builder >/dev/null
    run_orchestrator agent-fail builder "Error 1" >/dev/null
    run_orchestrator agent-fail builder "Error 2" >/dev/null
    run_orchestrator agent-fail builder "Error 3" >/dev/null

    run run_orchestrator recover builder
    [ "$status" -eq 0 ]

    # Extract JSON by filtering out log lines (lines starting with [)
    json_output=$(echo "$output" | grep -v '^\[')
    action=$(echo "$json_output" | jq -r '.action')
    [ "$action" = "replan" ]
}

@test "orchestrator recover returns escalate for 5+ failures" {
    run_orchestrator init "Test" implicit >/dev/null
    run_orchestrator agent-start builder >/dev/null
    for i in 1 2 3 4 5; do
        run_orchestrator agent-fail builder "Error $i" >/dev/null
    done

    run run_orchestrator recover builder
    [ "$status" -eq 0 ]

    # Extract JSON by filtering out log lines (lines starting with [)
    json_output=$(echo "$output" | grep -v '^\[')
    action=$(echo "$json_output" | jq -r '.action')
    [ "$action" = "escalate" ]
}

# =============================================================================
# STATUS TESTS
# =============================================================================

@test "orchestrator status shows session info" {
    run_orchestrator init "Test goal for status" implicit >/dev/null

    run run_orchestrator status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ORCHESTRATION STATUS" ]]
    [[ "$output" =~ "Test goal for status" ]]
}

@test "orchestrator status shows no session when none active" {
    run run_orchestrator status
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No active orchestration session" ]]
}

# =============================================================================
# CLEANUP TESTS
# =============================================================================

@test "orchestrator cleanup removes session" {
    run_orchestrator init "Test" implicit >/dev/null
    session_id=$(cat "$STUDIO_DIR/orchestration/.current")

    run run_orchestrator cleanup
    [ "$status" -eq 0 ]

    [ ! -d "$STUDIO_DIR/orchestration/$session_id" ]
    [ ! -f "$STUDIO_DIR/orchestration/.current" ]
}
