#!/bin/sh
set -eu

override="${LUAC_EXECUTABLE-}"
if [ -n "$override" ]; then
    if [ -x "$override" ]; then
        printf '%s\n' "$override"
        exit 0
    fi

    if command -v "$override" >/dev/null 2>&1; then
        command -v "$override"
        exit 0
    fi

    >&2 printf '%s\n' "specified luac executable \"$override\" was not found or is not executable."
    exit 1
fi

candidates="luac luac5.1 luac-5.1"

for candidate in $candidates; do
    if command -v "$candidate" >/dev/null 2>&1; then
        command -v "$candidate"
        exit 0
    fi
done

>&2 printf '%s\n' "luac executable not found. Install Lua 5.1 development tools to provide luac."
exit 1
