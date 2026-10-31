#!/bin/bash
# Stops Prism Launcher and any game it started
flatpak kill org.prismlauncher.PrismLauncher 2>/dev/null
pkill -9 -f "[o]rg.prismlauncher.EntryPoint" 2>/dev/null
sleep 1
