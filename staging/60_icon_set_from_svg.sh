#!/bin/bash

# Directory containing SVGs  (env override supported)
SRC_DIR="${SRC_DIR:-assets/images/logos}"
# List of desired sizes  (env override supported)
SIZES=(${SIZES[@]:-16 32 48 64 128 256 512})

# Check for ImageMagick's convert command
if ! command -v convert &> /dev/null; then
	echo "Error: ImageMagick 'convert' command not found."
	read -p "Would you like to install ImageMagick using 'sudo apt install imagemagick'? [Y/n] " yn
	case "$yn" in
		[Yy]* | "" )
		echo "Installing ImageMagick..."
		sudo apt update && sudo apt install imagemagick
		if ! command -v convert &> /dev/null; then
			echo "Installation failed or 'convert' still not found. Exiting."
			exit 1
		fi
		;;
		* )
		echo "Cannot proceed without ImageMagick. Exiting."
		exit 1
	;;
	esac
fi

# Check if source directory exists
if [ ! -d "$SRC_DIR" ]; then
	echo "Error: Source directory '$SRC_DIR' does not exist."
	exit 1
fi

# Check if SVGs exist in the source directory
shopt -s nullglob
svg_files=("$SRC_DIR"/*.svg)
if [ ${#svg_files[@]} -eq 0 ]; then
	echo "Error: No SVG files found in '$SRC_DIR'."
	exit 1
fi
shopt -u nullglob

# Loop over each SVG file in the scalable directory
for svg in "${svg_files[@]}"; do
	# Extract the base filename without extension
	base=$(basename "$svg" .svg)
	# For each size, generate the PNG in the corresponding directory
	for size in "${SIZES[@]}"; do
		OUT_DIR="share/icons/hicolor/${size}x${size}"
		mkdir -p "$OUT_DIR"
		OUT_FILE="${OUT_DIR}/${base}.png"
		# Only generate if missing or source SVG is newer
		if [[ ! -f "$OUT_FILE" || "$svg" -nt "$OUT_FILE" ]]; then
			convert -background none -resize ${size}x${size} "$svg" "$OUT_FILE"
		if [ $? -eq 0 ]; then
			echo "Generated $OUT_FILE"
		else
			echo "Failed to convert $svg to $OUT_FILE"
		fi
	fi
	done
done
