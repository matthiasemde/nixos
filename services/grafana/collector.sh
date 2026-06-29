#!/bin/bash
# Usage: collector.sh <outfile> <dir1> [dir2 ...]

OUT="$1"
shift

echo "# HELP directory_size_bytes Size of directory in bytes" > "$OUT"
echo "# TYPE directory_size_bytes gauge" >> "$OUT"

for BASE_DIR in "$@"; do
    find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        size=$(du -sb "$dir" | cut -f1)
        name=$(basename "$dir")
        parent=$(basename "$BASE_DIR")
        if [ "$parent" = "services" ]; then
            echo "directory_size_bytes{parent=\"$parent\",directory=\"$dir\",service=\"$name\"} $size" >> "$OUT"
        else
            echo "directory_size_bytes{parent=\"$parent\",directory=\"$dir\"} $size" >> "$OUT"
        fi
    done
done
