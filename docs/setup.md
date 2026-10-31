# Reproducing the setup

This is the setup the benchmarks ran on. Paths assume Bazzite with Prism Launcher and WiVRn installed from Flathub.
Replace `<user>` with your user name.

## 1. WiVRn

Install WiVRn and its Quest client, then pair the headset.

```sh
flatpak install flathub io.github.wivrn.wivrn
```

WiVRn's server settings live in `~/.var/app/io.github.wivrn.wivrn/config/wivrn/config.json`. The two that matter here
are the encoder and the OpenVR layer. [config/wivrn-config.json](../config/wivrn-config.json) is the file used.

```json
"encoder": "nvenc",
"openvr-compat-path": "xrizer"
```

While it runs, WiVRn registers itself as the OpenXR runtime and points OpenVR games at the xrizer it bundles through
`~/.config/openvr/openvrpaths.vrpath`. Step 6 overrides that for Minecraft only.

Note the per-eye size of the foveated video stream. It is the "size" of the NVENC encoders in the WiVRn server log. On
this Quest 3 with default WiVRn settings it was 1152x1216, while the game rendered 2270x2378 per eye. Nvidium's foveated
shading has to know the stream size, see step 8.

## 2. Let Prism Launcher reach WiVRn

Prism runs in a Flatpak sandbox, so it needs read access to the OpenXR and OpenVR registrations, WiVRn's socket and
WiVRn's install directory.

```sh
flatpak override --user org.prismlauncher.PrismLauncher \
  --filesystem=xdg-config/openxr:ro \
  --filesystem=xdg-config/openvr:ro \
  --filesystem=xdg-run/wivrn:ro \
  --filesystem=/var/lib/flatpak/app/io.github.wivrn.wivrn:ro
```

## 3. Minecraft instance

Create an instance with Minecraft 26.3 and Fabric Loader 0.20.1, running on Java 25. Add these mods:

| Mod | Version |
|---|---|
| Fabric API | 0.165.0+26.3 |
| Sodium | 0.9.2+mc26.3 |
| Iris | 1.11.7+mc26.3 |
| Vivecraft | 26.3-1.3.17-fabric |
| Nvidium | built from the fork, step 4 |

Put `ComplementaryReimagined_r5.9.3.zip` in `shaderpacks` and select it in Iris with its default settings.

## 4. Build Nvidium

Needs JDK 25.

```sh
git clone -b 26.3-vr https://github.com/phantomlullaby/nvidium.git
cd nvidium
./gradlew build
```

Copy `build/libs/nvidium-0.4.4-beta7-26.3.jar` into the instance's `mods` folder.

## 5. Build xrizer

Bazzite's base system is read-only, so build inside a distrobox. Ubuntu 24.04 with Rust 1.99 worked.

```sh
distrobox create --name Ubuntu --image ubuntu:24.04
distrobox enter Ubuntu
sudo apt install build-essential clang libclang-dev glslc pkg-config libx11-dev libxcb1-dev libgl-dev libegl-dev
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

git clone -b vr-perf https://github.com/phantomlullaby/xrizer.git
cd xrizer
cargo build --release
```

Install the library where the Prism sandbox can read it. Prism's own data directory works.

```sh
mkdir -p ~/.var/app/org.prismlauncher.PrismLauncher/xrizer-vr/bin/linux64
cp target/release/libxrizer.so ~/.var/app/org.prismlauncher.PrismLauncher/xrizer-vr/bin/linux64/vrclient.so
```

## 6. Instance settings

In Prism, open the instance's settings.

Java arguments:

```
-Dorg.lwjgl.opengl.contextAPI=native -XX:+UseZGC
```

Environment variables:

```
SDL_VIDEODRIVER=x11
SDL_VIDEO_DRIVER=x11
VR_OVERRIDE=/var/home/<user>/.var/app/org.prismlauncher.PrismLauncher/xrizer-vr
XRIZER_DEFERRED_END=1
XRIZER_REFRESH_RATE=90
```

The first two variables and `contextAPI=native` make the game use a GLX context through XWayland. `VR_OVERRIDE` makes
OpenVR load the forked xrizer instead of the one WiVRn bundles. `XRIZER_DEFERRED_END` and `XRIZER_REFRESH_RATE` turn on
the two xrizer changes described in [how-it-works.md](how-it-works.md). Without `XRIZER_REFRESH_RATE` the Quest 3 ran at
120 Hz.

Prism stores these in the instance's `instance.cfg` as `JvmArgs` and `Env`.

## 7. Game settings used for the benchmarks

| Setting | Value |
|---|---|
| Render distance | 12 |
| Simulation distance | 8 |
| Mipmap levels | 4 |
| Biome blend | 2 |
| Particles | All |
| VSync | Off, maximum fps 260. The headset paces the frames |
| Sodium | Defaults, including the no-error OpenGL context |
| Iris shadow render distance | 32 |
| Vivecraft | Defaults, OpenVR provider, render scale 1.0 |

## 8. Nvidium options

Nvidium reads `config/nvidium-config.json` and uses defaults when the file is missing. The defaults are what the
benchmarks used, see [config/nvidium-config.json](../config/nvidium-config.json). The VR options:

| Option | Default | Meaning |
|---|---|---|
| `vr_foveated_shading` | `true` | Coarse shading where WiVRn's stream averages several pixels |
| `vr_stream_width`, `vr_stream_height` | `1152`, `1216` | Per-eye stream size from step 1. Change these if yours differs |
| `vr_foveation_sample_factor` | `1.5` | How many rendered pixels per streamed pixel before shading goes coarser. Higher is sharper and slower |
| `vr_full_rate_programs` | `composite3`, `composite4` | Shader pack passes always shaded at full rate |
| `vr_full_rate_pipelines` | mob eye pipelines | Render pipelines always shaded at full rate |
| `gpu_submit_depth` | `0` | Render submits in flight. `0` means 3 with Vivecraft, 2 without |

## 9. Run

Start the WiVRn server, connect the headset, then launch the instance. Vivecraft starts VR on its own. The game log should
contain these lines:

```
Foveated shading image 2270x2378 (142x149 texels of 16x16, sample factor 1.5) for stream 1152x1216, center (-0.271, -0.046): 59.7% of full-rate fragment shading
Foveated shading image 2270x2378 (142x149 texels of 16x16, sample factor 1.5) for stream 1152x1216, center (0.271, -0.046): 59.7% of full-rate fragment shading
Render submit depth 3
```

## Undoing it

- Remove `VR_OVERRIDE`, `XRIZER_DEFERRED_END` and `XRIZER_REFRESH_RATE` to go back to WiVRn's xrizer.
- Set `"vr_foveated_shading": false` in `nvidium-config.json` to render every pixel at full rate.
- Set `"gpu_submit_depth": 2` for vanilla's submit queue.
