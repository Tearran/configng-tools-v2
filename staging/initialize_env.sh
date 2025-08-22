#!/usr/bin/env bash
set -euo pipefail

# ./initialize_env.sh - Armbian Config V2 module
# Public entry: initialize_env
# Purpose: detect and expose environment variables used by other config-v2 modules.

initialize_env() {
	case "${1:-}" in
		help|-h|--help)
			_about_initialize_env
			;;
		show|-s)
			_initialize_env_vars
			_initialize_env_show
			;;
		export|-e)
+			_initialize_env_export
+			;;
		*)
			_initialize_env_vars
			;;
	esac
}

_initialize_env_vars() {

	# OS-defined files (declared values)
	OS_RELEASE="/etc/armbian-release"
	OS_INFO="/etc/os-release"

	# Source them if readable (non-fatal here; tests assert presence)
	# shellcheck disable=SC1091
	[[ -r "$OS_INFO" ]] && source "$OS_INFO" || true
	# shellcheck disable=SC1091
	[[ -r "$OS_RELEASE" ]] && source "$OS_RELEASE" || true

	# Config NG defined paths (defaults relative to this script)
	BIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	LIB_ROOT="${LIB_ROOT:-$BIN_ROOT/../LIB}"
	WEB_ROOT="${WEB_ROOT:-$BIN_ROOT/../html}"
	DOC_ROOT="${DOC_ROOT:-$BIN_ROOT/../doc}"
	SHARE_ROOT="${SHARE_ROOT:-$BIN_ROOT/../share}"

	# TUI variables (may be overridden by caller)
	BACKTITLE="${BACKTITLE:-"Contribute: https://github.com/armbian/configng"}"
	TITLE="${TITLE:-"${VENDOR:-Armbian} configuration utility"}"

	# Legacy / runtime variables (require OS info)
	DISTRO=${ID:-Unknown}
	DISTROID=${VERSION_CODENAME:-Unknown}
	KERNELID="$(uname -r)"

	# Detect default IPv4 adapter (best-effort)
	DEFAULT_ADAPTER=$(
		ip -4 route ls 2>/dev/null | awk '/default/ {
			for (i=1;i<=NF;i++) if ($i == "dev") print $(i+1)
			exit
		}' || true
	)

	# Get IPv4 address for the adapter (if present)
	if [[ -n "${DEFAULT_ADAPTER:-}" ]]; then
		LOCALIPADD=$(
			ip -4 addr show dev "${DEFAULT_ADAPTER}" 2>/dev/null |
			awk '/inet/ {print $2; exit}' | cut -d'/' -f1 || true
		)
	else
		LOCALIPADD=""
	fi

	# Derive local subnet (best-effort)
	if [[ -n "${LOCALIPADD:-}" ]]; then
		LOCALSUBNET="$(echo "${LOCALIPADD}" | cut -d"." -f1-3).0/24"
	else
		LOCALSUBNET=""
	fi

	# Export variables so callers that source this file (or eval exports) see them.
	# Exporting here makes the vars available to child processes and subshells.
	export BIN_ROOT LIB_ROOT WEB_ROOT DOC_ROOT SHARE_ROOT
	export BACKTITLE TITLE DISTRO DISTROID KERNELID
	export DEFAULT_ADAPTER LOCALIPADD LOCALSUBNET
	export OS_INFO OS_RELEASE
}

# Emits export lines suitable for: eval "$(initialize_env export)"
_initialize_env_export() {
	_initialize_env_vars
	local vars=(
		BIN_ROOT LIB_ROOT WEB_ROOT DOC_ROOT SHARE_ROOT
		BACKTITLE TITLE DISTRO DISTROID KERNELID
		DEFAULT_ADAPTER LOCALIPADD LOCALSUBNET
		OS_INFO OS_RELEASE
	)
	for v in "${vars[@]}"; do
		# Use indirect expansion to fetch each value; %q for shell-safe quoting
		printf 'export %s=%q\n' "$v" "${!v-}"
	done
}

_initialize_env_show() {
	# Make sure variables are initialized first
	_initialize_env_vars

	# Print header
	echo "=== Environment Variables ==="

	# Path variables
	echo -e "\n[Paths]"
	echo "BIN_ROOT     : $BIN_ROOT"
	echo "LIB_ROOT     : $LIB_ROOT"
	echo "WEB_ROOT     : $WEB_ROOT"
	echo "DOC_ROOT     : $DOC_ROOT"
	echo "SHARE_ROOT   : $SHARE_ROOT"

	# System information
	echo -e "\n[System]"
	echo "DISTRO       : $DISTRO"
	echo "DISTROID     : $DISTROID"
	echo "KERNELID     : $KERNELID"

	# TUI information
	echo -e "\n[UI]"
	echo "BACKTITLE    : $BACKTITLE"
	echo "TITLE        : $TITLE"

	# Network information
	echo -e "\n[Network]"
	echo "DEFAULT_ADAPTER : $DEFAULT_ADAPTER"
	echo "LOCALIPADD      : $LOCALIPADD"
	echo "LOCALSUBNET     : $LOCALSUBNET"

	# OS files
	echo -e "\n[OS Files]"
	echo "OS_RELEASE   : $OS_RELEASE"
	echo "OS_INFO      : $OS_INFO"

	# OS Release file contents
	echo -e "\n=== OS Release File Contents ==="
	if [[ -r "$OS_RELEASE" ]]; then
		echo -e "\n[Armbian Release File: $OS_RELEASE]"
		cat "$OS_RELEASE"
	else
		echo "Armbian release file not found or not readable: $OS_RELEASE"
	fi

	# OS Info file contents
	echo -e "\n=== OS Info File Contents ==="
	if [[ -r "$OS_INFO" ]]; then
		echo -e "\n[OS Info File: $OS_INFO]"
		cat "$OS_INFO"
	else
		echo "OS info file not found or not readable: $OS_INFO"
	fi
}


_about_initialize_env() {
	cat <<"EOF"
Usage: initialize_env [help|-h|--help]

About:
	The 'initialize_env' module provides environment detection utilities.

Commands:
	help    - Show this help message.

Notes:
	- To set variables in the current shell: source this file and call _initialize_env_vars
	- When executed, this file's test entrypoint verifies the environment and prints variables.
EOF
}


### START ./initialize_env.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(initialize_env help)"
	echo "$help_output" | grep -q "Usage: initialize_env" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	initialize_env "$@"
fi

### END ./initialize_env.sh - Armbian Config V2 test entrypoint
