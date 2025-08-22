#!/usr/bin/env bash
set -euo pipefail

# src/core/initialize/trace.sh

trace() {
	local cmd="${1:-}" msg="${2:-}"
	case "$cmd" in
		help)
			_about_trace
			;;
		reset)
			_trace_start=$(date +%s)
			_trace_time=$_trace_start
			;;
		total)
			if [[ -n "${TRACE:-}" ]]; then
				_trace_time=${_trace_start:-$(date +%s)}
				trace "TOTAL time elapsed"
			fi
			trace reset
			;;
		*)
			if [[ -n "${TRACE:-}" ]]; then
				local now elapsed
				now=$(date +%s)
				: "${_trace_time:=$now}"  # Initialize if unset
				elapsed=$((now - _trace_time))
				printf "%-30s %4d sec\n" "$cmd" "$elapsed"
				_trace_time=$now
			fi
			;;
	esac
}

_about_trace() {
	cat <<EOF
Usage: trace <option> | <"message string">

Options:
	help	- Show this help message
	<string>	- Show trace message (if TRACE is set)
	reset	- (Re)set starting point for timing
	total	- Show total time since reset, then reset

Examples:
	# Start a new timing session
	trace reset

	# Print elapsed time with a message
	trace "Step 1 complete"

	# Show total elapsed time and reset
	trace total

Notes:
	- When TRACE is set (e.g., TRACE="true"), trace outputs timing info.
	- Elapsed time is shown since last trace call.
	- Intended for use in config-ng modules and scripting.
	- Keep this help message in sync with available options.

For more info, see this file or related README in ./lib/.
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	TRACE="true"
	trace reset
	trace "trace initialized"

	# --- Capture and assert help output ---
	help_output="$(trace help)"
	echo "$help_output" | grep -q "Usage: trace" || {
		echo "fail: Help output does not contain expected usage string"
		trace "test complete"
		exit 1
	}
	# --- end assertion ---

	trace "$help_output"
	trace "test complete"
	trace total
fi
