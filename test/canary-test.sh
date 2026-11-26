#!/usr/bin/env bash
# Regression: the step-2 canary must not report "absent" when it simply could not run.
# python:3.12-alpine HAS python3 but no bash, so a bash-based canary errors out and
# used to be read as "python3 not on PATH". Stops at step 2, so it takes seconds.
set -uo pipefail
cd "$(dirname "$0")/.."
out="$(IMAGE=python:3.12-alpine ./clean-room.sh 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'Python IS present' <<<"$out" && ! grep -q 'absence is real' <<<"$out"; then
  echo "PASS: canary caught python3 on a bash-less image"
else
  echo "FAIL (rc=$rc):"; echo "$out"; exit 1
fi
