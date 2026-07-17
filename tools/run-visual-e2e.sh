#!/usr/bin/env bash
# Deprecated name — use capture-device-screens.sh
#
# Captures the app **as already running on your phone/desktop** (real session
# data). Does not create throwaway accounts.
#
#   bash tools/capture-device-screens.sh
#   bash tools/capture-device-screens.sh --android --guided
#   bash tools/capture-device-screens.sh --linux --now
#
# This wrapper forwards to capture-device-screens.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/capture-device-screens.sh" "$@"
