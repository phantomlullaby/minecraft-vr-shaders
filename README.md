# Minecraft VR with shaders at 90 fps

Complementary Reimagined in Vivecraft on a Quest 3, streamed from a Linux PC over WiVRn, at 89.5 to 90 fps in every
static benchmark scene. This repo describes the setup, the changes that got it there, and the measurements behind each
one.

The work lives in two forks:

- [phantomlullaby/nvidium](https://github.com/phantomlullaby/nvidium/tree/26.3-vr), branch `26.3-vr`. Nvidium with Iris
  shader pack and Vivecraft support, foveated shading for streamed VR, a depth pre-pass and rendering fixes.
- [phantomlullaby/xrizer](https://github.com/phantomlullaby/xrizer/tree/vr-perf), branch `vr-perf`. xrizer, the OpenVR
  to OpenXR layer WiVRn uses, with a deferred frame end and a refresh rate request.

Iris, Sodium, Vivecraft, WiVRn and the shader pack are unmodified. The pack runs with its default settings.

## Results

Frames per second in the headset, 8 seconds per scene after the world settles. Scenes are fixed positions in one world,
see [docs/benchmarks.md](docs/benchmarks.md).

| Scene | Before | After |
|---|---:|---:|
| far view | 60.9 | 89.8 |
| jungle floor | 63.2 | 90.0 |
| river | 56.4 | 90.0 |
| village | 65.3 | 89.7 |
| night | 70.9 | 89.7 |
| underwater | 66.6 | 90.0 |
| rain | 63.3 | 89.5 |
| nether | 115.9 | 90.0 |
| 30 s jungle walk | | 83.1 to 90.0 |
| 30 s village walk | | 88.6 |

"Before" is the Nvidium build that first made Iris and Vivecraft work, with the headset at its default 120 Hz. "After"
is the final build with the headset requested at 90 Hz, so 90 is the ceiling. The jungle walk varies between runs with
chunk loading and walking direction.

Image quality was checked against rendering everything at full rate. The difference on the Quest's own display was
within capture-to-capture noise, and in a simulation of WiVRn's stream the foveated shading added at most 0.76/255 of
error per pixel, where the video encoder alone adds 2.4 to 4.9/255.

## Hardware and software

| | |
|---|---|
| GPU | RTX 4070 SUPER, NVIDIA driver 615.78.08 |
| OS | Bazzite (Fedora 44 base), kernel 7.2.9, KDE Plasma |
| Headset | Quest 3 with the WiVRn client, 2270x2378 rendered and 1152x1216 streamed per eye |
| Streaming | WiVRn 26.9 from Flathub, NVENC encoder |
| Launcher | Prism Launcher 11.1.1 from Flathub |
| Minecraft | 26.3, Fabric Loader 0.20.1, Java 25.0.1 |
| Mods | Fabric API 0.165.0+26.3, Sodium 0.9.2+mc26.3, Iris 1.11.7+mc26.3, Vivecraft 26.3-1.3.17, Nvidium fork |
| Shader pack | Complementary Reimagined r5.9.3, default settings |
| OpenVR layer | xrizer fork, replacing the xrizer bundled with WiVRn |

Nvidium needs an NVIDIA GPU from the Turing generation or later. The foveated shading uses `NV_shading_rate_image`, so
it is NVIDIA only as well.

## Documents

- [docs/setup.md](docs/setup.md) walks through reproducing the setup and how to undo it.
- [docs/how-it-works.md](docs/how-it-works.md) explains each change, why it helps, and what did not work.
- [docs/benchmarks.md](docs/benchmarks.md) covers the method, every measurement step, and the image quality checks.
- [docs/flash-investigation.md](docs/flash-investigation.md) is the story of a one-frame white flash artifact the
  foveated shading caused, and how it was found and fixed.
- [bench/](bench/) has the benchmark and analysis scripts. [results/](results/) has the raw output of the runs the
  documents cite.
