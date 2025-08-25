#!/usr/bin/env bash
set -euo pipefail

# ./promote_staged_module.sh - Armbian Config V2 module
# When a module's parent=development it is promoted to /src/development[/<group>].
# For other parents the module is promoted to ./src/<parent>[/<group>].
# Default behavior no longer uses DEVELOPMENT_DEST.
promote_staged_module() {
	case "${1:-}" in
		help|-h|--help)
			_about_promote_staged_module
			;;
		*)
			_promote_staged_module_main
			;;
	esac
}

_promote_staged_module_main() {
	shopt -s nullglob
	for sh_file in ./staging/*.sh; do
		[[ -f "$sh_file" ]] || continue
		base_name="$(basename "$sh_file" .sh)"
		conf_file="./staging/${base_name}.conf"

		if [[ -f "$conf_file" ]]; then
			parent="$(grep -Em1 '^parent=' "$conf_file" | cut -d= -f2- | xargs || true)"
			group="$(grep -Em1 '^group=' "$conf_file" | cut -d= -f2- | xargs || true)"

			# quick presence/format checks (feature/helpers/description/parent at minimum)
			if ! grep -Eqm1 '^feature=' "$conf_file" \
				|| ! grep -Eqm1 '^helpers=' "$conf_file" \
				|| ! grep -Eqm1 '^description=' "$conf_file" \
				|| ! grep -Eqm1 '^parent=' "$conf_file"; then
				echo "ERROR: $conf_file missing one or more required fields (feature/helpers/description/parent). Aborting."
				exit 1
			fi

			# If parent=development, promote to /src/development[/<group>].
			# Otherwise promote to ./src/<parent>[/<group>]
			if [[ "$parent" == "development" ]]; then
				if [[ -n "$group" ]]; then
					dest_dir="./tools/${group}"
				else
					echo "INFO: parent=development and no group specified; promoting to /src/development"
					dest_dir="./tools/misc"
				fi
			else
				if [[ -n "$group" ]]; then
					dest_dir="./src/${parent}/${group}"
				else
					dest_dir="./src/${parent}/failed"
				fi
			fi

			# Ensure destination exists
			mkdir -p "$dest_dir"

			# Fail if any destination file exists to avoid accidental overwrite
			for f in "$sh_file" "$conf_file"; do
				t="$dest_dir/$(basename "$f")"
				if [[ -e "$t" ]]; then
					echo "ERROR: Destination already contains $(basename "$f") at $dest_dir/. Aborting to prevent overwrite."
					exit 1
				fi
			done

			echo "Moving $sh_file and $conf_file to $dest_dir"
			mv "$sh_file" "$dest_dir"
			mv "$conf_file" "$dest_dir"

		else
			echo "ERROR: No .conf file for $sh_file, cannot promote."
			exit 1
		fi
	done

	# Check for orphans
	if [[ -d "./staging" ]]; then
		if [[ -z "$(ls -A ./staging)" ]]; then
			echo "Removing empty ./staging directory."
			rmdir ./staging
		else
			echo "ERROR: Orphaned files left in ./staging after promotion!"
			ls -l ./staging
			exit 1
		fi
	fi
}

_about_promote_staged_module() {
	cat <<EOF
Usage: promote_staged_module <command> [options]

Commands:
	help        - Show this help message

Notes:
	- If the module .conf contains parent=development the module is promoted
	  to /src/development[/<group>] (if group is set it becomes /src/development/<group>).
	- For other parents the module is promoted to ./src/<parent>[/<group>].
	- Destination directories are created with mkdir -p if they don't exist.
	- Promotion aborts if a file with the same name already exists at the destination.
EOF
}

### START ./promote_staged_module.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(promote_staged_module help)"
	echo "$help_output" | grep -q "Usage: promote_staged_module" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	promote_staged_module "$@"
fi

### END ./promote_staged_module.sh - Armbian Config V2 test entrypoint