#!/usr/bin/env bash
set -euo pipefail

# runmatrix.sh — run the full interop matrix or a single group.
#
# Usage:
#   ./runmatrix.sh --all              Run all 9 cells
#   ./runmatrix.sh --group baseline   Run one group (baseline, neutrality, matched, mismatched, fallback)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cell groups
BASELINE_CELLS="baseline-go baseline-c baseline-jvm"
NEUTRALITY_CELLS="neutrality-go neutrality-c neutrality-jvm"
MATCHED_CELLS="matched-go"
MISMATCHED_CELLS="mismatched-go"
FALLBACK_CELLS="fallback-go"
ALL_CELLS="$BASELINE_CELLS $NEUTRALITY_CELLS $MATCHED_CELLS $MISMATCHED_CELLS $FALLBACK_CELLS"

usage() {
  echo "Usage: $0 --all | --group <name>"
  echo "Groups: baseline, neutrality, matched, mismatched, fallback"
  exit 1
}

CELLS=""
case "${1:-}" in
  --all)
    CELLS="$ALL_CELLS"
    ;;
  --group)
    GROUP="${2:?Missing group name}"
    case "$GROUP" in
      baseline)   CELLS="$BASELINE_CELLS" ;;
      neutrality) CELLS="$NEUTRALITY_CELLS" ;;
      matched)    CELLS="$MATCHED_CELLS" ;;
      mismatched) CELLS="$MISMATCHED_CELLS" ;;
      fallback)   CELLS="$FALLBACK_CELLS" ;;
      *) echo "Unknown group: $GROUP" >&2; usage ;;
    esac
    ;;
  *) usage ;;
esac

MATRIX_START=$(date +%s)
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

echo "========================================"
echo "  Interop Matrix Run"
echo "  $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "========================================"
echo ""

for cell in $CELLS; do
  CELL_START=$(date +%s)
  VERDICT="FAIL"

  if bash "$SCRIPT_DIR/runscenario.sh" "$cell"; then
    VERDICT="PASS"
  else
    VERDICT="FAIL"
  fi

  CELL_END=$(date +%s)
  CELL_ELAPSED=$((CELL_END - CELL_START))

  # Read actual verdict from evidence file (may be REJECT-AS-EXPECTED)
  if [[ -f "evidence/${cell}.txt" ]]; then
    ACTUAL_VERDICT=$(grep -oP '(?<=^)PASS|REJECT-AS-EXPECTED|FAIL' "evidence/${cell}.txt" | tail -1)
    if [[ "$ACTUAL_VERDICT" == "PASS" || "$ACTUAL_VERDICT" == "REJECT-AS-EXPECTED" ]]; then
      VERDICT="$ACTUAL_VERDICT"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  RESULTS+=("$cell: $VERDICT (${CELL_ELAPSED}s)")
  echo ""
done

MATRIX_END=$(date +%s)
MATRIX_ELAPSED=$((MATRIX_END - MATRIX_START))

# Print and write summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
echo "========================================"
echo "  Matrix Summary"
echo "========================================"
echo ""

SUMMARY_FILE="evidence/matrix-summary.txt"
mkdir -p evidence
{
  echo "Matrix run: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "Wall clock: ${MATRIX_ELAPSED}s"
  echo "Total: $TOTAL | Pass: $PASS_COUNT | Fail: $FAIL_COUNT"
  echo ""
  for r in "${RESULTS[@]}"; do
    echo "  $r"
  done
} | tee "$SUMMARY_FILE"

echo ""
echo "Summary written to $SUMMARY_FILE"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
