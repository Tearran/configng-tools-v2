#!/usr/bin/env bash
set -euo pipefail

# simple_server.sh - Armbian Config V2 module (lightweight static server)

simple_server() {
	# Directory of this script (not assuming a bin/ directory exists)
	local SCRIPT_DIR
	SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
	# Project root = parent of script dir (adjust if you prefer SCRIPT_DIR itself)
	local PROJECT_ROOT
	if [[ -d "${SCRIPT_DIR}/../.git" ]]; then
		PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
	elif  [[ -d "${SCRIPT_DIR}/../../.git" ]];then
		PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
	fi

	case "${1:-}" in
		help|-h|--help)
			_about_simple_server
			;;
		"")
			_simple_server_main "${PROJECT_ROOT}/public_html" || _simple_server_main "${PROJECT_ROOT}/docs"
			;;
		*)
			echo "Unknown command: ${1}" >&2
			echo
			_about_simple_server >&2
			return 1
			;;
	esac
}

_simple_server_main() {
	# Positional overrides (optional):
	# $1 = root dir (defaults to arg passed from dispatcher or PROJECT_ROOT/public_html)
	# $2 = port (defaults to $WEB_PORT or 8080)
	local provided_root="${1:-}"
	local port="${2:-${WEB_PORT:-8080}}"

	# Fall back if caller passed empty
	local root
	if [[ -n "$provided_root" ]]; then
		root="$provided_root"
	else
		# If PROJECT_ROOT was exported by caller we can use it; else use script dir
		root="${PROJECT_ROOT:-$(pwd)}"
	fi

	if [[ ! -d "$root" ]]; then
		echo "Root directory does not exist: $root" >&2
		return 2
	fi

	if ! command -v python3 >/dev/null 2>&1; then
		echo "Python 3 is required to run the server. Please install it." >&2
		return 3
	fi

	cd -- "$root"

	# Detect CI: skip actually starting server
	if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${TRAVIS:-}" || -n "${JENKINS_URL:-}" || -n "${CIRCLECI:-}" ]]; then
		echo "CI environment detected - skipping http.server (root: $root)"
		return 0
	fi

	echo "Starting Python web server in: $(pwd)"
	echo "Port: ${port}"
	#python3 -m http.server "${port}" --bind 127.0.0.1 --cgi &
 	#python3 -m http.server 8080 --cgi &
	# Pick first non-localhost IP
	BIND_IP=$(hostname -I | awk '{print $1}')
	python3 -m http.server 8080 --cgi --bind "$BIND_IP" &

	local PYTHON_PID=$!
	echo "Python web server started with PID ${PYTHON_PID}"
	echo "URL: http://localhost:${port}/"
	echo "Press any key to stop the server..."
	trap 'echo; echo "Stopping the server..."; kill "${PYTHON_PID}" >/dev/null 2>&1 || true; wait "${PYTHON_PID}" 2>/dev/null || true; trap - INT TERM EXIT' INT TERM EXIT

	# Wait single key
	read -r -n 1 -s || true

	echo
	echo "Stopping the server..."
	kill "${PYTHON_PID}" >/dev/null 2>&1 || true
	wait "${PYTHON_PID}" 2>/dev/null || true
	trap - INT TERM EXIT
	echo "Server stopped."
}

_about_simple_server() {
	cat <<'EOF'
Usage: simple_server <command> [options]
Commands:
	serve        Start a simple static HTTP server (default if no command given)
	help         Show this help message

Examples:
	simple_server
	WEB_PORT=5000 simple_server

Notes:
	- Press any key to stop the running server.
	- Uses python3 -m http.server bound to 127.0.0.1.
EOF
}

### Self-test & entrypoint
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# Basic help check
	if ! simple_server help | grep -q "Usage:"; then
		echo "fail: Help output does not contain expected usage string" >&2
		echo "test complete"
		exit 1
	fi
	simple_server "$@"
fi