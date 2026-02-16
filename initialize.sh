#!/bin/bash

# Termux Dual XFCE Setup Initializer
# This script fetches available branches and downloads the setup script

set -euo pipefail

REPO_OWNER="Jessiebrig"
REPO_NAME="termux_dual_xfce"
SCRIPT_NAME="termux-xfce-dual-setup.sh"

echo ""
echo "┌────────────────────────────────────┐"
echo "│ Termux Dual XFCE Setup Initializer │"
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

# Sort branches: main first, then others alphabetically
if echo "$BRANCHES" | grep -q '^main$'; then
    # Main exists, add it first
    commit_data=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/main")
    commit_msg=$(echo "$commit_data" | grep -m1 '"message":' | cut -d'"' -f4 | head -c 40)
    commit_datetime=$(echo "$commit_data" | grep '"date":' | head -1 | cut -d'"' -f4)
    commit_date=$(date -d "$commit_datetime" '+%Y-%m-%d' 2>/dev/null || echo "$commit_datetime" | cut -d'T' -f1)
    commit_time=$(date -d "$commit_datetime" '+%H:%M' 2>/dev/null || echo "$commit_datetime" | cut -d'T' -f2 | cut -d':' -f1,2)
    [[ ${#commit_msg} -eq 40 ]] && commit_msg="${commit_msg}..."
    
    echo "  $i) main - $commit_msg ($commit_date $commit_time)"
    branch_map[$i]="main"
    ((i++))
fi

# Add other branches alphabetically
while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    [[ "$branch" == "main" ]] && continue
    
    # Fetch last commit message and date for this branch
    commit_data=$(curl -s "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits/$branch")
    commit_msg=$(echo "$commit_data" | grep -m1 '"message":' | cut -d'"' -f4 | head -c 40)
    commit_datetime=$(echo "$commit_data" | grep '"date":' | head -1 | cut -d'"' -f4)
    commit_date=$(date -d "$commit_datetime" '+%Y-%m-%d' 2>/dev/null || echo "$commit_datetime" | cut -d'T' -f1)
    commit_time=$(date -d "$commit_datetime" '+%H:%M' 2>/dev/null || echo "$commit_datetime" | cut -d'T' -f2 | cut -d':' -f1,2)
    [[ ${#commit_msg} -eq 40 ]] && commit_msg="${commit_msg}..."
    
    echo "  $i) $branch - $commit_msg ($commit_date $commit_time)"
    branch_map[$i]="$branch"
    ((i++))
done <<< "$(echo "$BRANCHES" | grep -v '^main$' | sort)"

# Get user choice
echo "" > /dev/tty
echo -n "Select branch [1]: " > /dev/tty
read -r choice < /dev/tty
choice=${choice:-1}

SELECTED_BRANCH="${branch_map[$choice]:-}"
if [[ -z "$SELECTED_BRANCH" ]]; then
    echo "Invalid choice. Defaulting to first branch."
    SELECTED_BRANCH="${branch_map[1]}"
fi

echo ""
echo "Selected: $SELECTED_BRANCH"
echo ""

# Generic download function
download_file() {
    local url="$1"
    local dest="$2"
    local name="$3"
    
    echo -n "Downloading $name... "
    if curl -sL "$url" -o "$dest" 2>/dev/null; then
        echo "✓"
        return 0
    else
        echo "✗"
        return 1
    fi
}

# Download files from selected branch
echo "Downloading files from $SELECTED_BRANCH:"
echo ""

SCRIPT_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$SELECTED_BRANCH/$SCRIPT_NAME"
XRUN_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$SELECTED_BRANCH/xrun"

download_file "$SCRIPT_URL" "$SCRIPT_NAME" "Setup script" || { echo "Error: Failed to download setup script"; exit 1; }

# Verify the script file exists and has content
if [[ ! -f "$SCRIPT_NAME" ]] || [[ ! -s "$SCRIPT_NAME" ]]; then
    echo "✗ Error: Script file not found or empty"
    exit 1
fi

if download_file "$XRUN_URL" "$PREFIX/bin/xrun" "xrun utility"; then
    chmod +x "$PREFIX/bin/xrun"
    cp "$PREFIX/bin/xrun" "$HOME/xrun" 2>/dev/null && chmod +x "$HOME/xrun" || true
else
    echo "Error: Failed to download xrun utility"
    exit 1
fi

echo ""

# Restore terminal state
exec < /dev/tty

# Prompt user to run setup or xrun
echo "[DEBUG] About to show tip"
echo "Tip: Setup script skips already installed packages but will run from the start."
echo "[DEBUG] About to show prompt"
echo -n "Run setup? (Y/n): "
echo "[DEBUG] About to read response"



read -r response
echo "[DEBUG] Got response: $response"

if [[ "$response" =~ ^[Nn]$ ]]; then
    echo "Setup skipped. Running xrun..."
    export INSTALLER_BRANCH="$SELECTED_BRANCH"
    xrun
else
    export INSTALLER_BRANCH="$SELECTED_BRANCH"
    bash "$SCRIPT_NAME"
fi
