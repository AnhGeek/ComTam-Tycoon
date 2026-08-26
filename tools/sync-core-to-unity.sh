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

# Deliberately not rsync: it is absent from some minimal images (including this
# project's dev container), and cp/find are guaranteed to be there.
# bin/ and obj/ must be excluded: the .NET build drops generated
# AssemblyInfo.cs files there, and copying them into Unity produces duplicate
# assembly-attribute compile errors.
( cd "$SRC" && find . \( -name bin -o -name obj \) -prune -o -name '*.cs' -type f -print0 \
    | while IFS= read -r -d '' f; do
        mkdir -p "$DEST/$(dirname "$f")"
        cp "$f" "$DEST/$f"
      done )

# Unity ships its own IsExternalInit; ours would be a duplicate symbol.
rm -f "$DEST/Util/IsExternalInit.cs"

# Prune any now-empty directories left by deleted source files.
find "$DEST" -type d -empty -delete 2>/dev/null || true

echo "Synced $(find "$DEST" -name '*.cs' | wc -l | tr -d ' ') source files -> $DEST"
echo "Switch to the Unity Editor to trigger a recompile."
