#!/usr/bin/env bats
# Tests for scripts/skills.sh
# Note: Most tests require yq to be installed

load 'helpers/test_helper'

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

# =============================================================================
# BASIC TESTS (no yq required)
# =============================================================================

@test "skills help shows usage" {
    run run_skills help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "STUDIO Skills Manager" ]]
    [[ "$output" =~ "Usage:" ]]
}

@test "skills unknown command fails" {
    run run_skills unknown_command
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Unknown command" ]]
}

# =============================================================================
# SKILL DETECTION TESTS (require yq)
# =============================================================================

@test "skills detect finds security skill for auth goal" {
    skip_if_no_yq

    run run_skills detect "Add user authentication with JWT"
    [ "$status" -eq 0 ]

    # Should find security skill
    [[ "$output" =~ "security" ]]

    # Should return JSON array
    skill_count=$(echo "$output" | jq 'length')
    [ "$skill_count" -gt 0 ]
}

@test "skills detect finds frontend skill for UI goal" {
    skip_if_no_yq

    run run_skills detect "Create a new React component for the dashboard"
    [ "$status" -eq 0 ]

    # Should find frontend skill
    [[ "$output" =~ "frontend" ]]
}

@test "skills detect finds backend skill for API goal" {
    skip_if_no_yq

    run run_skills detect "Add new API endpoint for user management"
    [ "$status" -eq 0 ]

    # Should find backend skill
    [[ "$output" =~ "backend" ]]
}

@test "skills detect returns empty array for unmatched goal" {
    skip_if_no_yq

    run run_skills detect "xyzzy foobar bazqux"
    [ "$status" -eq 0 ]

    # Should return empty array
    [[ "$output" == "[]" ]]
}

@test "skills detect scores skills by priority" {
    skip_if_no_yq

    run run_skills detect "Add authentication"
    [ "$status" -eq 0 ]

    # Security skill has priority 90, should have higher score
    first_skill=$(echo "$output" | jq -r '.[0].skill')
    [ "$first_skill" = "security" ]
}

@test "skills detect fails without goal" {
    skip_if_no_yq

    run run_skills detect
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Usage:" ]]
}

# =============================================================================
# SKILL LOADING TESTS (require yq)
# =============================================================================

@test "skills load returns skill as JSON" {
    skip_if_no_yq

    run run_skills load security
    [ "$status" -eq 0 ]

    # Should be valid JSON
    echo "$output" | jq . >/dev/null

    # Should have expected fields
    name=$(echo "$output" | jq -r '.name')
    [ "$name" = "security" ]
}

@test "skills load fails for nonexistent skill" {
    skip_if_no_yq

    run run_skills load nonexistent_skill
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Skill not found" ]]
}

# =============================================================================
# SKILL INJECTION TESTS (require yq)
# =============================================================================

@test "skills inject returns injection content" {
    skip_if_no_yq

    run run_skills inject security
    [ "$status" -eq 0 ]

    # Should include skill name
    [[ "$output" =~ "Skill: security" ]]

    # Should include guidelines
    [[ "$output" =~ "Security Guidelines" ]]

    # Should include checklist
    [[ "$output" =~ "Verification Checklist" ]]
}

@test "skills inject-all combines multiple skills" {
    skip_if_no_yq

    run run_skills inject-all "security,backend"
    [ "$status" -eq 0 ]

    # Should include both skills
    [[ "$output" =~ "Active Skills: security,backend" ]]
    [[ "$output" =~ "Skill: security" ]]
    [[ "$output" =~ "Skill: backend" ]]
}

@test "skills inject fails for nonexistent skill" {
    skip_if_no_yq

    run run_skills inject nonexistent_skill
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Skill not found" ]]
}

# =============================================================================
# TEAM MEMBER TESTS (require yq)
# =============================================================================

@test "skills team returns team members" {
    skip_if_no_yq

    run run_skills team security
    [ "$status" -eq 0 ]

    # Should return JSON array
    count=$(echo "$output" | jq 'length')
    [ "$count" -gt 0 ]

    # Should have tier and member fields
    tier=$(echo "$output" | jq -r '.[0].tier')
    [[ "$tier" =~ ^tier[123]$ ]]
}

@test "skills team fails for nonexistent skill" {
    skip_if_no_yq

    run run_skills team nonexistent_skill
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Skill not found" ]]
}

# =============================================================================
# SKILL LIST TESTS (require yq)
# =============================================================================

@test "skills list shows all available skills" {
    skip_if_no_yq

    run run_skills list
    [ "$status" -eq 0 ]

    # Should return JSON array
    count=$(echo "$output" | jq 'length')
    [ "$count" -gt 0 ]

    # Should include known skills
    [[ "$output" =~ "security" ]]
    [[ "$output" =~ "frontend" ]]
    [[ "$output" =~ "backend" ]]
}

@test "skills list sorts by priority" {
    skip_if_no_yq

    run run_skills list
    [ "$status" -eq 0 ]

    # First skill should have highest priority
    first_priority=$(echo "$output" | jq '.[0].priority')
    second_priority=$(echo "$output" | jq '.[1].priority')

    [ "$first_priority" -ge "$second_priority" ]
}

# =============================================================================
# VALIDATION TESTS (require yq)
# =============================================================================

@test "skills validate passes for valid skills" {
    skip_if_no_yq

    run run_skills validate security
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Valid" ]]
}

@test "skills validate all checks all skills" {
    skip_if_no_yq

    run run_skills validate
    [ "$status" -eq 0 ]
    [[ "$output" =~ "All skills valid" ]]
}
