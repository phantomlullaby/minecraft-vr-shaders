# Benchmark and analysis scripts

## On the PC

These assume the Prism instance is called `nvidium` and the world `New World`. Work files and results go to `$NVTEST`,
`~/nvtest` by default.

| Script | What it does |
|---|---|
| `pc/bench.sh LABEL [options]` | Launches the instance with a chosen Nvidium jar, instance config, Nvidium config and autotest script, waits for the game to quit, prints the profiler results and restores everything it changed. The options are listed at the top of the script. |
| `pc/make-suite.sh > full.txt` | Writes the full benchmark script, the 8 scenes plus the two walks. |
| `pc/flash-headset.sh LABEL SCRIPT` | Runs a script in the real headset with the flash detector and prints flash counts per eye. |
| `pc/flash-nullvr.sh LABEL SCRIPT JAR` | Same in Vivecraft's NullVR mode with the Quest 3 emulation, no headset needed. |
| `pc/stop.sh` | Stops Prism and the game. |

`pc/scenes.txt` is the 8 scene script and `pc/flash-static.txt` the still-headset flash check. Running the suite:

```sh
bench/pc/make-suite.sh > ~/nvtest/full.txt
bench/pc/bench.sh suite --secs 2 --timeout 700 --script ~/nvtest/full.txt
```

## On the Mac or any machine with adb

`mac/headset-capture.sh` runs a script on the PC over ssh and saves what the Quest displays whenever the game logs a
`HSCAP_<name>` marker.

## Analysis

| Script | What it does |
|---|---|
| `analysis/fov.py` | WiVRn's foveation mapping: how many rendered pixels each streamed pixel averages |
| `analysis/streamsim.py` | Turns full-resolution eye captures into a simulation of WiVRn's foveated stream |
| `analysis/fidelity_sim.py` | Averaged foveated vs full-rate comparison in the simulated stream, plus the AV1 error for scale |
| `analysis/fidelity_headset.py` | Averaged comparison of headset display captures |

They need Python 3 with numpy and Pillow, and ffmpeg with SVT-AV1 for the AV1 column.

## Autotest commands

Nvidium's debug autotest runs `nvidium-autotest.txt` from the game directory, one line per game tick, once a world is
loaded. Lines starting with `#` are skipped.

| Command | Effect |
|---|---|
| `wait N` | Wait N ticks |
| `cmd COMMAND` | Run a server command with full permissions, without the slash |
| `prof reset`, `prof report NAME` | Start a measurement, then log fps, wall, CPU and GPU time per frame as NAME |
| `log TEXT` | Write TEXT to the log, used as a marker |
| `shot NAME`, `eyeshot NAME` | Screenshot of the desktop window, or of both VR eyes at full resolution |
| `nvidium on/off` | Nvidium or plain Sodium terrain |
| `shaders on/off`, `irisreload` | Toggle or reload the shader pack |
| `vrs on/off` | Foveated shading |
| `vrsk K` | Foveation sample factor |
| `vrsfull PROGRAMS/none` | Comma separated shader pack programs kept at full rate |
| `vrsparticles full/coarse`, `vrspipelines default/none` | Full rate for particles and for the mob eye pipelines |
| `vrsgeometry on/off`, `vrscomposites on/off` | Foveated shading in the geometry passes and in the composite passes |
| `centroid on/off`, `centroidnames NAMES/all` | Centroid interpolation, for all varyings or only the named ones. Needs `irisreload` |
| `prepass on/off` | Depth pre-pass for opaque terrain |
| `flash on LABEL`, `flash report LABEL`, `flash off` | Flash detector |
| `hud on/off`, `pause on/off`, `pos`, `fps`, `debug` | Small helpers |
| `quit` | Close the game |

## Marker files

These files in the game directory switch on debug features. None of them exist in normal play.

| File | Effect |
|---|---|
| `nvidium-autotest.txt` | The autotest script |
| `nvidium-profile.txt` | Frame profiler and the debug hooks the flash detector needs |
| `nvidium-flashab.txt` | Flash detector during normal play, cycling settings every 15 s with chat announcements |
| `nvidium-nullvr-quest.txt` | NullVR renders Quest 3 eyes, 2270x2378 with the Quest's projection |
| `nvidium-nullvr-motion.txt` | NullVR head sways a few cm and turns up to 8 degrees |
