"""usage: fidelity_headset.py CAPTURE_DIR scene1 [scene2 ...]   (captures <scene>_off1..4.png and <scene>_on1..4.png)
Headset display captures (after WiVRn encode -> Quest decode): averaged VRS on vs off, against off vs off noise."""
import sys, numpy as np
from PIL import Image
D = sys.argv[1]
ld = lambda n: np.asarray(Image.open(f'{D}/{n}.png').convert('RGB')).astype(np.float32)
for sc in sys.argv[2:]:
    off = [ld(f'{sc}_off{i}') for i in range(1, 5)]
    on = [ld(f'{sc}_on{i}') for i in range(1, 5)]
    h, w, _ = off[0].shape
    lum = off[0].mean(-1)
    mask = lum > 8  # inside the lenses
    # radial distance from each eye's image center, normalized to the eye half-width
    yy, xx = np.mgrid[0:h, 0:w]
    ex = np.where(xx < w // 2, w // 4, 3 * w // 4)
    r = np.hypot((xx - ex) / (w / 4), (yy - h / 2) / (h / 2))
    regions = {'all': mask, 'center r<0.35': mask & (r < 0.35), 'periphery r>0.6': mask & (r > 0.6)}
    oA, oB = (off[0] + off[2]) / 2, (off[1] + off[3]) / 2
    nA, nB = (on[0] + on[2]) / 2, (on[1] + on[3]) / 2
    d = lambda a, b, m: np.abs(a - b).max(-1)[m].mean()
    for name, m in regions.items():
        noise = d(oA, oB, m)
        vrs = 0.5 * (d(nA, oA, m) + d(nB, oB, m))
        print(f"{sc:8s} {name:16s} noise {noise:5.2f}  vrs-vs-off {vrs:5.2f}  excess {vrs - noise:+5.2f}")
