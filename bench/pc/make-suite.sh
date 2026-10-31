#!/bin/bash
# Writes the full benchmark script: the 8 scenes from scenes.txt, then two 30 s walks (0.25 blocks per tick).
# usage: make-suite.sh > full.txt
cd "$(dirname "$0")"
cat scenes.txt
echo "wait 300"; echo "prof reset"
for i in $(seq 600); do echo "cmd tp @p ~0.25 ~ ~"; done
echo "prof report walk_jungle"
echo "cmd tp @p -240 100 336 90 10"; echo "wait 300"; echo "prof reset"
for i in $(seq 600); do echo "cmd tp @p ~ ~ ~0.25"; done
echo "prof report walk_village"
