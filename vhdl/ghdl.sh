#!/usr/bin/env bash
set -euo pipefail
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/gcc/lib/gcc/current${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
exec /opt/homebrew/bin/ghdl "$@"
