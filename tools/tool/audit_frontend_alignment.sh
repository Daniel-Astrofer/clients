#!/usr/bin/env bash
set -euo pipefail
FRONTEND_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$FRONTEND_ROOT"
python3 tools/tool/audit_frontend_alignment.py
