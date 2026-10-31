# How it works

## The starting point

The Nvidium build that first ran Complementary Reimagined in Vivecraft took 12.5 to 15.5 ms of GPU time per frame in
the overworld scenes. A frame is two eyes of 2270x2378 pixels each, about 10.8 million pixels, every one of them going
through Complementary's deferred lighting. At 90 Hz the budget is 11.1 ms, so frame rates sat between 56 and 71.

Four changes closed the gap, and asking the headset for 90 Hz instead of 120 set the target. Most of the gain came from
not shading pixels the stream throws away, and the last few frames from keeping the GPU busy while the CPU waits on the
headset.

## 1. Foveated shading that matches WiVRn's stream

WiVRn never sends the full 2270x2378 eye image. Its encoder squeezes each eye into a 1152x1216 video frame with
foveation. Around the lens center every rendered pixel becomes one streamed pixel. Further out, each streamed pixel is
the average of 2, 3 or 4 rendered pixels along each axis. Shading those outer pixels individually is wasted work,
because the encoder averages them together anyway.

Nvidium reproduces WiVRn's mapping with a port of WiVRn's foveation solver, `WiVRnFoveation.java`, and turns it into
an `NV_shading_rate_image` for each eye. The image has one entry per 16x16 pixel tile. A tile is shaded once per 2 or 4
pixels along an axis wherever WiVRn averages at least 2k or 4k rendered pixels into one streamed pixel there. k is
`vr_foveation_sample_factor`, 1.5 by default, with a 24 pixel safety margin around each band. Depth, coverage and
geometry stay per pixel. Only the fragment shader runs less often, about 59.7% of the full rate.

The foveation centers follow WiVRn: the eyes converge at 1 meter and the assumed gaze is 10 degrees below straight
ahead, which puts the centers at x = ±0.271 and y = -0.046 in normalized image coordinates.

The first version used k = 1, so every streamed pixel got exactly one shading sample. It shaded 36.9% of the pixels and
was fast, but the outer periphery of the simulated stream looked softer. k = 1.5 keeps the error well below the video
encoder's own. The measurements are in [benchmarks.md](benchmarks.md#image-quality).

Some things always get full rate:

- The corner tiles. Complementary keeps per-frame values in single corner pixels, like the volumetric light factor in
  the top right pixel, and finds them with exact `gl_FragCoord` tests a coarse fragment never passes.
- Tiles on the right and top edges only use rates that divide the partial tile, so `gl_FragCoord` never lands outside
  the target, where the pack's `texelFetch` calls would read nothing.
- Complementary's `composite3` and `composite4` passes, which draw the bloom fog. Coarse shading there shifted the
  colors of the whole image slightly.
- Particles and mob eyes. Both are a few bright texels of a texture without mipmaps. A firefly is one lit texel in an
  8x8 sprite. One shading sample per 4x4 block either misses it or lights the whole block, and bloom turns that into a
  flickering blob.
- The shadow map and scaled composite passes, which don't draw into the eye-sized targets.

The shader pack's geometry programs, terrain and entities among them, also read their interpolated inputs with
`centroid` interpolation. Without it a coarse fragment evaluates the triangle's inputs at the center of its 4x4 block,
which for a distant leaf can lie far outside the triangle.
[flash-investigation.md](flash-investigation.md) explains why that mattered.

## 2. Depth pre-pass for opaque terrain

Forests mean overdraw. Leaves cover each other, so Complementary's terrain fragment shader ran several times per pixel
and most results were overwritten. The pre-pass draws opaque terrain twice:

1. A depth-only program made from the pack's own fragment shader with its color outputs removed. The compiler drops
   everything except what decides the alpha test discard.
2. The full program with depth writes off. Each fragment is tested against the finished depth buffer before shading,
   so each pixel is shaded once.

Both programs share the vertex shader with `invariant gl_Position`, so their depths match exactly. The river scene went
from 83.9 to 91.3 fps with the pre-pass when it was added.

## 3. Three render submits in flight

Vivecraft submits GPU work after each eye. Minecraft's OpenGL backend allows 2 submits in flight, so the CPU could
never get more than one eye ahead of the GPU. Nvidium raises it to 3 with Vivecraft by resizing the backend's fence
slots and its rotating transient memory. The option is `gpu_submit_depth`.

## 4. Deferred frame end in xrizer

This change got the last scenes from the low 80s to 90.

With a GLX context, ending an OpenXR frame makes the runtime's OpenGL client call `glFinish`. The CPU blocks until the
GPU has finished everything queued. Then `xrWaitFrame` blocks for the headset's pacing, and the next frame starts with
an idle GPU. With the headset at 90 Hz, the jungle floor ran at 79.3 fps and rain at 84.0.

With `XRIZER_DEFERRED_END=1`, xrizer's `WaitGetPoses` keeps frame N open and returns poses predicted one display period
further ahead, so the game starts frame N+1 right away. After Nvidium has queued the left eye of frame N+1, it calls
`PostPresentHandoff`. Only then does xrizer end frame N, wait, and begin frame N+1. The `glFinish` now runs while the GPU
still has the left eye to draw. The runtime sees its usual wait, begin, end order, so pacing is unaffected. If a game
never hands off, the next `WaitGetPoses` ends the frame instead.

The jungle floor went from 79.3 to 90.0 fps and rain from 84.0 to 90.0. The cost is that poses are predicted one frame
further ahead.

## 5. 90 Hz

`XRIZER_REFRESH_RATE=90` asks the headset for 90 Hz through `XR_FB_display_refresh_rate`. The Quest 3 otherwise ran at
120 Hz through WiVRn, which this hardware can't hold with shaders.

## What didn't work

- **An EGL context instead of GLX.** The xrizer fork can create OpenXR sessions for EGL contexts
  through `XR_MNDX_egl_enable`. The idea was that the runtime would sync on a native fence instead of `glFinish`. WiVRn ignores
  that fence and waits for its own GPU work synchronously, so the EGL path stalled. The code is still in the fork, and
  nothing uses it with the settings in [setup.md](setup.md).
- **The first deferred end.** It ended frame N inside the handoff without keeping the runtime's wait, begin, end order.
  In a fresh WiVRn session that broke pacing, with unpaced frames and multi-second stalls. The version in the fork keeps
  the order.
- **Coarser foveation.** k = 1 and coarse shading in the bloom fog passes were faster but visibly changed the image.

## Bugs found along the way

- **Nvidium culling.** Nvidium keeps an 8-render visibility history per chunk section and decides which newly visible
  sections need a catch-up draw from it. Regions hidden behind terrain skipped their sections' history update, and a
  region leaving the view cleared 255 of its 256 sections. Either way a section could look as if it had been drawn in
  the previous render when it had not, and go missing for a frame. In VR the two eyes alternate renders from different
  viewpoints, which makes this more likely. Both are fixed.
- **One-frame white flashes** from foveated shading, fixed with centroid interpolation. See
  [flash-investigation.md](flash-investigation.md).

## Iris and Vivecraft support

This came before the performance work. Nvidium normally replaces Sodium's terrain rendering with its own shaders, which
Iris can't hook. The fork instead takes the shader pack's terrain programs as Iris patched them for Sodium, adapts the
vertex shader to Nvidium's draws, and builds the draw lists on the GPU from Nvidium's culling output. The same path draws
translucent terrain and the shadow map. With a pack active it keeps Iris' vertex format and the vanilla far plane,
because packs linearize depth with it.

For Vivecraft, the terrain buffer is reused when renderers are rebuilt. A fresh 2 GiB buffer could otherwise land in
system memory once Vivecraft's per-eye Iris pipelines were allocated, which made terrain rendering about 4 times slower.
