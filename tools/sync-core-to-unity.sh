#!/usr/bin/env bash
# Mirrors src/ComTam.Core into the Unity project.
#
# Core is consumed by Unity as SOURCE (not a prebuilt DLL) so that step-through
# debugging works and there is no build-order dependency. The .csproj is excluded
# because Unity generates its own project files from the .asmdef.
#
# Run this after changing anything in src/ComTam.Core, then let Unity recompile.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_ROOT/src/ComTam.Core"
DEST="$REPO_ROOT/unity/ComTamTycoon/Assets/_Project/Core"

if [[ ! -d "$SRC" ]]; then
  echo "error: $SRC not found" >&2
  exit 1
fi

mkdir -p "$DEST"

# Keep the asmdef (and Unity's .meta files); replace everything else.
find "$DEST" -name '*.cs' -type f -delete

rsync -a \
  --include='*/' \
  --include='*.cs' \
  --exclude='*' \
  --prune-empty-dirs \
  "$SRC/" "$DEST/"

# Unity ships its own IsExternalInit; ours would be a duplicate symbol.
rm -f "$DEST/Util/IsExternalInit.cs"

echo "Synced $(find "$DEST" -name '*.cs' | wc -l | tr -d ' ') source files -> $DEST"
echo "Switch to the Unity Editor to trigger a recompile."
