#!/usr/bin/env bash
# tools/push_itch.sh — DLV1 (F5): export the "Web" preset and push it to itch.io via butler.
#
# Local sibling of nightly.yml's export-and-publish job, for a hand-shipped playtest build.
# Pushes the HTML5 web build to qusto/the-far-yard:html5 (the Director's browser feel-read;
# the page is password/restricted-gated). The Windows build stays the proven telemetry vehicle;
# web telemetry is retrieved by DLV2's in-game "Export telemetry" download button.
#
# AUTH (secret discipline — NEVER printed or committed):
#   - Prefers BUTLER_API_KEY already in the env (so CI passes its repo secret straight through).
#   - Else reads the value under the "# Itch.io" header in the gitignored APIKEYS.md.
#   The key is exported to butler only; it is never echoed. APIKEYS.md is gitignored — never commit it.
#
# PREREQUISITES (one-time; see SETUP.md §1):
#   - butler on PATH                  (~/.local/bin/butler)
#   - Godot 4.6.3 export templates     (~/.local/share/godot/export_templates/4.6.3.stable/)
#   - the itch project qusto/the-far-yard created, set HTML/playable-in-browser,
#     Restricted/Draft + project password, with the "SharedArrayBuffer support" toggle ON.
#   NOTE: the threaded web build runs reliably only in CHROMIUM (Chrome/Edge); Firefox lacks
#   the `credentialless` COEP scheme itch serves. Play the build in Chrome/Edge.
#
# USAGE:  bash tools/push_itch.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

ITCH_TARGET="qusto/the-far-yard:html5"   # F5 real slug (personal acct; :html5 channel)
EXPORT_PRESET="Web"
EXPORT_DIR="build/web"

# --- 0. tooling sanity ----------------------------------------------------------
command -v butler >/dev/null 2>&1 || { echo "ERROR: butler not on PATH — see SETUP.md §1." >&2; exit 1; }
command -v godot  >/dev/null 2>&1 || { echo "ERROR: godot not on PATH (export PATH=\$HOME/.local/bin:\$PATH)." >&2; exit 1; }

# --- 1. stamp the build id the same way CI does (BuildVersion reads build_info_gen.gd) ---
bash tools/stamp_build.sh
SHA="$(git rev-parse --short HEAD)"
USER_VERSION="m1-$(date -u +%Y%m%d)-${SHA}"

# --- 2. export the Web preset (templates must be installed) ----------------------
mkdir -p "$EXPORT_DIR"
godot --headless --path . --export-release "$EXPORT_PRESET" "$EXPORT_DIR/index.html"
# A produced file is the minimum proof — a partial export can still emit, but a MISSING
# entry file is a hard fail. Also require the wasm + pck (the load-bearing payload).
test -f "$EXPORT_DIR/index.html" || { echo "ERROR: export produced no $EXPORT_DIR/index.html" >&2; exit 1; }
test -f "$EXPORT_DIR/index.wasm" || { echo "ERROR: export produced no $EXPORT_DIR/index.wasm" >&2; exit 1; }
test -f "$EXPORT_DIR/index.pck"  || { echo "ERROR: export produced no $EXPORT_DIR/index.pck"  >&2; exit 1; }

# --- 3. resolve the itch key WITHOUT printing it --------------------------------
if [ -z "${BUTLER_API_KEY:-}" ]; then
  if [ -f APIKEYS.md ]; then
    # Take the last whitespace-token of the first non-empty, non-comment line under the
    # "# Itch.io" header. Handles both `label value` and `key: value` shapes. Never echoed.
    BUTLER_API_KEY="$(awk '
      /^[[:space:]]*#[[:space:]]*Itch\.io/ {f=1; next}
      f && /^[[:space:]]*#/ {exit}
      f && NF {print $NF; exit}
    ' APIKEYS.md)"
  fi
fi
[ -n "${BUTLER_API_KEY:-}" ] || {
  echo "ERROR: no itch key — set BUTLER_API_KEY in the env or add an '# Itch.io' entry to APIKEYS.md." >&2
  exit 1
}
export BUTLER_API_KEY

# --- 4. push the DIRECTORY to the :html5 channel --------------------------------
butler push "$EXPORT_DIR" "$ITCH_TARGET" --userversion "$USER_VERSION"
echo "pushed ${ITCH_TARGET} @ ${USER_VERSION}"
