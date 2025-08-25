#!/usr/bin/env bash
set -euo pipefail

# ./icon_set.sh - Armbian Config V2 module

icon_set() {
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
			_about_icon_set
			;;
		""|web)
			[[ "${1:-}" == "web" ]] && shift
			if [[ -d "$PROJECT_ROOT/share/icons/hicolor/" ]]; then
				mkdir -p "$PROJECT_ROOT/public_html/images/logos/"
				cp -r "$PROJECT_ROOT/share/icons/hicolor/" "$PROJECT_ROOT/public_html/images/logos/"
			else 
				_icon_set_main "${1:-$PROJECT_ROOT/assets/images/logos}" "${2:-$PROJECT_ROOT/public_html/images/logos}"
			fi
			;;
		desktop|share)
			if [[ -d "$PROJECT_ROOT/public_html/images/logos" ]]; then
				mkdir -p "$PROJECT_ROOT/share/icons/hicolor/"
				cp -r "$PROJECT_ROOT/public_html/images/logos/" "$PROJECT_ROOT/share/icons/hicolor/"
			else 
				_icon_set_main "${1:-$PROJECT_ROOT/assets/images/logos}" "${2:-$PROJECT_ROOT/share/icons/hicolor/}"
			fi
			;;
		*)
			echo "Unknown command: ${1}"
			_about_icon_set
			return 1
			;;  # FIX: needed terminator
	esac
}

_icon_set_main() {
	local SRC_DIR="${1:-}"
	local OUT_DIR_BASE="${2:-}"

	[[ -n "${SRC_DIR}" && -d "${SRC_DIR}" ]] || { echo "SVG source not found: ${SRC_DIR}"; return 1; }
	[[ -n "${OUT_DIR_BASE}" ]] || { echo "Output directory not given or empty"; return 1; }

	# Prefer 'magick' if available, else 'convert'
	local IM="convert"
	if command -v magick >/dev/null 2>&1; then
		IM="magick"
	elif ! command -v convert >/dev/null 2>&1; then
		echo "ImageMagick is required ('magick' or 'convert' not found)."
		return 1
	fi

	# Sizes
	local DEFAULT_SIZES="16,32,48,512"
	local sizes_csv="${ICON_SIZES:-$DEFAULT_SIZES}"
	IFS=',' read -r -a SIZES <<<"${sizes_csv//[[:space:]]/}"

	# Ensure output structure
	mkdir -p "${OUT_DIR_BASE}/scalable" "${OUT_DIR_BASE}/scalable/legacy"

	# Copy SVGs (non-legacy)
	find "${SRC_DIR}" -maxdepth 1 -type f -name "*.svg" -exec cp -f {} "${OUT_DIR_BASE}/scalable/" \;

	# Copy legacy SVGs if present
	if [[ -d "${SRC_DIR}/legacy" ]]; then
		find "${SRC_DIR}/legacy" -maxdepth 1 -type f -name "*.svg" -exec cp -f {} "${OUT_DIR_BASE}/scalable/legacy/" \;
	fi

	# Render PNGs into <out>/<size>x<size>/<name>.png
	# Iterate both src and optional src/legacy
	shopt -s nullglob
	local svg
	for svg in "${SRC_DIR}"/*.svg "${SRC_DIR}/legacy"/*.svg; do
		[[ -e "$svg" ]] || continue
		local base="$(basename "${svg%.svg}")"
		for size in "${SIZES[@]}"; do
			[[ "$size" =~ ^[0-9]+$ ]] || continue
			local OUT_DIR="${OUT_DIR_BASE}/${size}x${size}"
			mkdir -p "${OUT_DIR}"
			# Transparent background, keep aspect, center and pad to square
			# 'magick' and 'convert' accept the same arguments here.
			$IM -background none -density 384 "$svg" \
				-resize "${size}x${size}" \
				-gravity center -extent "${size}x${size}" \
				"${OUT_DIR}/${base}.png"
		done
	done
	shopt -u nullglob

	# Favicon generation
	# Prefer a specific file if present; fall back to the first available SVG
	local FAVICON_SVG="${SRC_DIR}/armbian_social.svg"
	if [[ ! -f "$FAVICON_SVG" ]]; then
		for svg in "${SRC_DIR}"/*.svg; do
			[[ -f "$svg" ]] || continue
			FAVICON_SVG="$svg"
			echo "$svg"
			break
		done
	fi

	if [[ -f "$FAVICON_SVG" ]]; then
		local tmp16="$PROJECT_ROOT/public_html/favicon-16.png"
		local tmp32="$PROJECT_ROOT/public_html/favicon-32.png"
		local tmp48="$PROJECT_ROOT/public_html/favicon-48.png"
		$IM -background none "$FAVICON_SVG" -resize 16x16 "$tmp16"
		$IM -background none "$FAVICON_SVG" -resize 32x32 "$tmp32"
		$IM -background none "$FAVICON_SVG" -resize 48x48 "$tmp48"
		$IM "$tmp16" "$tmp32" "$tmp48" "$PROJECT_ROOT/public_html/favicon.ico"
		rm -f "$tmp16" "$tmp32" "$tmp48"
		echo "Favicon generated at $PROJECT_ROOT/public_html/favicon.ico"
	else
		echo "No SVG found for favicon in ${SRC_DIR} (looked for armbian_social.svg or any .svg). Skipping favicon."
	fi

	echo "SVGs copied to:       ${OUT_DIR_BASE}/scalable[/legacy]"
	echo "PNG icons generated:  ${OUT_DIR_BASE}/{SIZE}x{SIZE}/name.png"
}

_about_icon_set() {
	cat <<'EOF'
Usage: icon_set <command> [options]
Commands
	help	- Show this help message
	web	- Generate icons (default)
	
Environment:
	ICON_SIZES   Space or comma separated sizes (default: 16 32 48 512)


Example:
	icon_set
	icon_set help
	ICON_SIZES="16,32,48,512" icon_set
	icon_set web ./assets/images/logos ./public_html/images/logos

Requires:
	ImageMagick (convert or magick)
EOF
}

### START ./icon_set.sh - Armbian Config V2 test entrypoint
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	help_output="$(icon_set help)"
	echo "$help_output" | grep -q "Usage: icon_set" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	icon_set "$@"
fi
### END ./icon_set.sh - Armbian Config V2 test entrypoint