#!/usr/bin/env bash
set -euo pipefail

# ./validate_staged_modules.sh - Armbian Config V2 module

validate_staged_modules() {
	case "${1:-}" in
		help|-h|--help)
			_about_validate_staged_modules
			;;
		"")
			_validate_staged_modules_main
			;;
		*)
			echo "Unknown command: $1"
			_about_validate_staged_modules
			exit 1
			;;

	esac
}

_validate_staged_modules_main() {
shopt -s nullglob   # <--- Add this!
			local failed=0
			local shfiles=(./staging/*.sh)
			if [ ${#shfiles[@]} -eq 0 ]; then
				echo "No modules found in ./staging/"
				#Sexit 1
			fi
			for shfile in "${shfiles[@]}"; do
				modname="$(basename "$shfile" .sh)"
				echo "==> Checking module: $modname"
				_check_sh "./staging/$modname.sh" || failed=1
				_check_conf "./staging/$modname.conf" || failed=1
				_check_duplicate_anywhere "$modname" || failed=1
				echo
			done
			if [[ "$failed" -ne 0 ]]; then
				echo "One or more modules failed validation" >&2
				exit 1
			fi
}


_check_sh() {
	file="$1"
	modname="$(basename "$file" .sh)"

	if [ ! -f "$file" ]; then
		echo "MISSING: $file"
		return 1
	fi

	# If filename starts with two digits and an underscore (e.g. "90_manage_images"),
	# strip that prefix for the _about_ check so we look for _about_manage_images().
	check_name="$modname"
	if [[ "$modname" =~ ^[0-9]{2}_(.+)$ ]]; then
		check_name="${BASH_REMATCH[1]}"
		echo "INFO: Stripped numeric prefix -> checking _about_${check_name}()"
	fi

	# Check for _about_<check_name>() function; allow leading whitespace and optional 'function' keyword
	if ! grep -Eq "^[[:space:]]*(function[[:space:]]+)?_about_${check_name}[[:space:]]*\\(\\)[[:space:]]*\\{" "$file"; then
		echo "FAIL: $file missing _about_${check_name}()"
		return 1
	fi

	echo "OK: $file"
}

_check_conf_hold() {
	# Check for required fields in <modulename>.conf
	local REQUIRED_CONF_FIELDS=(feature options helpers description parent group contributor port)
	local file="$1"
	local failed=0
	local failed_fields=()

	if [ ! -f "$file" ]; then
		echo "MISSING: $file"
		return 1
	fi
	# Check for feature= line
	local feature
	feature="$(grep -E "^feature=" "$file" | cut -d= -f2- | xargs)"

	for field in "${REQUIRED_CONF_FIELDS[@]}"; do
		if ! grep -qE "^$field=" "$file"; then
			failed=1
			failed_fields+=("$field (missing)")
			continue
		fi

		local value
		value="$(grep -E "^$field=" "$file" | cut -d= -f2- | xargs)"

		case "$field" in
			helpers)
		# Check for _about_<feature> function in CSV or space-separated helpers list
				if [[ -n $feature && ! $value =~ (^|,)_about_${feature}(,|$) ]]; then
					failed=1
					failed_fields+=("helpers must have at least (_about_$feature)")
				fi
				;;
			options)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("options (blank; should describe supported options or 'none')")
				fi
				;;
			parent|group)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("$field (empty)")
				elif [[ "$value" =~ [A-Z\ ] ]]; then
					failed=1
					failed_fields+=("$field (should be lowercase, no spaces)")
				fi
				;;
			contributor)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("contributor (empty)")
				elif [[ ! "$value" =~ ^@[a-zA-Z0-9_-]+$ ]]; then
					failed=1
					failed_fields+=("contributor (should be valid github username, like @tearran)")
				fi
				;;
			feature|description|port)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("$field (empty)")
				fi
				;;
		esac
	done

	if [ "$failed" -eq 0 ]; then
		echo "OK: $file"
		return 0
	else
		echo "FAIL: $file missing or invalid fields:"
		for f in "${failed_fields[@]}"; do
			echo "  - $f"
		done
		return 1
	fi
}

_check_conf() {
	# Check for required fields in <modulename>.conf
	# Edit VALID_PARENTS to change allowed parent categories
	local VALID_PARENTS=(core network system software locales development)
	local REQUIRED_CONF_FIELDS=(feature options helpers description parent group contributor port)
	local file="$1"
	local failed=0
	local failed_fields=()

	if [ ! -f "$file" ]; then
		echo "MISSING: $file"
		return 1
	fi
	# Check for feature= line
	local feature
	feature="$(grep -E "^feature=" "$file" | cut -d= -f2- | xargs || true)"

	for field in "${REQUIRED_CONF_FIELDS[@]}"; do
		if ! grep -qE "^$field=" "$file"; then
			failed=1
			failed_fields+=("$field (missing)")
			continue
		fi

		local value
		value="$(grep -E "^$field=" "$file" | cut -d= -f2- | xargs || true)"

		case "$field" in
			helpers)
				# Check for _about_<feature> function in CSV or space-separated helpers list
				if [[ -n $feature ]] && ! echo "$value" | grep -Eq "(^|[[:space:],])_about_${feature}([[:space:],]|$)"; then
					failed=1
					failed_fields+=("helpers must have at least (_about_$feature)")
				fi
				;;
			options)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("options (blank; should describe supported options or 'none')")
				fi
				;;
			parent)
				# parent must be non-empty, lowercase, no spaces, and one of VALID_PARENTS
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("parent (empty)")
				elif [[ "$value" =~ [A-Z\ ] ]]; then
					failed=1
					failed_fields+=("parent (should be lowercase, no spaces)")
				else
					local ok=1
					for p in "${VALID_PARENTS[@]}"; do
						if [[ "$value" == "$p" ]]; then
							ok=0
							break
						fi
					done
					if [ "$ok" -ne 0 ]; then
						failed=1
						failed_fields+=("parent (invalid; must be one of: ${VALID_PARENTS[*]})")
					fi
				fi
				;;
			group)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("group (empty)")
				elif [[ "$value" =~ [A-Z\ ] ]]; then
					failed=1
					failed_fields+=("group (should be lowercase, no spaces)")
				fi
				;;
			contributor)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("contributor (empty)")
				elif [[ ! "$value" =~ ^@[a-zA-Z0-9_-]+$ ]]; then
					failed=1
					failed_fields+=("contributor (should be valid github username, like @tearran)")
				fi
				;;
			feature|description|port)
				if [ -z "$value" ]; then
					failed=1
					failed_fields+=("$field (empty)")
				fi
				;;
		esac
	done

	if [ "$failed" -eq 0 ]; then
		echo "OK: $file"
		return 0
	else
		echo "FAIL: $file missing or invalid fields:"
		for f in "${failed_fields[@]}"; do
			echo "  - $f"
		done
		return 1
	fi
}
_check_duplicate_anywhere() {
	local modname="$1"
	local found=0
	local scanned=0

	# Directories to scan for duplicates (add more if needed)
	local dirs=(./src ./tools)

	for dir in "${dirs[@]}"; do
		# Skip directories that don't exist to avoid 'find' errors on first run
		if [[ ! -d "$dir" ]]; then
			continue
		fi
		scanned=1

		for ext in .sh .conf; do
			# Find matching files; silence find errors just in case
			while IFS= read -r file; do
				# Skip if nothing found or file is in ./staging
				[[ -z "$file" ]] && continue
				[[ "$file" == ./staging/* ]] && continue
				# FAIL if file exists outside staging
				if [ -f "$file" ]; then
					echo "FAIL: Duplicate found in $dir: $file"
					found=1
				fi
			done < <(find "$dir" -type f -name "$modname$ext" 2>/dev/null)
		done
	done

	# If we didn't scan any directories, just inform (not an error) and return success.
	if [[ "$scanned" -eq 0 ]]; then
		echo "INFO: No duplicate-search directories (like ./src) found; skipping duplicate checks."
		return 0
	fi

	return $found
}

_about_validate_staged_modules() {
	cat <<EOF
Usage: validate_staged_modules [help]

Validate staged module .sh and .conf files under ./staging/.

Commands:
	help    Show this help message

Examples:
	# Validate all modules under ./staging/
	validate_staged_modules

	# Show help
	validate_staged_modules help

Notes:
	- If a filename begins with NN_ (two digits and an underscore), the validator
	  strips that prefix when checking for the _about_<name>() function.
	- Allowed parent values are defined in the _check_conf() function (VALID_PARENTS).
EOF
}

### START ./validate_staged_modules.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(validate_staged_modules help)"
	echo "$help_output" | grep -q "Usage: validate_staged_modules" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	validate_staged_modules "$@"
fi

### END ./validate_staged_modules.sh - Armbian Config V2 test entrypoint

