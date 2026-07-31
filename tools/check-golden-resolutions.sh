#!/usr/bin/env bash
# Checks that golden baseline files exist for all 5 canonical resolutions.
#
# Usage: tools/check-golden-resolutions.sh [screen_name]
#   With screen_name: checks that specific screen's golden exists at all 5 sizes
#   Without: lists all golden baselines and reports missing resolutions
#
# Exit 0 if complete, 1 if gaps found.

set -euo pipefail

GOLDEN_DIR="test/goldens/goldens"
RESOLUTIONS=("compact" "medium" "expanded" "wide" "wide_large")

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

if [[ $# -gt 0 ]]; then
  SCREEN="$1"
  MISSING=()
  for res in "${RESOLUTIONS[@]}"; do
    if [[ ! -f "${GOLDEN_DIR}/${SCREEN}_${res}.png" ]]; then
      MISSING+=("${SCREEN}_${res}.png")
    fi
  done
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${RED}MISSING golden baselines for ${SCREEN}:${NC}"
    for m in "${MISSING[@]}"; do
      echo "  - ${m}"
    done
    exit 1
  else
    echo -e "${GREEN}${SCREEN}: all 5 resolutions present${NC}"
    exit 0
  fi
fi

# List mode: find all unique screen names and check each
echo "Golden resolution coverage:"
echo "============================"

SCREENS=$(find "${GOLDEN_DIR}" -name "*.png" -not -name "*_compact*" -not -name "*_medium*" -not -name "*_expanded*" -not -name "*_wide*" -not -name "*_wide_large*" | sed 's|.*/||; s|\.png$||' | sort -u)

GAPS=0
for screen in $SCREENS; do
  MISSING=()
  for res in "${RESOLUTIONS[@]}"; do
    if [[ ! -f "${GOLDEN_DIR}/${screen}_${res}.png" ]]; then
      MISSING+=("$res")
    fi
  done
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${RED}  ${screen}: missing ${MISSING[*]}${NC}"
    GAPS=$((GAPS + 1))
  else
    echo -e "${GREEN}  ${screen}: complete${NC}"
  fi
done

echo ""
if [[ $GAPS -gt 0 ]]; then
  echo -e "${RED}${GAPS} screen(s) with missing resolutions${NC}"
  exit 1
else
  echo -e "${GREEN}All screens have complete resolution coverage${NC}"
  exit 0
fi
