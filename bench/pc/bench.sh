#!/bin/bash
# VR benchmark runner for the Prism instance "nvidium" and its world "New World". Work files live in $NVTEST
# (default ~/nvtest). Only one Minecraft can use the GPU/headset at a time, so the whole run holds $NVTEST/.bench.lock.
# usage: bench.sh LABEL [options]
#   --jar PATH        nvidium jar (path on this PC) to install for the run (default: keep the installed one)
#   --secs N          seconds to profile after a 10 s settle (default 30)
#   --noshaders       run with Iris shaders disabled (default: Complementary Reimagined enabled)
#   --cfg PATH        instance.cfg to use for the run instead of the current one (restored afterwards)
#   --script PATH     extra autotest lines to run after the settle (see nvidium debug/AutoTest.java)
#   --timeout N       max seconds to wait for the game to quit after joining (default secs+90; raise it for long --script runs)
#   --noerror-off     disable Sodium's no-error GL context for the run (needed for the EGL xrizer path)
#   --nvcfg PATH      nvidium-config.json to use for the run
#   --keep            leave the game running at the end (lock is released; caller must run stop.sh)
# Results: $NVTEST/results/LABEL/{latest.log,dmon.txt,summary.txt}. Prints the [profile] blocks and fps lines.
set -u
NVTEST=${NVTEST:-$HOME/nvtest}; mkdir -p "$NVTEST"
LABEL=$1; shift
JAR=""; SECS=30; SH=shaders; CFG=""; SCRIPT=""; KEEP=0; TIMEOUT=""; NOERR=1; NVCFG=""
while [ $# -gt 0 ]; do
  case $1 in
    --jar) JAR=$2; shift;; --secs) SECS=$2; shift;; --noshaders) SH=noshaders;;
    --cfg) CFG=$2; shift;; --script) SCRIPT=$2; shift;; --keep) KEEP=1;; --timeout) TIMEOUT=$2; shift;; --noerror-off) NOERR=0;; --nvcfg) NVCFG=$2; shift;;
    *) echo "unknown option $1"; exit 2;;
  esac; shift
done
INST=~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/nvidium
I=$INST/minecraft
OUT=$NVTEST/results/$LABEL; rm -rf $OUT; mkdir -p $OUT
exec 9>$NVTEST/.bench.lock
echo "waiting for bench lock..."; flock -w 3600 9 || { echo "lock timeout"; exit 3; }
echo "lock acquired $(date +%T)"
export XAUTHORITY=$(ls -t /run/user/1000/xauth_* | head -1) DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 QT_QPA_PLATFORM=offscreen
$(dirname "$0")/stop.sh
BK=$(mktemp -d)
cp $I/mods/nvidium-*.jar $BK/; cp $INST/instance.cfg $BK/; cp $I/config/iris.properties $BK/; cp $I/config/sodium-options.json $BK/; cp $I/config/nvidium-config.json $BK/ 2>/dev/null
restore() { $(dirname "$0")/stop.sh; rm -f $I/mods/nvidium-*.jar; cp $BK/nvidium-*.jar $I/mods/; cp $BK/instance.cfg $INST/; cp $BK/iris.properties $I/config/; cp $BK/sodium-options.json $I/config/; rm -f $I/config/nvidium-config.json; cp $BK/nvidium-config.json $I/config/ 2>/dev/null; rm -f $I/nvidium-autotest.txt; rm -rf $BK; }
[ $KEEP = 0 ] && trap restore EXIT
if [ -n "$JAR" ]; then rm -f $I/mods/nvidium-*.jar; cp "$JAR" $I/mods/nvidium-0.4.4-beta7-26.3.jar; fi
[ -n "$CFG" ] && cp "$CFG" $INST/instance.cfg
[ $NOERR = 0 ] && sed -i 's/"use_no_error_g_l_context": true/"use_no_error_g_l_context": false/' $I/config/sodium-options.json
[ -n "$NVCFG" ] && cp "$NVCFG" $I/config/nvidium-config.json
if [ $SH = shaders ]; then
  sed -i 's/^shaderPack=.*/shaderPack=ComplementaryReimagined_r5.9.3.zip/; s/^enableShaders=.*/enableShaders=true/' $I/config/iris.properties
else
  sed -i 's/^enableShaders=.*/enableShaders=false/' $I/config/iris.properties
fi
touch $I/nvidium-profile.txt
{ echo "wait 200"; [ -n "$SCRIPT" ] && cat "$SCRIPT"; echo "fps"; echo "wait $((SECS*20))"; echo "fps"; [ $KEEP = 0 ] && echo "quit"; } > $I/nvidium-autotest.txt
rm -f $I/logs/latest.log
setsid nohup flatpak run org.prismlauncher.PrismLauncher -l nvidium -w "New World" > $OUT/prism.log 2>&1 < /dev/null &
for i in $(seq 1 120); do
  [ -f $I/logs/latest.log ] && grep -qE "joined the game|Minecraft Crash Report" $I/logs/latest.log && break
  sleep 2
done
echo "joined at $(date +%T)"
nvidia-smi dmon -s pu -d 1 -c $((SECS+25)) > $OUT/dmon.txt 2>&1 &
if [ $KEEP = 1 ]; then
  sleep $((SECS+15)); cp $I/logs/latest.log $OUT/latest.log
  echo "game left running (--keep); run $(dirname "$0")/stop.sh when done and restore configs yourself"
  exit 0
fi
for i in $(seq 1 ${TIMEOUT:-$((SECS+90))}); do
  grep -qE "Stopping!|Minecraft Crash Report" $I/logs/latest.log 2>/dev/null && break
  sleep 1
done
sleep 2
cp $I/logs/latest.log $OUT/latest.log
grep -E "\[profile\]|\[autotest\] fps|Crash|Exception|nvidium.*(WARN|ERROR)" $OUT/latest.log | tail -120 | tee $OUT/summary.txt
