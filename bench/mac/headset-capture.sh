#!/bin/bash
# Runs an autotest SCRIPT on the PC with bench.sh and captures the Quest's display over adb whenever the game logs
# "HSCAP_<name>" (autotest line "log HSCAP_<name>"). Needs ssh access to the PC in $PC (user@host) and the Quest
# connected over adb with its proximity sensor disabled (adb shell am broadcast -a com.oculus.vrpowermanager.prox_close).
# usage: PC=user@host headset-capture.sh OUTDIR REMOTE_SCRIPT
OUT=$1; SCRIPT=$2; mkdir -p "$OUT"
LOG=.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/nvidium/minecraft/logs/latest.log
ssh "$PC" "\$HOME/minecraft-vr-shaders/bench/pc/bench.sh capture --secs 2 --timeout 1500 --script $SCRIPT" > "$OUT/bench.out" 2>&1 &
BENCH=$!
seen=""
while kill -0 $BENCH 2>/dev/null; do
  m=$(ssh "$PC" "grep -o 'log HSCAP_[a-z0-9_]*' $LOG 2>/dev/null | tail -1 | sed 's/log HSCAP_//'")
  if [ -n "$m" ] && [ "$m" != "$seen" ]; then
    sleep 0.5
    adb exec-out screencap -p > "$OUT/$m.png"
    echo "captured $m"
    seen=$m
  fi
  sleep 1
done
# The headset's own frame rate counter for the run
adb logcat -d | grep -E "VrApi.*FPS=" | tail -300 | sed 's/.*\(FPS=[0-9]*\/[0-9]*\).*\(Stale=[0-9]*\).*/\1 \2/' | sort | uniq -c | sort -rn | head -6
