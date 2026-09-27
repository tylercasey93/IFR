#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../IFRCore"
if ! command -v swift >/dev/null 2>&1 && [ -x /opt/swift/usr/bin/swift ]; then
  export PATH="/opt/swift/usr/bin:$PATH"
fi
swift test "$@"
