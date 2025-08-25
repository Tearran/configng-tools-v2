#!/usr/bin/env bash
set -euo pipefail

# JSON escaping helper
json_escape() {
	local s="$1"
	s="${s//\\/\\\\}"
	s="${s//\"/\\\"}"
	s="${s//$'\n'/ }"
	printf '%s' "$s"
}

# Extract tag content helper
extract_tag_content() {
	local file="$1" primary="$2" fallback="$3" val
	if val="$(grep -m1 -o "<${primary}>[^<]*</${primary}>" "$file" 2>/dev/null)"; then
		val="$(printf '%s' "$val" | sed 's|<[^>]*>||g')"
		printf '%s' "$val"; return 0
	fi
	if [ -n "$fallback" ]; then
		if val="$(grep -m1 -o "<${fallback}>[^<]*</${fallback}>" "$file" 2>/dev/null)"; then
			val="$(printf '%s' "$val" | sed 's|<[^>]*>||g')"
			printf '%s' "$val"; return 0
		fi
	fi
	printf ''; return 1
}

_json_set_images() {
	local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local PROJECT_ROOT
	
	if [[ -d "${SCRIPT_DIR}/../.git" ]]; then
		PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
	elif [[ -d "${SCRIPT_DIR}/../../.git" ]]; then
		PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
	fi
	
	# Allow direct parameter override
	local SVG_DIR="${1:-${SVG_SRC_DIR:-$PROJECT_ROOT/assets/images/logos}}"
	local JSON_OUT="${2:-${WEB_JSON_ROOT:-$PROJECT_ROOT/public_html/json}/images/logo.json}"
	
	# Derive other paths
	local WEB_ROOT="$PROJECT_ROOT/public_html"
	local IMG_ROOT="${LOGO_IMG_ROOT:-$WEB_ROOT/images}"
	local IMG_WEB="${LOGO_IMG_WEB:-images/logos}"

	# Normalize IMG_WEB path
	IMG_WEB="${IMG_WEB%/}"
	IMG_WEB="${IMG_WEB#/}"
	IMG_WEB="${IMG_WEB#./}"

	# Set image sizes
	local SIZES=(16 32 48 512)
	if [ -n "${ICON_SIZES:-}" ]; then
		IFS=',' read -r -a SIZES <<< "${ICON_SIZES}"
	fi

	# Create output directory
	mkdir -p "$(dirname "$JSON_OUT")"

	# Find SVG files
	mapfile -t svg_files < <(find "$SVG_DIR" -type f -name "*.svg" 2>/dev/null | sort -u)

	# Build JSON
	printf '[\n' > "$JSON_OUT"
	local first=1

	for file in "${svg_files[@]}"; do
		[ -e "$file" ] || continue
		local name="$(basename "${file%.svg}")"
		local category svg_path

		# Set category and path
		if [[ "$file" == */legacy/* ]]; then
			if [[ "$name" == armbian_* ]]; then category="armbian-legacy"
			elif [[ "$name" == configng_* ]]; then category="configng-legacy"
			else category="other-legacy"; fi
			svg_path="${IMG_WEB}/scalable/legacy/${name}.svg"
		else
			if [[ "$name" == armbian_* ]]; then category="armbian"
			elif [[ "$name" == configng_* ]]; then category="configng"
			else category="other"; fi
			svg_path="${IMG_WEB}/scalable/${name}.svg"
		fi

		# Get metadata
		local title="$(extract_tag_content "$file" "dc:title" "title")"
		[ -z "$title" ] && title="$(extract_tag_content "$file" "title" "")"
		local desc="$(extract_tag_content "$file" "dc:description" "desc")"
		[ -z "$desc" ] && desc="$(extract_tag_content "$file" "desc" "")"
		title="$(json_escape "$title")"
		desc="$(json_escape "$desc")"

		# Get PNGs
		local png_entries="" png_count=0
		for size in "${SIZES[@]}"; do
			[[ "$size" =~ ^[0-9]+$ ]] || continue
			local img_path="${IMG_WEB}/${size}x${size}/${name}.png"
			local full_path="${IMG_ROOT}/${size}x${size}/${name}.png"
			
			if [[ -f "$full_path" ]]; then
				local kb=$(du -k "$full_path" 2>/dev/null | cut -f1 || echo 0)
				if (( kb > 0 )); then
					local kb_fmt="$(printf "%.2f" "$kb")"
					if (( png_count > 0 )); then
						png_entries="${png_entries},\n      { \"path\": \"${img_path}\", \"size\": \"${size}x${size}\", \"kb\": ${kb_fmt} }"
					else
						png_entries="      { \"path\": \"${img_path}\", \"size\": \"${size}x${size}\", \"kb\": ${kb_fmt} }"
					fi
					((png_count++))
				fi
			fi
		done

		# Add comma between objects
		if [ "$first" -eq 0 ]; then
			printf ',\n' >> "$JSON_OUT"
		fi
		first=0

		# Write object
		{
		printf '  {\n'
		printf '    "name": "%s",\n' "$name"
		printf '    "category": "%s",\n' "$category"
		printf '    "svg": "%s",\n' "$svg_path"
		printf '    "svg_meta": {\n'
		printf '      "title": "%s",\n' "$title"
		printf '      "desc": "%s"\n' "$desc"
		printf '    },\n'
		printf '    "pngs": [\n'
		if [[ -n "$png_entries" ]]; then
			printf '%b\n' "$png_entries"
		fi
		printf '    ]\n'
		printf '  }'
		} >> "$JSON_OUT"
	done

	# Close array
	printf '\n]\n' >> "$JSON_OUT"
	printf 'JSON written to: %s\n' "$JSON_OUT"
}



# ./json_set.sh - Armbian Config V2 module

json_set() {
	local SCRIPT_DIR
	SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
	# Project root = parent of script dir (adjust if you prefer SCRIPT_DIR itself)
	local PROJECT_ROOT
	if [[ -d "${SCRIPT_DIR}/../.git" ]]; then
		PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
	elif  [[ -d "${SCRIPT_DIR}/../../.git" ]];then
		PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
	fi
	WEB_JSON_ROOT="$PROJECT_ROOT/public_html/json"


	case "${1:-}" in
		help|-h|--help|"")
			_about_json_set
			;;
		contrib|-c)
			shift
			_json_set_contributors "${1:-Tearran}" "${2:-configng-tools-v2}"
			;;
		images|-i)
			shift
			_json_set_images "${1:-$PROJECT_ROOT/assets/images/logos}" "${2:-$PROJECT_ROOT/public_html/json/images/logos.json}"
			;;
		armbian-config|-a)
			shift
			_json_set_images "${1:-$PROJECT_ROOT/assets/images/logos}" "${2:-$PROJECT_ROOT/public_html/json/images/logos.json}"
			
			_json_set_contributors "${1:-Tearran}" "${2:-configng-tools-v2}"
			_json_set_contributors "${1:-armbian}" "${2:-configng}"
			_json_set_contributors "${1:-armbian}" "${2:-config}"
			;;
		armbian)
			_json_set_contributors "${1:-armbian}" "${2:-documentation}"
			_json_set_contributors "${1:-armbian}" "${2:-build}"
			;;
		*)
			echo "Unknown command: ${1}"
			_about_json_set
			return 1
	esac
}

_json_set_contributors() {

	if ! command -v jq >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
		echo "jq and wget are required to generate the contributors JSON. Please install them."
		exit 1
	fi

	local USER="${1:-Tearran}"
	local REPO="${2:-configng-v2}"
	local MIN_COMMITS=1   # Default minimum commits

	local json_root="${WEB_JSON_ROOT:-${WEB_ROOT:-./}/json}"
	mkdir -p "${json_root}/contributors/"

	local OUTFILE="${3:-${json_root}/contributors/${REPO}.json}"

	#echo "Generating contributors JSON for ${USER}/${REPO} (min commits: ${MIN_COMMITS})..."

	local headers=(--header="Accept: application/vnd.github+json")
	local url="https://api.github.com/repos/${USER}/${REPO}/contributors?per_page=100"

	if ! wget -qO- "${headers[@]}" "${url}" \
		| jq --argjson min "$MIN_COMMITS" '[.[] | select(.contributions > $min) | {login, contributions, avatar_url, html_url}]' \
		> "${OUTFILE}"; then
		echo "Failed to generate contributors JSON for ${USER}/${REPO}."
		exit 1
	fi

	echo "Contributors JSON generated at ${OUTFILE}"
}

_about_json_set() {
	cat <<EOF
Usage: json_set <command> [options]

Commands:
	help        - Show this help message
	contrib     - Get GitHub contributors list
	images      - Generate image metadata JSON

Examples:
	json_set help
	json_set contrib [username] [repo]
	json_set images [svg_dir] [output_json]

Requires:
	jq, wget (for contributor data)
EOF
}

### START ./json_set.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(json_set help)"
	echo "$help_output" | grep -q "Usage: json_set" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	json_set "$@"
fi

### END ./json_set.sh - Armbian Config V2 test entrypoint

