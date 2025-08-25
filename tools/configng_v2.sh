#!/usr/bin/env bash
set -euo pipefail

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
### DEV-BLOCK START (remove for production)
if [[ "$SCRIPT_DIR" == */tools ]]; then
        # Development environment logic
        if [[ -f "$PROJECT_ROOT/src/core/initialize/trace.sh" ]]; then
                . "$PROJECT_ROOT/src/core/initialize/trace.sh"
                TRACE=y
                trace reset
        fi
        # Load initialize scripts
        shopt -s nullglob
        for f in "$PROJECT_ROOT/src/core/initialize"/*.sh; do

                [[ -f "$f" ]] && source "$f" ; trace "$f";
        done

        # Initialize vars if function exists
        if declare -f init_vars >/dev/null 2>&1; then
                eval "$(init_vars show 2>/dev/null || true)"
        fi

        if [[ ! -f "${OS_RELEASE:-/etc/os-release}" ]]; then
                echo "Warning: failed to detect Armbian (os-release file missing: ${OS_RELEASE:-/etc/os-release})."
        fi

        case "${1:-}" in
                help|-h|--help|"")
                        cat <<EOF
Usage: armbian-config <command>

Commands:
        help    - Show this help message
        start   - Generate a scaffold script and metadata
        valid   - Validate metadata and module scripts for promotion  
        promote - After validation, move modules to the production src/ folder 

examples
        armbian-config start <string>
        armbian-config valid
        armbian-config promote

EOF
                        ;;
                web)
                        shift
                        "$BIN_ROOT/release/web_kit.sh"
                        ;;
                start)  
                        shift 
                        "$BIN_ROOT"/staging/setup_staged_modules.sh "$@"
                        ;;
                valid)
                        shift
                        "$BIN_ROOT"/staging/validate_staged_modules.sh "$@"
                        ;;
                promote)
                        shift
                        "$BIN_ROOT"/staging/promote_staged_module.sh "$@"
                        ;;
                *)
                        
                        trace "Run <${1:-} ${2:-}>"
                        eval "$@"
                        ;;
        esac
trace total
fi
### DEV-BLOCK END


# Production loader triggers ONLY when script resides in bin/ or sbin/.
### START main
if [[ "$SCRIPT_DIR" == */bin || "$SCRIPT_DIR" == */sbin ]]; then
        if [[ -d "$PROJECT_ROOT/lib/armbian-config/" ]]; then
                . "$PROJECT_ROOT/lib/armbian-config/core.sh"
        else
                echo "Error: Library not found $PROJECT_ROOT/lib/armbian-config/" >&2
                exit 1
        fi

       case "${1:-}" in
                help|-h|--help|"")
                        cat <<EOF
Usage: armbian-config <command>

Commands:
        help    - Show this help message

examples
        armbian-config <string>

EOF
                        ;;               
                *)
                        "$@"
                        ;;
        esac
fi

### END main
