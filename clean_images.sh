#!/bin/bash
set -e

usage () {
    echo "Creates a 'cleaned' subfolder in the given folder and converts"
    echo "each image into a white image containing the filename but"
    echo "while preserving the EXIF data."
    echo ""
    echo "Usage: clean_images.sh <folder>"
}

abort () {
    echo "Error: $1." >&2
    exit 1
}

if [[ $1 == "-h" || $1 == "--help" ]]; then
    usage
    exit 0
fi

if [[ "$#" -ne 1 ]]; then
    abort "Illegal number of arguments"
fi

if ! [[ -x "$(command -v convert)" ]]; then
    abort "convert (ImageMagick) is not installed"
fi

input_directory=$1
output_directory="$input_directory/cleaned"

mkdir -p $output_directory

for file_path in $input_directory/*; do
    filename=$(basename -- "$file_path")
    extension=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]') # converted to lowercase

    if [[ $extension == "jpg" ||  $extension == "jpeg" || $extension == "png" ]]; then
        convert -size 500x100 xc:white -draw "text 20,40 '$filename'" "$output_directory/$filename"
        convert "$file_path" "$output_directory/$filename" -resize 500x100! -composite "$output_directory/$filename"
    fi
done
