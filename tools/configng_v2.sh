#!/usr/bin/env bash
set -euo pipefail

# configng_v2 - Armbian Config V2 Entry Point

BIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 
PROJECT_ROOT="$(cd "${BIN_ROOT}/.." && pwd)"


_about_armbian_config(){
        cat <<EOF
Usage: armbian-config [help]
        help - this mesage
        show - show the projct varible
EOF
}


### START dev env
if [[ "${BIN_ROOT}" == */tools && -d "$PROJECT_ROOT/src" ]]; then

        TRACE=${TRACE:-foo} # any value will show a debug trace message
        # load trace module
        . "$PROJECT_ROOT"/src/core/initialize/trace.sh
        # Define directories to source files from
        allowed_directories=("initialize")

        # Loop through each directory
        for dir in "${allowed_directories[@]}"; do
                trace "Processing directory: $dir"
                # Source all shell files in this directory
                for init_file in "$PROJECT_ROOT/src/core/$dir"/*.sh; do
                        if [[ -f "$init_file" ]]; then
                        trace "Sourcing $(basename "$init_file")"
                        . "$init_file"
                        fi
                done
        done
        trace reset
        trace "Loading modules"


        init_vars
        if [[ ! -f "$OS_RELEASE" ]]; then
                # Display warning
                echo -e "Warning, failed to detect Armbian."
        fi

	case "${1:-}" in
		help|-h|--help)
			_about_armbian_config
			;;
                show)
                        init_vars show
                        ;;
                "")
                        _about_armbian_config
                ;;
		*)
			echo "Unknown command: $1"
			_about_validate_staged_modules
			exit 1
			;;

	esac

else 
        echo "Modules not found"

fi
### END dev env

### START main
if [[ (("${BIN_ROOT}" == */bin) || ("${BIN_ROOT}" == */sbin)) && -d "$PROJECT_ROOT/lib" ]]; then

        # Running in production environment
        . "$PROJECT_ROOT"/src/core/initialize/trace.sh


fi
### END main

# Common code for both environments goes here