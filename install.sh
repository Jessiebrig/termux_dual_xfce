#!/bin/bash

# Termux XFCE Installer Launcher
# This script fetches available branches and downloads the setup script

set -euo pipefail

REPO_OWNER="Jessiebrig"
REPO_NAME="termux_dual_xfce"
SCRIPT_NAME="termux-xfce-dual-setup.sh"

echo ""
echo "┌────────────────────────────────────┐"
echo "│   Termux XFCE Installer Launcher   │"
echo "└────────────────────────────────────┘"
echo ""

# Fetch available branches dynamically
echo "Fetching available branches..."
BRANCHES=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/branches" | grep '"name":' | cut -d'"' -f4)

if [[ -z "$BRANCHES" ]]; then
    echo "Error: Failed to fetch branches. Check your internet connection."
    exit 1
fi

# Display branches
echo ""
echo "Available branches:"
i=1
declare -A branch_map
while IFS= read -r branch; do
    echo "  $i) $branch"
    branch_map[$i]="$branch"
    ((i++))
done <<< "$BRANCHES"

# Get user choice
echo ""
echo -n "Select branch [1]: "
read -r choice
choice=${choice:-1}

SELECTED_BRANCH="${branch_map[$choice]}"
if [[ -z "$SELECTED_BRANCH" ]]; then
    echo "Invalid choice. Defaulting to first branch."
    SELECTED_BRANCH="${branch_map[1]}"
fi

echo ""
echo "Selected: $SELECTED_BRANCH"
echo ""

# Download the setup script
echo "Downloading setup script from $SELECTED_BRANCH..."
SCRIPT_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$SELECTED_BRANCH/$SCRIPT_NAME"

if curl -sL "$SCRIPT_URL" -o "$SCRIPT_NAME"; then
    echo "✓ Downloaded successfully"
    echo ""
    
    # Pass the selected branch to the setup script
    export INSTALLER_BRANCH="$SELECTED_BRANCH"
    bash "$SCRIPT_NAME"
else
    echo "✗ Failed to download setup script from $SELECTED_BRANCH"
    exit 1
fi
