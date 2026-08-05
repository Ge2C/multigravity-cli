#!/data/data/com.termux/files/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Multigravity CLI Automated Test Suite
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MULTIGRAVITY="$SCRIPT_DIR/multigravity"
TEST_BASE=$(mktemp -d)

cleanup() {
  rm -rf "$TEST_BASE"
}
trap cleanup EXIT

echo "=================================================="
echo " Running Multigravity CLI Regression Test Suite"
echo "=================================================="
echo ""

# 1. Syntax Check
echo "[1/7] Testing script syntax..."
bash -n "$MULTIGRAVITY"
echo "  ✓ Syntax valid"

# 2. CLI Detection Unit Test
echo "[2/7] Testing CLI detection (is_cli_app)..."
bash -c "
  eval \"\$(grep -A15 'is_cli_app()' '$MULTIGRAVITY')\"
  is_cli_app agy || exit 1
  is_cli_app /usr/bin/agy || exit 1
  is_cli_app antigravity-cli || exit 1
  if is_cli_app Antigravity.app; then exit 1; fi
  if is_cli_app Antigravity.AppImage; then exit 1; fi
"
echo "  ✓ is_cli_app correctly identifies CLI vs IDE applications"

# 3. Profile Creation & Storage Isolation
echo "[3/7] Testing profile creation..."
MULTIGRAVITY_HOME="$TEST_BASE" "$MULTIGRAVITY" new p-standard >/dev/null
if [ ! -d "$TEST_BASE/p-standard" ]; then
  echo "  ✗ Profile directory was not created!"
  exit 1
fi
echo "  ✓ Standard profile created successfully"

# 4. Shared Profile Layout & CLI Symlinks
echo "[4/7] Testing shared profile symlink layout..."
MULTIGRAVITY_HOME="$TEST_BASE" "$MULTIGRAVITY" new p-shared --shared >/dev/null

if [ ! -f "$TEST_BASE/p-shared/.shared" ]; then
  echo "  ✗ Shared marker file missing!"
  exit 1
fi

# Simulate system config directory
mkdir -p "$HOME/.gemini/config/plugins"
touch "$HOME/.gemini/config/mcp_config.json"
touch "$HOME/.gemini/config/config.json"

# Trigger shared layout sync via status/launch
MULTIGRAVITY_HOME="$TEST_BASE" "$MULTIGRAVITY" status >/dev/null

if [ -d "$HOME/.gemini/config/plugins" ]; then
  if [ ! -L "$TEST_BASE/p-shared/.gemini/config/plugins" ]; then
    echo "  ✗ Shared CLI plugins symlink missing in profile!"
    exit 1
  fi
fi

# Verify auto-shared history symlink if system brain exists
mkdir -p "$HOME/.gemini/antigravity-cli/brain"
MULTIGRAVITY_HOME="$TEST_BASE" "$MULTIGRAVITY" new p-shared-hist --shared >/dev/null
if [ -d "$HOME/.gemini/antigravity-cli/brain" ]; then
  if [ ! -L "$TEST_BASE/p-shared-hist/.gemini/antigravity-cli/brain" ]; then
    echo "  ✗ Auto-shared history (brain) symlink missing in shared profile!"
    exit 1
  fi
fi

# Verify mgy sync command between isolated profiles
mkdir -p "$TEST_BASE/p-standard/.gemini/antigravity-cli/brain"
echo "test-history-log" > "$TEST_BASE/p-standard/.gemini/antigravity-cli/brain/log.txt"
MULTIGRAVITY_HOME="$TEST_BASE" "$MULTIGRAVITY" sync p-standard p-shared >/dev/null
if [ ! -f "$TEST_BASE/p-shared/.gemini/antigravity-cli/brain/log.txt" ]; then
  echo "  ✗ mgy sync failed to sync history between profiles!"
  exit 1
fi
echo "  ✓ Shared profile symlinks and mgy sync verified"

# 5. Security & Path Traversal Guard
echo "[5/7] Testing path traversal protection..."
if MULTIGRAVITY_HOME="$TEST_BASE" "$MULTIGRAVITY" new p-exploit --from "../p-standard" 2>/dev/null; then
  echo "  ✗ Path traversal via --from was NOT blocked!"
  exit 1
fi
echo "  ✓ Path traversal attack blocked correctly"

# 6. Status and List commands
echo "[6/7] Testing list and status output..."
PROFILES=$(MULTIGRAVITY_HOME="$TEST_BASE" "$MULTIGRAVITY" list --raw)
if [[ "$PROFILES" != *"p-standard"* ]] || [[ "$PROFILES" != *"p-shared"* ]]; then
  echo "  ✗ List output missing expected profiles!"
  exit 1
fi
echo "  ✓ List and status outputs verified"

# 7. Mock Launch Test (Flag filtering for CLI)
echo "[7/7] Testing launch environment & flag isolation for CLI..."
MOCK_APP="$TEST_BASE/bin/agy"
mkdir -p "$TEST_BASE/bin"
cat << 'EOF' > "$MOCK_APP"
#!/data/data/com.termux/files/usr/bin/env bash
for arg in "$@"; do
  if [[ "$arg" == "--user-data-dir"* ]] || [[ "$arg" == "--extensions-dir"* ]]; then
    echo "FAIL: IDE flag passed to CLI: $arg" >&2
    exit 2
  fi
done
echo "MOCK_LAUNCH_SUCCESS"
EOF
chmod +x "$MOCK_APP"

LAUNCH_OUT=$(MULTIGRAVITY_HOME="$TEST_BASE" MULTIGRAVITY_APP="$MOCK_APP" "$MULTIGRAVITY" p-standard 2>&1)
if [[ "$LAUNCH_OUT" != *"MOCK_LAUNCH_SUCCESS"* ]]; then
  echo "  ✗ Launch failed or passed invalid IDE flags!"
  echo "$LAUNCH_OUT"
  exit 1
fi
echo "  ✓ Launch flag filtering verified"

echo ""
echo "=================================================="
echo " ✓ ALL 7 REGRESSION TESTS PASSED SUCCESSFULLY!"
echo "=================================================="
