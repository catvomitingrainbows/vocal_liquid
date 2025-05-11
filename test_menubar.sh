#!/bin/bash
set -e

echo "=== Building and running simple menu bar test ==="

# Compile the Swift file
echo "Compiling SimpleStatusBar.swift..."
swiftc -o SimpleStatusBarTest SimpleStatusBar.swift

# Make it executable
chmod +x SimpleStatusBarTest

# Run it
echo "Running test app..."
echo "Use Command-Shift-R to toggle recording, or use the menu"
echo "Press Ctrl+C to quit"
./SimpleStatusBarTest