#!/bin/bash
# Rebuilds the debug binary and relaunches GridOS, replacing any running debug instance.
# Usage: ./Scripts/dev-run.sh          rebuild, relaunch detached
#        ./Scripts/dev-run.sh -f       rebuild, run in the foreground with live logs
set -euo pipefail

PACKAGE_PATH="$(cd "$(dirname "$0")/.." && pwd)"
BINARY="$PACKAGE_PATH/.build/debug/GridOS"

# Replace a previous debug instance so two GridOSs cannot fight over the global hot key.
if pkill -f "build/debug/GridOS" 2>/dev/null; then
    sleep 1
fi

swift build --package-path "$PACKAGE_PATH"

# An installed copy (e.g. /Applications/GridOS.app) still holding the hot key would swallow
# activation and make the fresh build look broken.
if pgrep -x GridOS >/dev/null 2>&1; then
    echo "⚠️ Another GridOS instance is still running; it may hold the global hot key."
fi

if [[ "${1:-}" == "-f" ]]; then
    exec "$BINARY"
fi

nohup "$BINARY" >/dev/null 2>&1 &
echo "GridOS debug build running (pid $!)."
