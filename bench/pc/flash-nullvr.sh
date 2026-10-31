#!/bin/bash
# usage: flash-nullvr.sh LABEL SCRIPT JAR
# Runs SCRIPT in Vivecraft's NullVR mode with the Quest 3 emulation and the flash detector, then restores the Vivecraft
# config and options. Add nvidium-nullvr-motion.txt to the game directory beforehand for simulated head sway.
NVTEST=${NVTEST:-$HOME/nvtest}
L=$1; S=$2; J=$3
I=~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/nvidium/minecraft
VC=$I/config/vivecraft-client-config.json
exec 8>$NVTEST/.flash.lock; flock 8
cp $VC $NVTEST/vc-before-flash.json
cp $I/options.txt $NVTEST/options-before-flash.txt
sed -i "s/^inactivityFpsLimit:.*/inactivityFpsLimit:\"minimized\"/" $I/options.txt
fin() { cp $NVTEST/vc-before-flash.json $VC; cp $NVTEST/options-before-flash.txt $I/options.txt; rm -f $I/nvidium-nullvr-quest.txt $I/nvidium-profile.txt; }
trap fin EXIT
sed -i "s/\"stereoProviderPluginID\": \"OPENVR\"/\"stereoProviderPluginID\": \"NULLVR\"/" $VC
touch $I/nvidium-nullvr-quest.txt
rm -rf $I/flashes
$(dirname "$0")/bench.sh $L --jar $J --secs 2 --timeout 900 --script $S > $NVTEST/results-$L.out 2>&1
mkdir -p $NVTEST/results/$L; rm -rf $NVTEST/results/$L/flashes; cp -r $I/flashes $NVTEST/results/$L/ 2>/dev/null
grep -E "\[flash\]|Foveated shading image|Crash|Exception" $NVTEST/results/$L/latest.log | grep -v "saved #" | head -150
