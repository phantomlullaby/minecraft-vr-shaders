import math, sys
def solve(lam, c):
    b = lambda a: math.atan(a*(1-c)/lam) - a
    eq = lambda a: math.atan(a*(1-c)/lam) + math.atan(a*(1+c)/lam) - 2*a
    a0, a1 = 0.0, 1.0
    while eq(a1) > 0: a1 *= 2
    fa0 = None; fa1 = eq(a1); n = 0; a = 0
    while abs(a1-a0) > 1e-7 and n < 100:
        n += 1
        if fa0 is None:
            a = 0.5*(a0+a1); v = eq(a)
            if v > 0: a0 = a; fa0 = v
            else: a1 = a; fa1 = v
        else:
            a = a1 - fa1*(a1-a0)/(fa1-fa0); a0 = a1; a1 = a; fa0 = fa1; fa1 = eq(a)
    return a, b(a)
def ratios(foveated, source, c):
    """per source pixel: how many source pixels share its foveated pixel (WiVRn's span size, before sorting)"""
    lam = foveated/source
    a, b = solve(lam, c)
    last = 0; spans = []
    for i in range(1, foveated):
        u = i*2.0/foveated - 1
        f = lam/a*math.tan(a*u+b) + c
        n = min(max(int((f*0.5+0.5)*source+0.5), 0), source)
        spans.append(n-last); last = n
    spans.append(source-last)
    r = []
    for s in spans: r += [s]*s
    return r
if __name__ == '__main__':
  for (fov, src, c) in [(1152, 2270, 0.0), (1152, 2270, 0.15), (1216, 2378, 0.0), (1216, 2378, -0.2)]:
    r = ratios(fov, src, c)
    cnt = {}
    for v in r: cnt[v] = cnt.get(v, 0) + 1
    print(fov, src, c, {k: round(v/len(r), 3) for k, v in sorted(cnt.items())})
