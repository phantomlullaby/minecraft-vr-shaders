"""usage: fidelity_sim.py CAPTURE_DIR STREAM_W STREAM_H CENTER_Y LEFT_CENTER_X scene1,scene2,...
Captures are h_<scene>_<mode><n>_<L|R>.png from the autotest "eyeshot" command, modes off/k15_/k2_, n = 1..4.
Averaged fidelity per scene: 4 captures per mode, compared in the simulated WiVRn stream (right/left eye),
plus the AV1 error of the stream at 36 Mbit/s 90 fps for that scene (slow pan)."""
import sys, os, subprocess, numpy as np
from PIL import Image
SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'streamsim.py')
src = open(SIM).read().split('cx, cy = float')[0]
g = {'__file__': SIM}; exec(src, g)
import sys
D = sys.argv[1]
FW, FH, CY = int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4]); CXL = float(sys.argv[5])
SCENES = sys.argv[6].split(',')
ld = lambda p: np.asarray(Image.open(p).convert('RGB')).astype(np.float32)
def S(n, eye, cx): return g['stream'](ld(f'{D}/h_{n}_{eye}.png'), cx, CY, FW, FH)
def mad(a, b): return np.abs(a - b).max(-1).mean()
def codec_err(img, tag):
    w = os.path.join('codec', tag); os.makedirs(w, exist_ok=True)
    s = np.clip(img, 0, 255).astype(np.uint8)
    ch, cw = (s.shape[0]-64)//8*8, (s.shape[1]-96)//8*8
    for i in range(45): Image.fromarray(s[32:32+ch, i*2:i*2+cw]).save(f'{w}/f_{i:03d}.png')
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','90','-i',f'{w}/f_%03d.png','-c:v','libsvtav1','-pix_fmt','yuv420p10le','-b:v','36M','-svtav1-params','rc=2:pred-struct=1:preset=8',f'{w}/o.mkv'],check=True,capture_output=True)
    subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',f'{w}/o.mkv','-pix_fmt','rgb24',f'{w}/d_%03d.png'],check=True,capture_output=True)
    e = [mad(np.asarray(Image.open(f'{w}/f_{i:03d}.png')).astype(np.float32), np.asarray(Image.open(f'{w}/d_{i+1:03d}.png')).astype(np.float32)) for i in range(15, 45)]
    return float(np.mean(e))
print(f"{'scene':10s} eye | noise(avg2 off vs off) | k=1.5 excess | k=2 excess | AV1 error")
for sc in SCENES:
    for eye, cx in (('L', CXL), ('R', -CXL)):
        off = [S(f'{sc}_off{i}', eye, cx) for i in range(1,5)]
        k15 = [S(f'{sc}_k15_{i}', eye, cx) for i in range(1,5)]
        k2 = [S(f'{sc}_k2_{i}', eye, cx) for i in range(1,5)]
        oA, oB = (off[0]+off[2])/2, (off[1]+off[3])/2
        noise = mad(oA, oB)
        def ex(on):
            a, b = (on[0]+on[2])/2, (on[1]+on[3])/2
            return 0.5*(mad(a, oA) + mad(b, oB)) - noise
        ce = codec_err(off[0], f'{sc}_{eye}') if eye == 'R' else float('nan')
        print(f"{sc:10s} {eye}   | {noise:6.2f} | {ex(k15):+6.2f} | {ex(k2):+6.2f} | {ce:5.2f}", flush=True)
