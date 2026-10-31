# The one-frame white flashes

After the performance work, bright white or green blobs flashed for a single frame at random spots, usually in one eye.
They showed up day and night, with no light source in view. The cause turned out to be foveated shading after all, but
it took a while to get there, partly because of mistakes in reading the data. This is what happened and what the
measurements were.

## Tools

- **A flash detector in Nvidium.** Every frame it downscales both eye images 4x on the GPU and reads them back
  asynchronously. A worker thread flags any 32x32 pixel block whose mean brightness rises above both the previous and
  the next frame, counts flags per eye and per setting, and saves the three frames around the strongest ones. It can
  also cycle settings on a timer during normal play and announce each one in chat.
- **NullVR set up as a Quest 3.** Vivecraft's headset-free mode, patched to use the Quest's resolution and projection,
  optionally with simulated head sway.
- **The real headset lying still,** with the proximity sensor and Guardian disabled. This ended up being the instrument
  that worked.

## Wrong turns

**Fireflies.** The first recording showed bright squares. Some were vanilla firefly particles flying close to the
headset, which is normal. But the detector also found distant fireflies blinking into glowing 4x4 blocks. A firefly is
one lit texel in an 8x8 sprite, and one shading sample per 4x4 block either misses it or lights the whole block. That was
a real foveation bug, and particles now always get full rate. It wasn't the main problem.

**Phantom eyes.** The next recording had a yellow-green glow, and phantom eyes are exactly that color: 4 opaque texels
of (136, 255, 0) and (54, 220, 11). Same mechanism, same fix, eye pipelines now get full rate. Still not the main
problem.

**Missing terrain.** A capture from the game's own eye image showed a bright disc for one frame where the canopy of a
giant jungle tree should have been, which looked like the moon showing through a hole. Reading Nvidium's culling code
for a way sections could go missing turned up two genuine bugs, both now fixed. Neither changed the flashes.

**xrizer.** Still-headset runs then showed the flashes with the patched xrizer and none with WiVRn's own. Splitting
xrizer's changes apart found nothing, because the clean runs had also been made with foveated shading off. That was a
confounded comparison.

**Reading play sessions.** Earlier, a session in the headset that switched foveated shading on and off every 20 seconds
showed similar flash counts for both, and that was taken as proof foveated shading was innocent. With the head moving,
the detector flagged thousands of large ordinary frame-to-frame changes, and a few dozen real flashes disappeared in
that noise.

## The tests that settled it

With the headset lying still at night at the spot where the flashes appeared:

| Setup | Frames per eye | Large flashes, left | Large flashes, right |
|---|---:|---:|---:|
| patched xrizer, foveated shading off, pre-pass off | 6662 | 0 | 0 |
| patched xrizer, foveated shading on, pre-pass off | 7822 | 9 | 23 |
| patched xrizer, foveated shading off, pre-pass on | 7467 | 0 | 0 |
| foveated only in geometry passes | 3567 | 8 | 15 |
| foveated only in composite passes | 3620 | 0 | 0 |

Foveated shading in the geometry passes was the cause. Shaders off gave no flashes either, and the flashes appeared at
the same screen positions at noon and at midnight, so it was not the sun or the moon.

## Cause

With coarse shading, one fragment shader invocation covers a 2x2 or 4x4 pixel block, and the GPU evaluates the
triangle's interpolated inputs at the block's center. A distant leaf on a tree line is a tiny triangle, so that center
can lie well outside it, and the inputs get extrapolated far past any value the triangle actually has.

Complementary turns the sky light level into surface smoothness, `smoothnessD *= max0(lmCoord.y - 0.95) * 20.0` in
`gbuffers_terrain`. An extrapolated `lmCoord.y` above 1 makes the surface far too smooth, the specular highlight blows
up, and a few pixels come out bright enough to saturate after tone mapping. Bloom spreads them into a glowing ball for
that frame. Tiny
movements of the tracked head shift where the coarse blocks land relative to the silhouettes, so it came and went. NullVR
holds the camera perfectly still or moves it smoothly, which is probably why it never reproduced there.

## Fix

The standard fix for this in variable rate shading is `centroid` interpolation, which evaluates inputs inside the part
of the triangle the block covers. Nvidium now adds the qualifier to the interpolated inputs of every geometry program
Iris patches: vertex outputs, geometry shader inputs and outputs, and fragment inputs. Nvidium's own terrain programs are
built from Iris' patched Sodium shaders, so they get it too. Pixels shaded at full rate are unaffected.

| Centroid interpolation | Frames per eye | Large flashes, left | Large flashes, right |
|---|---:|---:|---:|
| on | 5392 | 0 | 0 |
| off | 5194 | 5 | 12 |
| on | 5391 | 0 | 0 |
| off | 5259 | 2 | 8 |
| on, final build | 8065 | 0 | 0 |

Centroid on `lmCoord` alone removed the large flashes but left 78 small one-frame changes in the right eye, while
centroid on all inputs left none, so the fix covers all of them. It has no measurable cost, as the walk comparison in
[benchmarks.md](benchmarks.md#performance-step-by-step) shows.

## Lessons

- Averaging captures is the right way to measure image quality and the wrong way to find flicker. Variable rate shading
  needs a frame-to-frame stability check too.
- Rare events need controlled comparisons. Change one setting at a time, because the xrizer detour came from comparing
  runs that differed in two.
- Head movement makes a detector based on frame differences useless for rare events. A headset lying still gave clean
  counts in a few minutes.
