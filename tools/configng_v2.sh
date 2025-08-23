#!/usr/bin/env bash
set -euo pipefail

# configng_v2 - Armbian Config V2 Entry Point

BIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 
PROJECT_ROOT="$(cd "${BIN_ROOT}/.." && pwd)"

source "$PROJECT_ROOT"/src/core/initialize/init_vars.sh
# Set the default dialog box whiptail or dialog
# You can override this by setting the DIALOG environment variable
init_vars show

