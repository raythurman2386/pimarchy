#!/bin/bash
#
# Test for template infinite loop detection
#

set -e

# Mock log functions if they're not already defined
log_info() { echo "[INFO] $1"; }
log_success() { echo "[OK] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# Source the functions to test
# We need to set PIMARCHY_DIR so it can find things
export PIMARCHY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PIMARCHY_DIR/lib/functions.sh"

# Create a temporary directory for test files
TEST_TEMP=$(mktemp -d)
trap 'rm -rf "$TEST_TEMP"' EXIT

test_happy_path() {
    echo "Running test_happy_path..."
    local template="$TEST_TEMP/happy.template"
    local output="$TEST_TEMP/happy.out"

    echo "Hello {{NAME}}!" > "$template"
    export NAME="World"

    if process_template "$template" "$output"; then
        local result=$(cat "$output")
        if [ "$result" = "Hello World!" ]; then
            echo "  ✓ Happy path passed"
        else
            echo "  ✗ Happy path failed: expected 'Hello World!', got '$result'"
            return 1
        fi
    else
        echo "  ✗ Happy path failed: process_template returned non-zero"
        return 1
    fi
}

test_infinite_loop() {
    echo "Running test_infinite_loop..."
    local template="$TEST_TEMP/loop.template"
    local output="$TEST_TEMP/loop.out"

    # This will cause an infinite loop because {{LOOP_VAR}} will always be present
    echo "Loop: {{LOOP_VAR}}" > "$template"
    export LOOP_VAR="{{LOOP_VAR}}"

    if process_template "$template" "$output" 2>/dev/null; then
        echo "  ✗ Infinite loop test failed: process_template should have failed"
        return 1
    else
        echo "  ✓ Infinite loop detected correctly"
    fi
}

test_recursive_expansion() {
    echo "Running test_recursive_expansion..."
    local template="$TEST_TEMP/recursive.template"
    local output="$TEST_TEMP/recursive.out"

    # This is a deep but finite expansion
    echo "Value: {{VAR1}}" > "$template"
    export VAR1="{{VAR2}}"
    export VAR2="{{VAR3}}"
    export VAR3="FinalValue"

    if process_template "$template" "$output"; then
        local result=$(cat "$output")
        if [ "$result" = "Value: FinalValue" ]; then
            echo "  ✓ Recursive expansion passed"
        else
            echo "  ✗ Recursive expansion failed: expected 'Value: FinalValue', got '$result'"
            return 1
        fi
    else
        echo "  ✗ Recursive expansion failed: process_template returned non-zero"
        return 1
    fi
}

# Run tests
test_happy_path
test_infinite_loop
test_recursive_expansion

echo "All tests in $(basename "$0") passed!"
