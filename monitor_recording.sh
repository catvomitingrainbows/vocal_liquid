#!/bin/bash
set -e

echo "=== VocalLiquid Recording Monitor ==="
echo "This script will help you monitor the recording state of VocalLiquid"
echo "Press Ctrl+C to exit"

# Path to the log file
LOG_FILE="$HOME/Library/Application Support/VocalLiquid/Logs/vocalliquid_$(date '+%Y-%m-%d').log"

if [ ! -f "$LOG_FILE" ]; then
  echo "Log file not found at: $LOG_FILE"
  echo "Make sure VocalLiquid is running and has created log files"
  exit 1
fi

echo "Monitoring log file: $LOG_FILE"
echo "-------------------------------------"
echo "Press Command+Shift+R to toggle recording..."
echo

# Tail the log file
tail -f "$LOG_FILE" | grep --color=always -E "Recording started|Recording stopped|permission|ERROR|WARN"