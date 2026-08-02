#!/bin/bash
set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
print_step() { echo "  → $1"; }
abort()       { echo "Error: $1" >&2; exit 1; }

# ── platform ──────────────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin) PLATFORM="darwin" ;;
  Linux)  PLATFORM="linux"  ;;
  *)      abort "unsupported platform." ;;
esac

echo "Uninstalling Multigravity..."
echo ""

REMOVED=0

# ── binary + icon ─────────────────────────────────────────────────────────────
for dir in "/usr/local/bin" "$HOME/.local/bin" "${PREFIX:-}/bin"; do
  [ -z "$dir" ] || [ ! -d "$dir" ] && continue
  for bin in "mgy" "multigravity"; do
    if [ -f "$dir/$bin" ]; then
      print_step "Removing $dir/$bin"
      rm -f "$dir/$bin"
      REMOVED=$((REMOVED + 1))
    fi
  done
  if [ "$PLATFORM" = "darwin" ] && [ -f "$dir/icon.icns" ]; then
    print_step "Removing $dir/icon.icns"
    rm -f "$dir/icon.icns"
  fi
done

# ── desktop shortcuts ─────────────────────────────────────────────────────────
if [ "$PLATFORM" = "darwin" ]; then
  for shortcut in "$HOME/Applications"/Multigravity\ *.app; do
    [ -d "$shortcut" ] || continue
    print_step "Removing shortcut: $shortcut"
    rm -rf "$shortcut"
  done
elif [ "$PLATFORM" = "linux" ]; then
  for entry in "$HOME/.local/share/applications"/multigravity-*.desktop; do
    [ -f "$entry" ] || continue
    print_step "Removing desktop entry: $entry"
    rm -f "$entry"
  done
  launcher_dir="$HOME/.local/share/multigravity/launchers"
  if [ -d "$launcher_dir" ]; then
    print_step "Removing launcher scripts: $launcher_dir"
    rm -rf "$launcher_dir"
  fi
fi

# ── profile data (opt-in) ─────────────────────────────────────────────────────
PROFILE_BASE="${MULTIGRAVITY_HOME:-$HOME/AntigravityProfiles}"
if [ -d "$PROFILE_BASE" ]; then
  echo ""
  read -r -p "Remove all profile data at '$PROFILE_BASE'? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    print_step "Removing profile data: $PROFILE_BASE"
    rm -rf "$PROFILE_BASE"
  else
    echo "  Keeping profile data."
  fi
fi

echo ""
if [ "$REMOVED" -eq 0 ]; then
  echo "Multigravity binary was not found — nothing to remove."
else
  echo "✓ Multigravity uninstalled."
fi
