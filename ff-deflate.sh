#!/bin/bash

if [[ -z $1 || -z $2 ]]; then
    echo "Usage: $0 <fastfile to convert> <output dir>"
    exit 1
fi

if [[ ! -f "$1" ]]; then
    echo "Input file does not exist: $1"
    exit 1
fi

if [[ ! -d "$2" ]]; then
    echo "Output directory does not exist: $2"
    exit 1
fi

(dd if="$1" ibs=28 skip=1 | zlib-flate -uncompress) > "$2/$(basename $1).bin"
exit 0
