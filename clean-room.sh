#!/usr/bin/env bash
# clean-room.sh — a disposable Docker clean-room for from-nothing install/bootstrap tests.
#
# Run with NO args: a self-test that PROVES the flagship claim — a genuinely
#   Python-free base, into which `uv` self-bootstraps a CPython, then tossed.
#   (This is the exact recipe from SKILL.md, verified live on arm64 / Apple Silicon.)
#
#   ./clean-room.sh
#
# The box always tears down (trap on EXIT), even on Ctrl-C or a mid-script failure —
# a lingering "temporary" box is how a disposable estate stops being disposable.
#
# NOTE ON REPRODUCIBILITY: the image tag below is a MOVING target and `apt` pulls
# today's mirror. For a claim you'll cite later, pin by digest:
#   IMAGE='debian:bookworm-slim@sha256:<digest>'
# Otherwise this proves "works on the base as it exists right now", not forever.
set -euo pipefail

IMAGE="${IMAGE:-debian:bookworm-slim}"     # glibc slim base (NOT alpine/musl — see SKILL.md caveats)
BOX="cleanroom-$$"                          # $$ = PID; unique per run, safe in parallel
cleanup() { docker rm -f "$BOX" >/dev/null 2>&1 || true; }
trap cleanup EXIT                           # self-disarming: box dies no matter how we leave

say() { printf '\n\033[1;36m== %s ==\033[0m\n' "$*"; }

say "1. launch clean base ($IMAGE) — deliberately WITHOUT Python"
docker run -d --name "$BOX" "$IMAGE" sleep infinity >/dev/null
ARCH="$(docker exec "$BOX" uname -m)"
echo "   box arch: $ARCH   (proving on this arch ONLY — say so; x86 needs --platform linux/amd64 + QEMU)"

say "2. canary: prove python3 is genuinely absent (honest pre-check)"
if docker exec "$BOX" bash -c 'command -v python3' >/dev/null 2>&1; then
  echo "   ✗ python3 IS present — this base is not a 'no Python' clean-room"; exit 1
fi
echo "   ✓ python3 not on PATH — the absence is real"

say "3. provision only what a realistic fresh box has (curl, ca-certs) — NOT the thing under test"
docker exec "$BOX" bash -c 'apt-get update -qq && apt-get install -y -qq curl ca-certificates >/dev/null 2>&1'
echo "   ✓ provisioned curl + ca-certificates"

say "4. flagship: does uv self-bootstrap a Python from NOTHING?"
docker exec -i "$BOX" bash -c '
  set -e
  export HOME=/root
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  export PATH=/root/.local/bin:$PATH
  uv python install 3.12 >/dev/null 2>&1
  echo -n "   ✓ uv pulled CPython with zero preinstalled python: "
  uv run --python 3.12 python -c "import sys; print(sys.version.split()[0])"
'

say "5. toss (tossable is the whole point — the trap also guarantees this)"
cleanup; trap - EXIT
echo "   ✓ box removed"
printf '\n\033[1;32mPASS\033[0m — userland-from-nothing verified on %s. (Whole-machine claims: see SKILL.md boundary.)\n' "$ARCH"
