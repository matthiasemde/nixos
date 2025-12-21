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
  
  # Get the diff for this file to find which image references changed
  # Look for any lines with image:tag@sha256:digest pattern
  changed_images=$(git diff "origin/$BASE_BRANCH"...HEAD -- "$flake" | \
    grep -E '^\+.*"[^"]+@sha256:[^"]+"' | \
    sed 's/^+//' | \
    grep -oP '"[^"]+@sha256:[^"]+"' | \
    tr -d '"' || true)
  
  if [ -z "$changed_images" ]; then
    echo "No Docker image references were changed in $flake"
    rm "$temp_file"
    continue
  fi
  
  echo "Changed images:"
  echo "$changed_images"
  echo ""
  
  # Collect all updates to apply at once
  declare -A hash_updates
  
  # Find all image references in the file (pattern: "image:tag@sha256:digest")
  # Use awk to get line numbers and image references
  while IFS='|' read -r line_num image_ref; do
    [ -z "$line_num" ] || [ -z "$image_ref" ] && continue
    
    # Check if this specific image was changed in the PR
    if ! echo "$changed_images" | grep -qF "$image_ref"; then
      continue
    fi
    
    echo ""
    echo -e "${YELLOW}Processing image at line $line_num${NC}"
    echo -e "${YELLOW}Image reference:${NC} $image_ref"
    
    # Parse image components
    # Format: registry/image:tag@sha256:digest
    image_with_tag=$(echo "$image_ref" | sed -E 's/@sha256:.+$//')
    image_name=$(echo "$image_with_tag" | sed -E 's/:([^:]+)$//')
    image_tag=$(echo "$image_with_tag" | sed -E 's/.*:([^:]+)$/\1/')
    image_digest=$(echo "$image_ref" | sed -E 's/.*@(sha256:[a-f0-9]+).*/\1/')
    
    echo -e "${YELLOW}Image name:${NC} $image_name"
    echo -e "${YELLOW}Tag:${NC} $image_tag"
    echo -e "${YELLOW}Digest:${NC} $image_digest"
    
    # Check if we already fetched the hash for this image
    cache_key="${image_name}:${image_tag}@${image_digest}"
    if [ -n "${hash_updates[$cache_key]:-}" ]; then
      nix_hash="${hash_updates[$cache_key]}"
      echo -e "${GREEN}Using cached Nix hash:${NC} $nix_hash"
    else
      # Use nix-prefetch-docker to get the correct SHA256 hash
      echo -e "${YELLOW}Fetching Nix hash...${NC}"
      
      if ! nix_output=$(nix run nixpkgs#nix-prefetch-docker -- \
        --image-name "$image_name" \
        --image-digest "$image_digest" \
        --final-image-tag "$image_tag" 2>&1); then
        echo -e "${RED}Error: Failed to fetch hash for $image_name:$image_tag@$image_digest${NC}"
        echo "$nix_output"
        continue
      fi
      
      # Extract the sha256 hash from the output
      nix_hash=$(echo "$nix_output" | grep -oP 'sha256-[A-Za-z0-9+/=]+' | head -1)
      
      if [ -z "$nix_hash" ]; then
        echo -e "${RED}Warning: Could not extract hash from nix-prefetch-docker output${NC}"
        echo "$nix_output"
        continue
      fi
      
      echo -e "${GREEN}Nix hash:${NC} $nix_hash"
      
      # Cache it
      hash_updates[$cache_key]="$nix_hash"
    fi
    
    # Get the current hash from the original file (not temp_file which may have been modified)
    current_hash=$(sed -n "$((line_num + 1))p" "$flake" | grep -oP 'sha256-[A-Za-z0-9+/=]+' || true)
    
    if [ -z "$current_hash" ]; then
      echo -e "${RED}Warning: Could not find nixSha256 line after image reference at line $line_num${NC}"
      continue
    fi
    
    echo -e "${YELLOW}Current hash:${NC} $current_hash"
    
    # Update the hash if it's different
    if [ "$current_hash" != "$nix_hash" ]; then
      echo -e "${GREEN}✓ Updating hash at line $((line_num + 1))${NC}"
      
      # Use sed to replace the hash at the specific line
      sed -i "$((line_num + 1))s|$current_hash|$nix_hash|" "$temp_file"
      
      CHANGES_MADE=true
    else
      echo -e "${GREEN}✓ Hash is already up to date${NC}"
    fi
    
  done < <(awk '
    /"[^"]+@sha256:[^"]+"/ {
      match($0, /"([^"]+@sha256:[^"]+)"/, arr)
      if (arr[1] != "") {
        print NR "|" arr[1]
      }
    }
  ' "$flake")
  
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
