# Benchmarks

## Method

All numbers come from the real headset unless a section says otherwise. The game runs scripted through Nvidium's debug
autotest: a file named `nvidium-autotest.txt` in the game directory holds one command per line, executed one per game
tick. `prof reset` and `prof report <name>` bracket a measurement. The frame profiler is active when
`nvidium-profile.txt` exists, and reports frames per second plus wall, CPU and GPU time per frame. A frame is both eyes.

[bench/pc/bench.sh](../bench/pc/bench.sh) launches Prism with a chosen Nvidium jar, instance config and script, waits
for the game to quit, then restores everything it changed. The headset's own frame counter, `VrApi FPS=90/90 Stale=0`
in `adb logcat`, agreed with the game's numbers.

The world is a freshly generated creative world, seed `-956860826812063173`. Each scene teleports a spectator to a fixed spot,
waits 200 ticks for chunks and lighting to settle, then measures 160 ticks, about 8 seconds.

| Scene | Position | Yaw, pitch | Time of day | Notes |
|---|---|---|---|---|
| far view | -240 120 336 | 90, 15 | 2000 | Long view over terrain |
| jungle floor | 0 84 0 | -45, 15 | 2000 | Dense leaves |
| river | 64 72 96 | 45, 30 | 2000 | Water reflections |
| village | -240 95 336 | 90, 25 | 2000 | |
| night | -240 75 336 | 90, 20 | 18000 | |
| underwater | 64 60 96 | 45, 10 | 6000 | |
| rain | 0 100 0 | 0, 10 | 6000 | Weather set to rain |
| nether | 0 80 0 in the Nether | 45, 20 | | 300 tick wait |
| jungle walk | from 0 100 0, +x | 45, 20 | 6000 | 0.25 blocks per tick for 30 s |
| village walk | from -240 100 336, +z | 90, 10 | 6000 | 0.25 blocks per tick for 30 s |

The walks teleport the spectator 0.25 blocks every tick, 5 blocks per second, so chunks load and sections rebuild during
the measurement. [bench/pc/make-suite.sh](../bench/pc/make-suite.sh) writes the full script.

## Performance, step by step

Frames per second. The first three rows ran with the Quest at its default 120 Hz, so values above 90 were possible and
120 was the ceiling. The last three ran at 90 Hz.

| Build | Hz | far | jungle floor | river | village | night | underwater | rain | nether | jungle walk | village walk |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Iris and Vivecraft support, no foveated shading | 120 | 60.9 | 63.2 | 56.4 | 65.3 | 70.9 | 66.6 | 63.3 | 115.9 | | |
| + foveated shading, first version with k = 1 | 120 | 90.3 | 92.1 | 83.9 | 96.6 | 104.6 | 102.9 | 92.4 | 120.0 | | |
| + depth pre-pass | 120 | 91.2 | 93.9 | 91.3 | 93.5 | 101.4 | 103.0 | 89.8 | 119.7 | | |
| final foveation k = 1.5, 3 submits in flight | 90 | 90.0 | 79.3 | 90.0 | 89.8 | 90.0 | 90.0 | 84.0 | 90.0 | 83.0 | 87.7 |
| + deferred frame end | 90 | 89.6 | 90.0 | 90.0 | 89.5 | 90.0 | 90.0 | 90.0 | 90.0 | 86.9 | 88.3 |
| final build, with the flash fixes | 90 | 89.8 | 90.0 | 90.0 | 89.7 | 89.7 | 90.0 | 89.5 | 90.0 | 83.1 | 88.6 |

GPU time per frame for the first row was 12.5 to 15.5 ms in the overworld. The rows map to these runs in
[results/raw.txt](../results/raw.txt): `scenes-off`, `scenes-on`, `scenes-merged1`, `suite-nodefer`, `suite-deferB`
and `final2_suite`.

The walk numbers move by a few frames between runs. Comparing the flash fix on and off showed why: in two separate
sessions, every pass walking in one direction measured 87.0 to 87.5 fps and every pass in the other direction 89.9 to
90.0, whatever the setting. Same-direction passes with and without centroid interpolation were identical, 87.5 and 87.5,
then 89.9 and 90.0. The fix costs nothing measurable.

## Image quality

Foveated shading is the only change that alters pixels on purpose, so it was compared against full-rate shading in two
ways. Both average four captures per setting, because waving leaves and water change every frame. "Noise" is the
difference between two averages of full-rate captures. "Excess" is how much further a foveated average is from a
full-rate average than that. Values are the mean per-pixel difference on a 0 to 255 scale.

### On the headset's display

`adb exec-out screencap` captures what the Quest shows after WiVRn's encode and decode. Center is within 0.35 of the
eye's half-width from its middle, periphery beyond 0.6.

| Scene | Region | Noise | Foveated vs full rate | Excess |
|---|---|---:|---:|---:|
| far | all | 2.52 | 2.45 | -0.07 |
| far | center | 3.24 | 3.05 | -0.19 |
| far | periphery | 2.01 | 2.23 | +0.22 |
| village | all | 2.50 | 2.63 | +0.13 |
| village | center | 2.52 | 2.58 | +0.07 |
| village | periphery | 2.45 | 2.61 | +0.17 |

The difference stays within capture-to-capture noise.

### In a simulation of WiVRn's stream

Full-resolution eye images from NullVR set up with the Quest 3's resolution and projection, run through a model of
WiVRn's foveated downscale in [bench/analysis/streamsim.py](../bench/analysis/streamsim.py). The last column is the
error AV1 at 36 Mbit/s adds to the same scene during a slow pan, for scale.

| Scene | Eye | Noise | Excess at k = 1.5 | Excess at k = 2 | AV1 error |
|---|---|---:|---:|---:|---:|
| far | L | 1.44 | +0.54 | +0.30 | |
| far | R | 1.40 | +0.47 | +0.23 | 4.39 |
| jungle floor | L | 7.32 | -0.05 | +0.61 | |
| jungle floor | R | 6.94 | -0.44 | +0.54 | 4.91 |
| river | L | 6.63 | -1.11 | +0.28 | |
| river | R | 7.20 | -1.42 | +0.09 | 4.63 |
| village | L | 2.07 | +0.76 | +0.62 | |
| village | R | 1.91 | +0.69 | +0.52 | 4.87 |
| night | L | 0.47 | +0.30 | +0.23 | |
| night | R | 0.46 | +0.22 | +0.16 | 2.62 |
| underwater | L | 9.75 | -2.87 | -1.40 | |
| underwater | R | 10.12 | -2.88 | -1.39 | 3.11 |
| rain | L | 2.54 | -0.30 | -0.14 | |
| rain | R | 2.71 | -0.34 | -0.20 | 3.27 |
| nether | L | 0.16 | +0.22 | +0.08 | |
| nether | R | 0.28 | +0.22 | +0.07 | 2.40 |

The largest excess is 0.76, against 2.4 to 4.9 from the video encoder. Negative values mean the scene moved more between
captures than foveation changed it.

### One-frame flashes

These averages can't see flicker, which is how a flash artifact got through. See
[flash-investigation.md](flash-investigation.md). The flash detector downscales both eye images 4x every frame and
flags a 32x32 pixel block whose mean brightness rises above both the previous and the next frame. A large flash is a
rise of more than 32 on the 0 to 255 scale. These runs used the real headset lying still, at night, at the spot where
the flashes showed up.

| Setup | Frames per eye | Large flashes, left eye | Large flashes, right eye |
|---|---:|---:|---:|
| foveated shading off, pre-pass off | 6662 | 0 | 0 |
| foveated shading on, pre-pass off | 7822 | 9 | 23 |
| foveated shading off, pre-pass on | 7467 | 0 | 0 |
| foveated only in geometry passes | 3567 | 8 | 15 |
| foveated only in composite passes | 3620 | 0 | 0 |
| foveated, centroid interpolation on | 5392 | 0 | 0 |
| foveated, centroid interpolation off | 5194 | 5 | 12 |
| foveated, centroid interpolation on | 5391 | 0 | 0 |
| foveated, centroid interpolation off | 5259 | 2 | 8 |
| final build | 8065 | 0 | 0 |
