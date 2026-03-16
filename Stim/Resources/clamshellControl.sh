#!/bin/bash
# clamshellControl.sh — Stim clamshell sleep control
# Installed to ~/Library/Application Scripts/com.steins.stim/
# Called via NSUserUnixTask from sandboxed app

case "$1" in
    enable)
        # Disable clamshell sleep (keep awake when lid closed)
        sudo /usr/bin/pmset disablesleep 1
        ;;
    disable)
        # Re-enable clamshell sleep (normal behavior)
        sudo /usr/bin/pmset disablesleep 0
        ;;
    status)
        # Check current state
        /usr/bin/pmset -g | grep -i disablesleep
        ;;
    *)
        echo "Usage: $0 {enable|disable|status}"
        exit 1
        ;;
esac
