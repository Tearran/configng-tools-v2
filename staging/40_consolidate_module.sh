#!/usr/bin/env bash
set -euo pipefail


SRC_ROOT="./src"
OUT_FILE="./lib/armbian-config/module_options_arrays.sh"
LIB_ROOT="./lib/armbian-config"
IGNORE_FILES=("readme.sh" "module-browser.html")

declare -A array_entries
declare -A group_counts  # For unique id per group

# Required keys for helpers
required_helper_keys=(description extend_desc parent group)

_consolidate_src() {
	mkdir -p "$LIB_ROOT"
	declare -A pipefail_written
	find "$SRC_ROOT" -type f -name '*.sh' | while read -r f; do
		rel="${f#$SRC_ROOT/}"
		namespace="${rel%%/*}"
		OUT="$LIB_ROOT/$namespace.sh"
		fname=$(basename "$f")
		skip=false
		for ignore in "${IGNORE_FILES[@]}"; do
			if [[ "${fname,,}" == "${ignore,,}" ]]; then
				skip=true
				break
			fi
		done
		[[ "$skip" == true ]] && continue

		# Only create/truncate once per OUT (per run)
		if [[ ! -e "$OUT.in_progress" ]]; then
			: > "$OUT"
			touch "$OUT.in_progress"
		fi

		echo -e "\n####### $f #######" >> "$OUT"
		awk -v pf="${pipefail_written[$OUT]:-0}" '
		BEGIN { inheader=1; inblock=0 }
		/^#!.*bash/ { next }
		inheader && /^set -euo pipefail/ {
			if (pf == 0) {
				print
				pf = 1
			}
			inheader=0
			next
		}
		inheader && NF==0 { next }
		inheader { next }
		/^set -euo pipefail/ { next }
		/^if \[\[ "\$\{BASH_SOURCE\[0\]\}" == "\$\{0\}" \]\]; then/ { inblock=1; next }
		inblock && /^\s*fi\s*$/ { inblock=0; next }
		inblock { next }
		{ print }
		' "$f" >> "$OUT"
		# Mark that pipefail is written for this output file
		pipefail_written[$OUT]=1
		echo -e "\n" >> "$OUT"
	done

	rm -f "$LIB_ROOT"/*.in_progress
	echo "All library files have been assembled in $LIB_ROOT/"
}

emit_section() {
	local section="$1"
	declare -n mapref="$2"
	local parent group arr parent_key id_num unique_id key

	parent="${mapref[parent]:-}"
	group="${mapref[group]:-}"

	[[ -z "$section" || -z "$parent" || -z "$group" ]] && return

	if [[ "$section" == _* ]]; then
		for req in "${required_helper_keys[@]}"; do
			if [[ -z "${mapref[$req]:-}" ]]; then
				echo "Error: Helper section [$section] missing required key: $req" >&2
				exit 1
			fi
		done
		arr="${parent}_helpers"
	else
		arr="${parent}_options"
	fi

	parent_key=$(echo "$parent" | tr '[:lower:]' '[:upper:]' | cut -c1-3)
	group_counts["$parent_key"]=$(( ${group_counts["$parent_key"]:-0} + 1 ))
	id_num=$(printf "%03d" "${group_counts["$parent_key"]}")
	unique_id="${parent_key}${id_num}"

	mapref["unique_id"]="$unique_id"

	for key in "${!mapref[@]}"; do
		array_entries["$arr"]+=$'\n'"${arr}[${section},${key}]=\"${mapref[$key]}\""
	done
}

_process_confs() {
	while IFS= read -r meta; do
		[[ -e "$meta" ]] || continue
		section=""
		declare -A section_kv=()
		while IFS='=' read -r key value || [[ -n "$key" ]]; do
			if [[ "$key" =~ ^\[(.*)\]$ ]]; then
				emit_section "$section" section_kv
				section="${BASH_REMATCH[1]}"
				section_kv=()
				continue
			fi
			[[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
			section_kv["$key"]="$value"
		done < "$meta"
		emit_section "$section" section_kv
	done < <(find "${SRC_DIRS[@]}" -type f -name '*.conf')
}

_write_arrays() {
	mkdir -p "$(dirname "$OUT_FILE")"
	{
		echo -e "######## Auto-generated. Do not edit. ########\n"
		for arr in $(printf "%s\n" "${!array_entries[@]}" | sort); do
			echo -e "######## start $arr ########\n#"
			echo "declare -A $arr"
			echo "${array_entries[$arr]}"
			echo -e "#\n######## finish $arr ########\n"
		done
	} > "$OUT_FILE"
	echo "Wrote generated options arrays to $OUT_FILE"
}


_process_parent_group() {
	local conf="./src/core/initialize/list_options.conf"
	declare -A parent_options
	declare -A group_options

	local current_section=""
	local key val
	local -A module_section

	echo -e "#\n######## start append descriptions ########\n"

	# Parse config file
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Clean up line
		line="${line%%#*}"
		line="${line%%;*}"
		line="${line#"${line%%[![:space:]]*}"}"
		line="${line%"${line##*[![:space:]]}"}"
		[[ -z "$line" ]] && continue

		# Section header
		if [[ "$line" =~ ^\[(.*)\]$ ]]; then
			current_section="${BASH_REMATCH[1]}"
			continue
		fi

		# Key-value
		if [[ "$line" =~ ^([a-zA-Z0-9_]+)=(.*)$ ]]; then
			key="${BASH_REMATCH[1]}"
			val="${BASH_REMATCH[2]}"
			case "$current_section" in
				options)
					# Parent descriptions
					parent_options["$key"]="$val"
					;;
				system|software|network|all)
					# Group descriptions
					group_options["$current_section,$key"]="$val"
					;;
				*)
					# For completeness, you could handle [list_options] etc here if needed
					;;
			esac
		fi
	done < "$conf"

	# Emit parent descriptions (system_options[system,description], etc)
	for parent in "${!parent_options[@]}"; do
		echo "${parent}_options[${parent},description]=\"${parent_options[$parent]}\""
	done

	# Emit group descriptions (system_options[system,Kernel], etc)
	for key in "${!group_options[@]}"; do
		local section="${key%%,*}"
		local name="${key#*,}"
		echo "${section}_options[${section},${name}]=\"${group_options[$key]}\""
	done

	echo -e "#\n######## end append descriptions ########\n"
}

consolidate_module() {
	local cmd="${1:-all}"
	case "$cmd" in
		consolidate)
			_consolidate_src
			;;
		generate|process)
			_process_confs
			_write_arrays
			;;
		all)
			_consolidate_src
			_process_confs
			_write_arrays
			_process_parent_group >> "$OUT_FILE"
			echo "Wrote generated descriptions to $OUT_FILE"
			;;
		*)
			echo "Usage: $0 [consolidate|generate|all]"
			return 1
			;;
	esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	consolidate_module "${1:-all}"
fi
