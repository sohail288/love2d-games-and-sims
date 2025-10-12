#!/bin/sh
set -eu

candidates="luac luac5.1 luac-5.1"

for candidate in $candidates; do
    if command -v "$candidate" >/dev/null 2>&1; then
        command -v "$candidate"
        exit 0
    fi
done

>&2 printf '%s\n' "luac executable not found. Install Lua 5.1 development tools to provide luac."
exit 1
