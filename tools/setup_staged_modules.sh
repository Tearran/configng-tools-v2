#!/usr/bin/env bash
set -euo pipefail

# ./setup_staged_modules.sh - Armbian Config V2 module

setup_staged_modules() {
	case "${1:-}" in
		help|-h|--help)
			_about_setup_staged_modules
			;;
		*)
			_setup_staged_modules_main "$@"
			;;

	esac
}

_setup_staged_modules_main() {
	local STAGING_DIR="${STAGING_DIR:-./staging}"
	local MODULE="${1:-}"

	# Validate module name
	if [[ -z "$MODULE" ]]; then
		echo "No argument provided"
		_about_setup_staged_modules
		return 1
	fi
	if ! [[ "$MODULE" =~ ^[a-zA-Z0-9_]+$ ]]; then
		echo "Invalid module name: $MODULE"
		exit 1
	fi

	# Ensure ./staging exists
	if [[ ! -d "$STAGING_DIR" ]]; then
		mkdir -p "$STAGING_DIR"
	fi

	local created=0
	local skipped=0

	# .conf
	local conf="${STAGING_DIR}/${MODULE}.conf"
	if [[ -f "$conf" ]]; then
		echo "Skip: $conf already exists"
		skipped=$((skipped+1))
	else
		_template_conf "$MODULE" > "$conf"
		echo "Created: $conf"
		created=$((created+1))
	fi

	# .sh
	local modsh="${STAGING_DIR}/${MODULE}.sh"
	if [[ -f "$modsh" ]]; then
		echo "Skip: $modsh already exists"
		skipped=$((skipped+1))
	else
		_template_sh "$MODULE" > "$modsh"
		echo "Created: $modsh"
		created=$((created+1))
	fi

	# .md is deprecated; call deprecating_md manually if needed.

	echo -e "Staging: Complete\nScaffold for ${MODULE} can be found at ${STAGING_DIR}/."
	echo "Created: $created, Skipped: $skipped"
}


_template_conf() {
	local MODULE="$1"
	cat <<-EOF
		# ${MODULE} - Configng V2 metadata

		[${MODULE}]
		# Main feature provided by this module (usually the same as the module name).
		feature=${MODULE}

		# Short, single-line summary describing what this module does.
		description=

		# Longer description with more details about the module's features or usage.
		extend_desc=

		# Comma-separated list of commands supported by this module (e.g., help,status,reload).
		options=

		# Main category this module belongs to. Must be one of: network, system, software, locales, development.
		parent=

		# Group or tag for this module. See docs/readme.md (group index) for options.
		# If none fit, suggest a new group in your pull request.
		group=

		# Contributor's GitHub username (use @username).
		contributor=

		# Comma-separated list of supported CPU architectures.
		arch=

		# Comma-separated list of supported operating systems.
		require_os=

		# What kernel are you using? (minimum required version, e.g., 5.15+)
		require_kernel=

		# Comma-separated list of network ports used by this module (e.g., 8080,8443). Use 'false' if not applicable.
		port=false

		# Comma-separated list of functions in this module (all functions except the main feature).
		# NOTE: You must include the help message function _about_${MODULE}; validation will fail if it is missing.
		helpers=

		# List each command and its description below.
		# Example:
		# show=Display the current configuration
		[options]
		help=Show help for this module

EOF
}

_template_sh() {
	local MODULE="$1"
	cat <<EOH
#!/usr/bin/env bash
set -euo pipefail

# ./${MODULE}.sh - Armbian Config V2 module

${MODULE}() {
	case "\${1:-}" in
		help|-h|--help)
			_about_${MODULE}
			;;
		"")
			_${MODULE}_main
			;;
		*)
			echo "Unknown command: \${1}"
			_about_${MODULE}
			return 1
	esac
}

_${MODULE}_main() {
	# TODO: implement module logic
	echo "${MODULE} - Armbian Config V2 test"
	echo "Scaffold test"
}

_about_${MODULE}() {
	cat <<EOF
Usage: ${MODULE} <command> [options]

Commands:
	foo         - Example 'foo' operation (replace with real command)
	bar         - Example 'bar' operation (replace with real command)
	help        - Show this help message

Examples:
	# Run the test operation
	${MODULE} test

	# Perform the foo operation with an argument
	${MODULE} foo arg1

	# Show help
	${MODULE} help

Notes:
	- Replace 'foo' and 'bar' with real commands for your module.
	- All commands should accept '--help', '-h', or 'help' for details, if implemented.
	- Intended for use with the config-v2 menu and scripting.
	- Keep this help message up to date if commands change.

EOF
}

### START ./${MODULE}.sh - Armbian Config V2 test entrypoint

if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="\$(${MODULE} help)"
	echo "\$help_output" | grep -q "Usage: ${MODULE}" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	${MODULE} "\$@"
fi

### END ./${MODULE}.sh - Armbian Config V2 test entrypoint

EOH
}

_about_setup_staged_modules() {
	cat <<EOF
Usage: setup_staged_modules <module-name> [options]

Commands:
	help, -h, --help    Show this help message
	<module-name>       Create a scaffold for the specified module. The scaffold
			includes a .conf and a .sh file written to STAGING_DIR
			(default: ./staging).

Examples:
	# Create a scaffold for a module named "testmod"
	setup_staged_modules testmod

	# Create a scaffold using a different staging directory
	STAGING_DIR=./my_staging setup_staged_modules testmod

	# Show help
	setup_staged_modules help

Notes:
	- Module names must contain only letters, numbers, or underscores (A-Za-z0-9_).
	- The script creates <module>.conf and <module>.sh in STAGING_DIR (default: ./staging).
	- Review and update generated files before committing them to the repository.
	- All commands should accept '--help', '-h', or 'help' where implemented.
	- Intended for use with the config-v2 menu and scripting.
	- Keep this help message up to date if the script's behavior or commands change.

EOF

}

### START ./setup_staged_modules.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(setup_staged_modules help)"
	echo "$help_output" | grep -q "Usage: setup_staged_modules" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	setup_staged_modules "$@"
fi

### END ./setup_staged_modules.sh - Armbian Config V2 test entrypoint

