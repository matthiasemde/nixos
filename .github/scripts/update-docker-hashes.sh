#!/usr/bin/env bash

set -uo pipefail  # Don't use -e, we want to handle errors ourselves

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track if any changes were made
CHANGES_MADE=false

echo "Starting Docker image hash update process..."

# Get the base branch (usually main or master)
BASE_BRANCH="${GITHUB_BASE_REF:-main}"
echo "Comparing against base branch: $BASE_BRANCH"

# Find only the service flake.nix files that were modified in this PR
modified_flakes=$(git diff --name-only "origin/$BASE_BRANCH"...HEAD | grep -E '^services/.*/flake\.nix$' || true)

if [ -z "$modified_flakes" ]; then
  echo "No service flake.nix files were modified in this PR"
  exit 1
fi

echo "Modified flake files:"
echo "$modified_flakes"

# Process each modified flake file
for flake in $modified_flakes; do
  if [ ! -f "$flake" ]; then
    continue
  fi
  
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Processing: $flake"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Create a temporary file for storing the updated content
  temp_file=$(mktemp)
  cp "$flake" "$temp_file"
  
  # Get the diff for this file to find which lines changed
  # We're looking for changes to RawImageReference lines
  changed_image_refs=$(git diff "origin/$BASE_BRANCH"...HEAD -- "$flake" | \
    grep -E '^\+.*RawImageReference.*=.*".*@sha256:' | \
    sed 's/^+//' || true)
  
  if [ -z "$changed_image_refs" ]; then
    echo "No Docker image references were changed in $flake"
    rm "$temp_file"
    continue
  fi
  
  # Extract all Docker image references from the file
  # Pattern: rawImageReference = "image:tag@sha256:digest";
  while IFS= read -r line; do
    # Check if this specific line was changed in the PR
    # by comparing against the changed_image_refs we found earlier
    line_trimmed=$(echo "$line" | sed 's/^[[:space:]]*//')
    
    # Check if this image reference was actually changed in the diff
    if ! echo "$changed_image_refs" | grep -qF "$line_trimmed"; then
      # This image wasn't changed, skip it
      continue
    fi
    
    echo ""
    echo -e "${YELLOW}Processing changed image reference${NC}"
    
    # Extract the full image reference
    image_ref=$(echo "$line" | sed -E 's/.*"([^"]+)".*/\1/')
    
    # Parse image components
    # Format: registry/image:tag@sha256:digest
    image_with_tag=$(echo "$image_ref" | sed -E 's/@sha256:.+$//')
    image_name=$(echo "$image_with_tag" | sed -E 's/:([^:]+)$//')
    image_tag=$(echo "$image_with_tag" | sed -E 's/.*:([^:]+)$/\1/')
    image_digest=$(echo "$image_ref" | sed -E 's/.*@(sha256:[a-f0-9]+).*/\1/')
    
    echo ""
    echo -e "${YELLOW}Image:${NC} $image_name"
    echo -e "${YELLOW}Tag:${NC} $image_tag"
    echo -e "${YELLOW}Digest:${NC} $image_digest"
    
    # Use nix-prefetch-docker to get the correct SHA256 hash
    echo -e "${YELLOW}Fetching Nix hash...${NC}"
    
    # Run nix-prefetch-docker and capture output
    if ! nix_output=$(nix run nixpkgs#nix-prefetch-docker -- \
      --image-name "$image_name" \
      --image-digest "$image_digest" \
      --final-image-tag "$image_tag" 2>&1); then
      echo -e "${RED}Error: Failed to fetch hash for $image_name:$image_tag@$image_digest${NC}"
      echo "$nix_output"
      continue
    fi
    
    # Extract the sha256 hash from the output
    # nix-prefetch-docker outputs the hash in the format: sha256-...
    nix_hash=$(echo "$nix_output" | grep -oP 'sha256-[A-Za-z0-9+/=]+' | head -1)
    
    if [ -z "$nix_hash" ]; then
      echo -e "${RED}Warning: Could not extract hash from nix-prefetch-docker output${NC}"
      echo "$nix_output"
      continue
    fi
    
    echo -e "${GREEN}Nix hash:${NC} $nix_hash"
    
    # Find the current hash - look for the nixSha256 line immediately following this rawImageReference
    current_hash=$(awk -v line_num="$(grep -n "rawImageReference = \"$image_ref\"" "$temp_file" | cut -d: -f1 | head -1)" '
      NR > line_num && /nixSha256 = "sha256-/ {
        match($0, /nixSha256 = "([^"]+)"/, arr)
        print arr[1]
        exit
      }
    ' "$temp_file")
    
    if [ -z "$current_hash" ]; then
      echo -e "${RED}Warning: Could not find current hash for rawImageReference in $flake${NC}"
      continue
    fi
    
    echo -e "${YELLOW}Current hash:${NC} $current_hash"
    
    # Update the hash if it's different
    if [ "$current_hash" != "$nix_hash" ]; then
      echo -e "${GREEN}✓ Updating hash${NC}"
      
      # Use awk to find and replace the nixSha256 line immediately following the rawImageReference
      awk -v image_ref="$image_ref" -v new_hash="$nix_hash" '
        /rawImageReference = "'"$image_ref"'"/ {
          found_ref = 1
          print
          next
        }
        found_ref && /nixSha256 = "sha256-/ {
          sub(/nixSha256 = "sha256-[^"]+";/, "nixSha256 = \"" new_hash "\";")
          found_ref = 0
          print
          next
        }
        { print }
      ' "$temp_file" > "${temp_file}.new" && mv "${temp_file}.new" "$temp_file"
      
      CHANGES_MADE=true
    else
      echo -e "${GREEN}✓ Hash is already up to date${NC}"
    fi
    
  done < <(grep -E '^[[:space:]]*rawImageReference[[:space:]]*=[[:space:]]*"[^"]+@sha256:[^"]+"' "$flake")
  
  # If changes were made to this file, update it
  if ! cmp -s "$flake" "$temp_file"; then
    mv "$temp_file" "$flake"
    echo -e "${GREEN}✓ Updated $flake${NC}"
  else
    rm "$temp_file"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$CHANGES_MADE" = true ]; then
  echo -e "${GREEN}✓ Hash updates complete - changes were made${NC}"
  echo "CHANGES_MADE=true"
  exit 0
else
  echo -e "${YELLOW}✓ Hash updates complete - no changes needed${NC}"
  echo "CHANGES_MADE=false"
  exit 1
fi
