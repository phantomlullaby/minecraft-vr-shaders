#!/bin/bash
# usage: flash-headset.sh LABEL SCRIPT [extra bench.sh args]
# Runs SCRIPT in the real headset with the flash detector and prints the counts. Pauses the in-play A/B cycler
# (nvidium-flashab.txt) for the run.
NVTEST=${NVTEST:-$HOME/nvtest}
L=$1; S=$2; shift 2
I=~/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher/instances/nvidium/minecraft
had=0; [ -f $I/nvidium-flashab.txt ] && had=1 && rm -f $I/nvidium-flashab.txt
rm -rf $I/flashes
$(dirname "$0")/bench.sh $L --secs 2 --timeout 600 --script $S "$@" > $NVTEST/results-$L.out 2>&1
mkdir -p $NVTEST/results/$L; rm -rf $NVTEST/results/$L/flashes; cp -r $I/flashes $NVTEST/results/$L/ 2>/dev/null
[ $had = 1 ] && touch $I/nvidium-flashab.txt
touch $I/nvidium-profile.txt
grep -E "\[flash\].*(analysed|one-frame)|Exception|Crash" $NVTEST/results/$L/latest.log | grep -v ": 3 frames" | sed "s/.*\[flash\] //" | cut -c1-120
grep "saved #" $NVTEST/results/$L/latest.log | sed "s/.*saved //" | head -30
