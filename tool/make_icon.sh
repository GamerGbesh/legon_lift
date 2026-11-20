#!/usr/bin/env bash
# Alias for tool/make_icons.sh (the name SPEC 11.5 uses). Same arguments.
exec "$(dirname "${BASH_SOURCE[0]}")/make_icons.sh" "$@"
