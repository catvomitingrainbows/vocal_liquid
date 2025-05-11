#!/bin/bash
set -e

echo "=== VocalLiquid Debug Console Watcher ==="
echo "This script will watch console output for VocalLiquid logs"
echo "Press Ctrl+C to exit"
echo

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if the app is running
APP_PID=$(pgrep -f "VocalLiquid" || echo "")
if [ -z "$APP_PID" ]; then
    echo -e "${RED}ERROR: VocalLiquid is not running!${NC}"
    echo "Please start the app first by running it from Xcode"
    exit 1
fi

echo -e "${GREEN}VocalLiquid is running with PID: $APP_PID${NC}"

# Filter log for specific app process
log stream --predicate "process == 'VocalLiquid'" --style compact | while read line; do
    # Color code based on log content
    if echo "$line" | grep -i "error" >/dev/null; then
        echo -e "${RED}$line${NC}"
    elif echo "$line" | grep -i "warn" >/dev/null; then
        echo -e "${YELLOW}$line${NC}"
    elif echo "$line" | grep -i "debug" >/dev/null; then
        echo -e "${BLUE}$line${NC}"
    elif echo "$line" | grep -i "hotkey" >/dev/null; then
        echo -e "${PURPLE}$line${NC}"
    elif echo "$line" | grep -i "icon" >/dev/null; then
        echo -e "${CYAN}$line${NC}"
    else
        echo "$line"
    fi
done