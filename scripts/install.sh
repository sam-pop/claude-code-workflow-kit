#!/usr/bin/env bash
# Copy the kit into a repo without overwriting anything that already exists.
# Usage: scripts/install.sh /path/to/repo
set -euo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:?usage: install.sh /path/to/repo}"
[[ -d "$TARGET" ]] || { echo "not a directory: $TARGET"; exit 1; }

copy() {
  local rel="$1" src="$KIT/$1" dst="$TARGET/$1"
  if [[ -e "$dst" ]]; then
    echo "exists, kept:   $rel   (kit copy saved as $rel.kit)"
    cp "$src" "$dst.kit"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "installed:      $rel"
  fi
}

while IFS= read -r f; do
  rel="${f#"$KIT"/}"
  [[ "$rel" == "scripts/install.sh" || "$rel" == "LICENSE" ]] && continue
  copy "$rel"
done < <(find "$KIT" -type f ! -path '*/.git/*')

chmod +x "$TARGET/scripts/check.sh"
echo
echo "Next: open Claude Code in $TARGET and say: Read TAILOR.md and tailor the kit to this repo."
echo "Any *.kit files are the kit's version of a file you already had; merge by hand, then delete them."
