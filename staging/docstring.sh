#!/usr/bin/env bash
set -euo pipefail

# ./docstring.sh - Armbian Config V2 module

docstring() {
	case "${1:-}" in
		help|-h|--help)
			_about_docstring
			;;
		"")
			_docstring_main
			;;
		*)
			echo "Unknown command: ${1}"
			_about_docstring
			return 1
	esac
}

_docstring_main() {
	# TODO: implement module logic
	echo "docstring - Armbian Config V2 test"
	echo "Scaffold test"
}

_about_docstring() {
	cat <<EOF
Usage: docstring <command> [options]

Commands:
	foo         - Example 'foo' operation (replace with real command)
	bar         - Example 'bar' operation (replace with real command)
	help        - Show this help message

Examples:
	# Run the test operation
	docstring test

	# Perform the foo operation with an argument
	docstring foo arg1

	# Show help
	docstring help

Notes:
	- Replace 'foo' and 'bar' with real commands for your module.
	- All commands should accept '--help', '-h', or 'help' for details, if implemented.
	- Intended for use with the config-v2 menu and scripting.
	- Keep this help message up to date if commands change.

EOF
}

### START ./docstring.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(docstring help)"
	echo "$help_output" | grep -q "Usage: docstring" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	docstring "$@"
fi

### END ./docstring.sh - Armbian Config V2 test entrypoint

