#!/bin/bash
set -e

echo "=== Building Icon-Only Test App ==="
echo "This is the absolute simplest test focused only on the orange icon issue"

# Kill any existing instances
pkill -f IconOnly 2>/dev/null || true

# Compile
swiftc -o IconOnly IconOnly.swift

# Make executable
chmod +x IconOnly

# Run
echo "Running IconOnly test app..."
echo "Use the menu to control icon states:"
echo "1. Turn Red = Set icon to red/orange"
echo "2. Turn Normal = Try to reset icon to normal"
echo "3. Replace Status Item = Nuclear option that should always work"
./IconOnly