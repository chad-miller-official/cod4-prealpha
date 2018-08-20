#!/bin/bash

force=false
echo_outfile_only=false

usage() {
    echo "Usage: $0 [-fp] <fastfile to extract header from>"
    exit 1;
}

while getopts 'fp' opt; do
    case "${opt}" in
        f)
            force=true
            ;;
        p)
            echo_outfile_only=true
            ;;
        *) 
            usage
            ;;
    esac
done

shift $((OPTIND - 1))

if [[ -z "$1" ]]; then
    usage
fi

if [[ ! -f "$1" ]]; then
    echo "Input file does not exist: $1"
    exit 1
fi

cwd="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)"
outfile="$cwd/ff-headers/$(basename $1).bin"

if [[ -f "$outfile" && $force != true ]]; then
    echo "Output file already exists: $outfile."
    echo "To force extraction, use -f flag."
    exit 1
fi

head -c 28 "$1" > "$outfile"

if [[ $echo_outfile_only = true ]]; then
    echo "$outfile"
else
    echo "Extracted to $outfile."
fi

exit 0
