# STUDIO Test Helper
# Common setup and teardown functions for bats tests

# Get the project root directory
export PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_DIRNAME}")" && pwd)"
export SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
export STUDIO_DIR="${PROJECT_ROOT}/.studio-test"

# Setup test environment
setup_test_env() {
    # Create isolated test directory
    export STUDIO_DIR="${PROJECT_ROOT}/.studio-test-$$"
    mkdir -p "$STUDIO_DIR"
    mkdir -p "$STUDIO_DIR/orchestration"
    mkdir -p "$STUDIO_DIR/tasks"
    mkdir -p "$STUDIO_DIR/.cache/summaries"
}

# Teardown test environment
teardown_test_env() {
    if [[ -d "$STUDIO_DIR" && "$STUDIO_DIR" == *".studio-test-"* ]]; then
        rm -rf "$STUDIO_DIR"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Skip test if yq is not installed
skip_if_no_yq() {
    if ! command_exists yq; then
        skip "yq not installed"
    fi
}

# Assert JSON field equals value
assert_json_field() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local actual
    actual=$(echo "$json" | jq -r "$field")
    if [[ "$actual" != "$expected" ]]; then
        echo "Expected $field to be '$expected', got '$actual'"
        return 1
    fi
}

# Assert JSON field exists
assert_json_has_field() {
    local json="$1"
    local field="$2"
    local value
    value=$(echo "$json" | jq -r "$field // \"__MISSING__\"")
    if [[ "$value" == "__MISSING__" ]]; then
        echo "Expected field $field to exist"
        return 1
    fi
}

# Assert file exists
assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file"
        return 1
    fi
}

# Assert directory exists
assert_dir_exists() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "Expected directory to exist: $dir"
        return 1
    fi
}

# Run orchestrator command with test environment
run_orchestrator() {
    STUDIO_DIR="$STUDIO_DIR" "$SCRIPTS_DIR/orchestrator.sh" "$@"
}

# Run context-manager command with test environment
run_context_manager() {
    STUDIO_DIR="$STUDIO_DIR" "$SCRIPTS_DIR/context-manager.sh" "$@"
}

# Run skills command
run_skills() {
    "$SCRIPTS_DIR/skills.sh" "$@"
}
