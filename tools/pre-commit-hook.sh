#!/bin/sh
set -e

# Pre-commit hook to automatically update README.md with directory structure
# This ensures the documentation stays up-to-date with the repository structure

# Check if tree command is available
if ! command -v tree >/dev/null 2>&1; then
  echo "⚠️  Warning: 'tree' command not found. Skipping directory structure update."
  echo "   Install tree to enable automatic README updates."
  exit 0
fi

# Define markers for the directory structure section
START_MARKER="<!-- DIRECTORY_STRUCTURE_START -->"
END_MARKER="<!-- DIRECTORY_STRUCTURE_END -->"

# Generate the directory structure
# Exclude: .git, result*, .cache, tmp, node_modules, and other build artifacts
TREE_OUTPUT=$(tree -a -I '.git|result*|.cache|tmp|node_modules|dist|build|__pycache__|*.pyc')

# Create temporary file for the new README content
TEMP_FILE=$(mktemp)

# Store original README.md content hash for comparison
ORIGINAL_HASH=$(md5sum README.md | cut -d' ' -f1)

# Check if markers exist in README.md
if grep -q "$START_MARKER" README.md && grep -q "$END_MARKER" README.md; then
  # Markers exist, update the section
  awk -v start="$START_MARKER" -v end="$END_MARKER" -v tree="$TREE_OUTPUT" '
    BEGIN { in_section=0 }
    $0 ~ start {
      print $0
      print ""
      print "```"
      print tree
      print "```"
      print ""
      in_section=1
      next
    }
    $0 ~ end {
      in_section=0
      print
      next
    }
    !in_section { print }
  ' README.md > "$TEMP_FILE"
else
  # Markers don't exist, append the section before the last line if it's empty, or at the end
  {
    cat README.md
    echo ""
    echo "$START_MARKER"
    echo ""
    echo '```'
    echo "$TREE_OUTPUT"
    echo '```'
    echo ""
    echo "$END_MARKER"
  } > "$TEMP_FILE"
fi

# Replace README.md with updated content
mv "$TEMP_FILE" README.md

# Check if README.md was actually modified
NEW_HASH=$(md5sum README.md | cut -d' ' -f1)

if [ "$ORIGINAL_HASH" != "$NEW_HASH" ]; then
  # README.md was modified, stage it and abort the commit
  git add README.md
  echo "✅ README.md updated with current directory structure"
  echo "📝 The README.md file has been updated and staged."
  echo "   Please run your commit command again to include the updated directory structure."
  exit 1
else
  # No changes needed
  echo "✅ Directory structure in README.md is already up-to-date"
  exit 0
fi
