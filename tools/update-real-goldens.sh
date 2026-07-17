#!/usr/bin/env bash
# Prefer device snapshot (no credentials). Delegates to device-snapshot-goldens.sh.
#
#   bash tools/device-snapshot-goldens.sh
#
# Legacy API login (only if you set REAL_GOLDENS_ALLOW_API_LOGIN + credentials)
# is no longer the default.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/device-snapshot-goldens.sh" "$@"
