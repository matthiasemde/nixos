#!/bin/sh
set -e

# Installation script for the pre-commit hook
# This script copies the pre-commit hook to .git/hooks/ and makes it executable

HOOK_SOURCE="tools/pre-commit-hook.sh"
HOOK_DEST=".git/hooks/pre-commit"

echo "🔧 Installing pre-commit hook..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
  echo "❌ Error: Not in a git repository root directory."
  echo "   Please run this script from the repository root."
  exit 1
fi

# Check if the hook source file exists
if [ ! -f "$HOOK_SOURCE" ]; then
  echo "❌ Error: Hook source file '$HOOK_SOURCE' not found."
  exit 1
fi

# Create .git/hooks directory if it doesn't exist
if [ ! -d ".git/hooks" ]; then
  echo "📁 Creating .git/hooks directory..."
  mkdir -p .git/hooks
fi

# Check if a pre-commit hook already exists
if [ -f "$HOOK_DEST" ]; then
  echo "⚠️  Warning: Pre-commit hook already exists."
  echo "   Backing up existing hook to $HOOK_DEST.backup"
  mv "$HOOK_DEST" "$HOOK_DEST.backup"
fi

# Copy the hook
echo "📋 Copying hook to $HOOK_DEST..."
cp "$HOOK_SOURCE" "$HOOK_DEST"

# Make the hook executable
echo "🔐 Making hook executable..."
chmod +x "$HOOK_DEST"

# Check if tree is installed
if command -v tree >/dev/null 2>&1; then
  echo "✅ Installation complete!"
  echo "   The pre-commit hook will automatically update README.md with the directory structure."
else
  echo "✅ Installation complete!"
  echo "   ⚠️  Note: 'tree' command not found. The hook will skip updates until tree is installed."
  echo "   To install tree on NixOS, add 'tree' to your system packages or run:"
  echo "   nix-shell -p tree"
fi

echo ""
echo "The hook will run automatically on each commit."
echo "If the directory structure changes, the hook will:"
echo "  1. Update README.md with the new structure"
echo "  2. Stage the updated README.md"
echo "  3. Abort the commit with a message to commit again"
echo ""
echo "This ensures the updated README.md is included in your commit."
echo "To temporarily skip the hook, use: git commit --no-verify"

exit 0
