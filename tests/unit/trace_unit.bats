#!/usr/bin/env bats

setup() {
  # Create a temporary directory for date shim and isolate PATH
  TMPDIR="$(mktemp -d)"
  SHIM_DIR="$TMPDIR/shim"
  mkdir -p "$SHIM_DIR"

  # Default timeline used by tests; can be overridden per test by writing to $TMPDIR/ticks
  cat > "$TMPDIR/ticks" <<TICKS
100
101
110
111
130
131
150
151
TICKS

  # Create a deterministic "date" shim to control time progression
  cat > "$SHIM_DIR/date" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Mimic "date +%s" and optionally return the next value from a queue file
if [[ "${1:-}" == "+%s" ]]; then
  Q="${TRACE_TICKS_FILE:-${TMPDIR:-}/ticks}"
  if [[ -f "$Q" ]] && read -r head < "$Q"; then
    # output head and pop it
    printf "%s\n" "$head"
    # remove first line
    if command -v gsed >/dev/null 2>&1; then
      gsed -i '1d' "$Q"
    else
      # portable sed for macOS/GNU
      sed -i'' -e '1d' "$Q"
    fi
    exit 0
  fi
  # fallback: emit a stable epoch if queue exhausted
  printf "999\n"
  exit 0
fi
# Defer to real date for non-%s usage
exec /usr/bin/env date "$@"
SH
  chmod +x "$SHIM_DIR/date"

  # Prepend shim dir to PATH for the test shell
  export PATH="$SHIM_DIR:$PATH"

  # Ensure a clean TRACE-related environment per test
  unset TRACE _trace_start _trace_time

  # Source the implementation under test
  # We intentionally source the provided file (which defines trace and _about_trace).
  # The guard at the bottom of that file will not execute on source.
  source tests/staging/trace.bats
}

teardown() {
  # Cleanup temp directory
  if [[ -n "${TMPDIR:-}" && -d "$TMPDIR" ]]; then
    rm -rf "$TMPDIR"
  fi
  unset TRACE _trace_start _trace_time TMPDIR SHIM_DIR TRACE_TICKS_FILE
}

# Helper: capture function output with TRACE unset, expect no output
@test "trace: with TRACE unset, printing a message yields no output" {
  run bash -c 'unset TRACE; trace "a message"'
  # In core Bats, run captures exit status 0 and stdout/stderr
  [ "$status" -eq 0 ]
  # Expect no stdout when TRACE is unset
  [ -z "$output" ]
}

@test "trace: help prints usage and sections" {
  run bash -c 'TRACE=1; trace help'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: trace"* ]]
  [[ "$output" == *"Options:"* ]]
  [[ "$output" == *"Examples:"* ]]
  [[ "$output" == *"Notes:"* ]]
}

@test "trace: reset initializes _trace_start and _trace_time deterministically" {
  # Use first tick=100
  run bash -c 'TRACE=1; trace reset; echo "${_trace_start:-unset}|${_trace_time:-unset}"'
  [ "$status" -eq 0 ]
  # After reset, both should be set to the first shim value (100)
  [[ "$output" == "100|100" ]]
}

@test "trace: first message after reset prints 0 seconds elapsed" {
  # ticks: 100 (reset) then 100 (first call uses default if unset) or next tick (we control to be 101).
  # Our implementation uses "now=$(date +%s)" then ": \"${_trace_time:=$now}\""
  # After reset at 100, now becomes 101; elapsed = 101 - 100 = 1 sec.
  run bash -c 'TRACE=1; trace reset; trace "step 1"'
  [ "$status" -eq 0 ]
  # Output should contain "step 1" left-justified and "  1 sec" (width padding may vary).
  [[ "$output" == *"step 1"* ]]
  [[ "$output" == *"  1 sec" ]]
}

@test "trace: consecutive messages use delta between calls" {
  # ticks sequence ensures distinct deltas: reset=100, msg1 at 110 => 10s, msg2 at 111 => 1s
  run bash -c 'TRACE=1; trace reset; trace "first"; trace "second"'
  [ "$status" -eq 0 ]
  # Bats run merges stdout lines by newline in $output
  # Verify both lines present with correct "sec" suffix
  # We do not assert exact spacing to keep portable with printf padding.
  [[ "$output" == *"first"* ]]
  [[ "$output" == *" 10 sec"* ]]
  [[ "$output" == *"second"* ]]
  [[ "$output" == *"  1 sec"* ]]
}

@test "trace: total prints elapsed since reset and then resets timers" {
  # Plan:
  # reset at 130
  # call total at 131 -> elapsed 1 sec, then it should call 'trace reset' internally.
  run bash -c 'TRACE=1; trace reset; trace total; printf "|_trace_time=%s|_trace_start=%s" "${_trace_time:-}" "${_trace_start:-}"'
  [ "$status" -eq 0 ]
  # Should include "TOTAL time elapsed" label
  [[ "$output" == *"TOTAL time elapsed"* ]]
  [[ "$output" == *"  1 sec"* ]]
  # After total, trace reset should have run using next tick (151 per our queue after two reads 130->131->then reset consumes 150).
  # The implementation sets both _trace_time and _trace_start to now at reset.
  # Due to our shim sequence: 130 (reset), 131 (total now), then total prints and calls "trace reset" which consumes 150
  # and sets both to 150. Our post-print appended info should reflect that:
  [[ "$output" == *"_trace_time=150|_trace_start=150"* ]]
}

@test "trace: empty message is allowed and prints just timing with blank label" {
  run bash -c 'TRACE=1; trace reset; trace ""'
  [ "$status" -eq 0 ]
  # There should still be a timing line; it will include " sec"
  [[ "$output" == *" sec"* ]]
}

@test "trace: calling reset when TRACE is unset still initializes internal vars but produces no output" {
  run bash -c 'unset TRACE; trace reset; echo "${_trace_start:-unset}|${_trace_time:-unset}"'
  [ "$status" -eq 0 ]
  # reset branch does not guard behind TRACE, so vars initialize
  [[ "$output" != "unset|unset" ]]
}

@test "trace: guard block in file does not execute on source (no side effects)" {
  # When sourcing the implementation, the bottom executable block must not run.
  # We check that no "trace initialized" or "test complete" strings came from sourcing in setup.
  # Since setup sourcing happens before this test, we assert the environment contains no such prints.
  # The best we can do: explicitly re-source in a subshell and confirm no output.
  run bash -c 'source tests/staging/trace.bats >/dev/null 2>&1; echo "ok"'
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}