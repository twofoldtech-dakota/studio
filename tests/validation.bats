#!/usr/bin/env bats
# Validation tests for STUDIO configuration files

load 'helpers/test_helper'

# =============================================================================
# HOOKS.JSON VALIDATION
# =============================================================================

@test "hooks.json is valid JSON" {
    run jq . "$PROJECT_ROOT/hooks/hooks.json"
    [ "$status" -eq 0 ]
}

@test "hooks.json has required structure" {
    hooks=$(cat "$PROJECT_ROOT/hooks/hooks.json")

    # Should have hooks object
    assert_json_has_field "$hooks" '.hooks'

    # Should have key hook types
    assert_json_has_field "$hooks" '.hooks.SessionStart'
    assert_json_has_field "$hooks" '.hooks.SubagentStart'
    assert_json_has_field "$hooks" '.hooks.SubagentStop'
}

@test "hooks.json PreCommand has build hook" {
    hooks=$(cat "$PROJECT_ROOT/hooks/hooks.json")
    build_hook=$(echo "$hooks" | jq '.hooks.PreCommand[] | select(.matcher == "build")')
    [ -n "$build_hook" ]
}

@test "hooks.json SessionStart has orchestration check" {
    hooks=$(cat "$PROJECT_ROOT/hooks/hooks.json")
    session_hooks=$(echo "$hooks" | jq '.hooks.SessionStart[0].hooks')
    [ -n "$session_hooks" ]

    # Should mention orchestration
    [[ "$session_hooks" =~ "orchestration" ]]
}

@test "hooks.json SubagentStart mentions skills" {
    hooks=$(cat "$PROJECT_ROOT/hooks/hooks.json")
    subagent_hooks=$(echo "$hooks" | jq -r '.hooks.SubagentStart[0].hooks[0].prompt')

    # Should mention skill detection
    [[ "$subagent_hooks" =~ "skills.sh" ]]
}

# =============================================================================
# SCHEMA VALIDATION
# =============================================================================

@test "skill.schema.json is valid JSON Schema" {
    run jq . "$PROJECT_ROOT/schemas/skill.schema.json"
    [ "$status" -eq 0 ]

    schema=$(cat "$PROJECT_ROOT/schemas/skill.schema.json")
    assert_json_has_field "$schema" '."$schema"'
    assert_json_has_field "$schema" '.properties'
}

@test "orchestration-state.schema.json is valid JSON Schema" {
    run jq . "$PROJECT_ROOT/schemas/orchestration-state.schema.json"
    [ "$status" -eq 0 ]

    schema=$(cat "$PROJECT_ROOT/schemas/orchestration-state.schema.json")
    assert_json_has_field "$schema" '."$schema"'
    assert_json_has_field "$schema" '.properties'
}

@test "plan.schema.json is valid JSON Schema" {
    run jq . "$PROJECT_ROOT/schemas/plan.schema.json"
    [ "$status" -eq 0 ]
}

# =============================================================================
# SKILL YAML VALIDATION
# =============================================================================

@test "all skill files exist" {
    expected_skills="security frontend backend testing performance devops accessibility data"
    for skill in $expected_skills; do
        assert_file_exists "$PROJECT_ROOT/skills/${skill}.yaml"
    done
}

@test "skill YAMLs have required fields (if yq available)" {
    skip_if_no_yq

    for skill_file in "$PROJECT_ROOT"/skills/*.yaml; do
        name=$(yq -r '.name // ""' "$skill_file")
        description=$(yq -r '.description // ""' "$skill_file")

        [ -n "$name" ] || { echo "Missing name in $skill_file"; return 1; }
        [ -n "$description" ] || { echo "Missing description in $skill_file"; return 1; }
    done
}

# =============================================================================
# SCRIPT VALIDATION
# =============================================================================

@test "orchestrator.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/orchestrator.sh" ]
}

@test "context-manager.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/context-manager.sh" ]
}

@test "skills.sh is executable" {
    [ -x "$PROJECT_ROOT/scripts/skills.sh" ]
}

@test "orchestrator.sh has valid bash syntax" {
    run bash -n "$PROJECT_ROOT/scripts/orchestrator.sh"
    [ "$status" -eq 0 ]
}

@test "context-manager.sh has valid bash syntax" {
    run bash -n "$PROJECT_ROOT/scripts/context-manager.sh"
    [ "$status" -eq 0 ]
}

@test "skills.sh has valid bash syntax" {
    run bash -n "$PROJECT_ROOT/scripts/skills.sh"
    [ "$status" -eq 0 ]
}

# =============================================================================
# AGENT YAML VALIDATION
# =============================================================================

@test "agent YAML files exist" {
    assert_file_exists "$PROJECT_ROOT/agents/builder.yaml"
    assert_file_exists "$PROJECT_ROOT/agents/planner.yaml"
    assert_file_exists "$PROJECT_ROOT/agents/orchestrator.yaml"
}

# =============================================================================
# COMMAND DOCUMENTATION VALIDATION
# =============================================================================

@test "build command documentation exists" {
    assert_file_exists "$PROJECT_ROOT/commands/build.md"
}

@test "build.md documents orchestration" {
    content=$(cat "$PROJECT_ROOT/commands/build.md")
    [[ "$content" =~ "Orchestration" ]]
    [[ "$content" =~ "orchestrator.sh" ]]
}
