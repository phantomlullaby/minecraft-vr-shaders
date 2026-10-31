# Raw results

`raw.txt` holds the profiler and flash detector lines of every run the documents cite, in run order. Each block starts
with `##### <label> <date>`. `image-quality.txt` is the output of the two image quality scripts.

| Label | What ran |
|---|---|
| `scenes-off` | 8 scenes, compatibility build with foveated shading off, 120 Hz |
| `scenes-on` | Same with the first foveated shading, k = 1 |
| `scenes-merged1` | Plus the depth pre-pass |
| `suite-nodefer` | Final foveation, 3 submits in flight, 90 Hz, stock frame end. Scenes and walks |
| `suite-deferB` | Plus the deferred frame end |
| `final2_suite` | Final build with the flash fixes |
| `walkcen` | Jungle walk with centroid interpolation on, off, on |
| `hsLm` | Still-headset flash check with centroid on `lmCoord` only, then walks with centroid on `lmCoord`, all, off |
| `hs2` | Still headset, all of the changes off, WiVRn's xrizer |
| `hsY` | Still headset, WiVRn's xrizer, 3 submits in flight, foveated shading and pre-pass off |
| `hsX` | Still headset, patched xrizer, 2 submits in flight |
| `hsZ1`, `hsZ2` | Patched xrizer without the deferred end, and without the refresh rate request |
| `hsX2`, `hsX3`, `hsX4` | Patched xrizer with foveated shading and pre-pass off/off, on/off, off/on |
| `hsS` | Foveated shading in both, geometry only, composites only, both |
| `hsE` | Night and noon, shaders on and off |
| `hsCen` | Centroid interpolation on, off, on, off |
| `hsF3` | Final build |
| `motion1`, `rebuild1`, `holes1`, `holes2` | NullVR attempts to reproduce the flashes: simulated head motion, forced chunk rebuilds, Nvidium against Sodium |

The rows marked "still headset" ran in the Quest lying on a desk at night at the spot where the flashes appeared. Flash
counts are per eye at thresholds of 4, 8, 16 and 32 on a 0 to 255 brightness scale. The documents use the 32 column.
