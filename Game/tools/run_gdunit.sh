#!/usr/bin/env bash
# G2 — headless GdUnit4 runner for THE FAR YARD.
#
# Runs the vendored GdUnit4 CLI over res://tests and exits non-zero on any failed
# or aborted test, so it can gate CI and a local pre-commit check identically.
#
# Usage:
#   tools/run_gdunit.sh                 # run all of res://tests
#   tools/run_gdunit.sh res://tests/economy   # run a subdir
#   GODOT_BIN=/path/to/godot tools/run_gdunit.sh
#
# Notes:
#   - --ignoreHeadlessMode: our logic suites never use InputEvents, so the headless
#     UI-input warning does not apply; this flag lets the runner proceed headless.
#   - Exit codes (GdUnitTestCIRunner): 0 = all green, 100 = test failure/error,
#     101 = orphan-node warning, 103 = headless refused. The CI gate treats any
#     non-zero as a failure.

set -uo pipefail

GODOT="${GODOT_BIN:-godot}"
TEST_PATH="${1:-res://tests}"

"$GODOT" --headless --path . \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode \
  -a "$TEST_PATH"
code=$?

if [ "$code" -ne 0 ]; then
  echo "GdUnit4 run FAILED (exit $code)"
  exit "$code"
fi
echo "GdUnit4 run PASSED"
exit 0
