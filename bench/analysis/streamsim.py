"""Simulate WiVRn's foveated stream image from full-res eye captures and compare them.
usage: streamsim.py cx cy imgA imgB [imgC ...]   (cx, cy: foveation centers from the nvidium log, y top-down)
Prints pairwise stats on the simulated stream images (and full-res) vs the first image."""
import sys, math
import numpy as np
from PIL import Image
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fov import solve

def boundaries(foveated, source, c):
    lam = foveated/source; a, b = solve(lam, c)
    left, right = [], []; last = 0
    def add(v, n):
        while len(v) < n: v.append(0)
        v[n-1] += 1
    for i in range(1, foveated):
        u = i*2.0/foveated - 1
        f = lam/a*math.tan(a*u+b) + c
        n = min(max(int((f*0.5+0.5)*source+0.5), 0), source)
        add(left if u < c else right, max(1, n-last)); last = n
    add(right, max(1, source-last))
    k = max(len(left), len(right)); out = [0]*(2*k-1)
    pos = k-len(left)
    for v in reversed(left): out[pos] += v; pos += 1
    pos -= 1
    for i, v in enumerate(right): out[pos+i] += v
    xs = [0]
    for i, n in enumerate(out):
        span = abs(k-1-i)+1
        for _ in range(n): xs.append(xs[-1]+span)
    return xs[:foveated+1]

def matrix(foveated, source, c):
    xs = boundaries(foveated, source, c)
    m = np.zeros((foveated, source), np.float32)
    for i in range(foveated):
        lo, hi = xs[i], min(xs[i+1], source)
        if hi <= lo: hi = min(lo+1, source)
        step = (hi-lo+3)//4
        idx = list(range(lo, hi, step))
        for x in idx: m[i, x] += 1.0/len(idx)
    return m

def to_lin(a):
    a = a/255.0
    return np.where(a <= 0.04045, a/12.92, ((a+0.055)/1.055)**2.4)

def to_srgb(a):
    a = np.clip(a, 0, 1)
    return np.where(a < 0.0031308, a*12.92, 1.055*a**(1/2.4)-0.055)*255

def stream(img, cx, cy, fw=1152, fh=1216):
    h, w, _ = img.shape
    mx = matrix(fw, w, cx); my = matrix(fh, h, cy)
    lin = to_lin(img[..., :3].astype(np.float32))
    out = np.stack([my @ lin[..., ch] @ mx.T for ch in range(3)], -1)
    return to_srgb(out)

def stats(a, b):
    d = np.abs(a-b).max(-1)
    mse = ((a-b)**2).mean()
    psnr = 10*math.log10(255**2/mse) if mse > 0 else 99
    return f"mean {d.mean():.2f}  >8: {100*(d>8).mean():.2f}%  >24: {100*(d>24).mean():.2f}%  psnr {psnr:.1f}"

cx, cy = float(sys.argv[1]), float(sys.argv[2])
imgs = [np.asarray(Image.open(p).convert('RGB')).astype(np.float32) for p in sys.argv[3:]]
streams = [stream(i, cx, cy) for i in imgs]
for p, i, s in zip(sys.argv[4:], imgs[1:], streams[1:]):
    print(f"{p}: full-res [{stats(imgs[0], i)}]  stream [{stats(streams[0], s)}]")
if len(sys.argv) > 5 and '--save' not in sys.argv:
    pass
Image.fromarray(np.clip(streams[0], 0, 255).astype(np.uint8)).save('stream0.png')
