#!/bin/bash
set -euo pipefail

REPO="sujitagarwal/multigravity-cli"
BRANCH="main"
RAW="https://raw.githubusercontent.com/$REPO/$BRANCH"
INSTALL_DIR="/usr/local/bin"

# ── helpers ──────────────────────────────────────────────────────────────────
print_step () { echo "  → $1"; }
abort ()       { echo "Error: $1" >&2; exit 1; }

# ── platform ─────────────────────────────────────────────────────────────────
case "$(uname -s)" in
  Darwin)
    PLATFORM="darwin"
    ;;
  Linux)
    PLATFORM="linux"
    ;;
  *)
    abort "unsupported platform. Multigravity currently supports macOS and Linux."
    ;;
esac

# ── preflight ────────────────────────────────────────────────────────────────
command -v curl &>/dev/null || abort "curl is required but not found"

# fall back to $PREFIX/bin (Termux) or ~/.local/bin if /usr/local/bin isn't writable
if [ -n "${PREFIX:-}" ] && [ -w "$PREFIX/bin" ]; then
  INSTALL_DIR="$PREFIX/bin"
elif [ ! -w "$INSTALL_DIR" ]; then
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"

  # auto-add to PATH in the user's shell profile if not already there
  if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    case "${SHELL:-}" in
      */zsh)  SHELL_RC="$HOME/.zshrc" ;;
      */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
      *)      SHELL_RC="$HOME/.bashrc" ;;
    esac

    LINE='export PATH="$HOME/.local/bin:$PATH"'

    if [ "$SHELL_RC" = "$HOME/.config/fish/config.fish" ]; then
      LINE='fish_add_path "$HOME/.local/bin"'
    fi

    if ! grep -qF "$HOME/.local/bin" "$SHELL_RC" 2>/dev/null; then
      echo "" >> "$SHELL_RC"
      echo "# Added by Multigravity installer" >> "$SHELL_RC"
      echo "$LINE" >> "$SHELL_RC"
      print_step "Added $INSTALL_DIR to PATH in $SHELL_RC"
    fi

    # apply to current session so the next commands in this script work
    export PATH="$INSTALL_DIR:$PATH"
  fi
fi

echo "Installing Multigravity to $INSTALL_DIR ..."

# ── download multigravity script ─────────────────────────────────────────────
print_step "Downloading multigravity..."
curl -fsSL "$RAW/multigravity" -o "$INSTALL_DIR/multigravity"
chmod +x "$INSTALL_DIR/multigravity"

# ── create mgy alias symlink ──────────────────────────────────────────────────
print_step "Creating mgy alias..."
ln -sf "$INSTALL_DIR/multigravity" "$INSTALL_DIR/mgy" 2>/dev/null || cp "$INSTALL_DIR/multigravity" "$INSTALL_DIR/mgy"

# ── download macOS icon ──────────────────────────────────────────────────────
if [ "$PLATFORM" = "darwin" ]; then
  print_step "Downloading icon..."
  curl -fsSL "$RAW/icon.icns" -o "$INSTALL_DIR/icon.icns"
fi

echo ""
echo "✓ Multigravity installed successfully!"
echo ""
echo "Reload your shell to apply PATH changes:"
echo "  source ~/.zshrc   (or ~/.bashrc, or open a new terminal)"
echo ""
echo "Usage (using 'mgy' or 'multigravity'):"
echo "  mgy help              (or: multigravity help)"
echo "  mgy new <profile>     (or: multigravity new <profile>)"
echo "  mgy <profile>         (or: multigravity <profile>)"

if [ "$PLATFORM" = "linux" ] && ! command -v antigravity &>/dev/null && [ ! -x /usr/share/antigravity/antigravity ]; then
  echo ""
  echo "Note:"
  echo "  Antigravity was not found on this machine."
  echo "  Install Antigravity for Linux and ensure 'antigravity' is on PATH,"
  echo "  or launch Multigravity with MULTIGRAVITY_APP=/path/to/antigravity."
fi
