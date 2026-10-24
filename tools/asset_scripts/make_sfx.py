import math, os, random, struct, sys, wave

SR = 44100
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
random.seed(7)

def env(t, dur, attack=0.005, curve=3.0):
    if t < attack:
        return t / attack
    x = (t - attack) / max(1e-6, dur - attack)
    return max(0.0, 1.0 - x) ** curve

def lowpass(samples, cutoff_fn):
    y = 0.0
    res = []
    for i, s in enumerate(samples):
        fc = cutoff_fn(i / SR)
        a = 1.0 - math.exp(-2 * math.pi * fc / SR)
        y += a * (s - y)
        res.append(y)
    return res

def save(name, samples, gain=0.8):
    peak = max(1e-6, max(abs(s) for s in samples))
    fade = int(0.004 * SR)
    with wave.open(os.path.join(out, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        frames = bytearray()
        n = len(samples)
        for i, s in enumerate(samples):
            v = s / peak * gain
            if i > n - fade:
                v *= (n - i) / fade
            frames += struct.pack("<h", int(max(-1, min(1, v)) * 32767))
        w.writeframes(bytes(frames))

def n(dur):
    return int(dur * SR)

def noise(dur):
    return [random.uniform(-1, 1) for _ in range(n(dur))]

def sweep(f0, f1, dur, wave_fn=math.sin):
    ph = 0.0; res = []
    for i in range(n(dur)):
        t = i / SR
        f = f0 * (f1 / f0) ** (t / dur)
        ph += 2 * math.pi * f / SR
        res.append(wave_fn(ph))
    return res

sq = lambda p: 1.0 if math.sin(p) >= 0 else -1.0
saw = lambda p: ((p / math.pi) % 2.0) - 1.0

# Sword swing: filtered noise whoosh with a rising-then-falling cutoff
d = 0.2
s = lowpass(noise(d), lambda t: 600 + 5000 * math.sin(math.pi * t / d))
save("sfx_sword_swing", [v * math.sin(math.pi * i / n(d)) ** 1.5 for i, v in enumerate(s)], 0.6)

# Hit: punchy pitch drop + noise crack
d = 0.16
body = sweep(220, 55, d)
crack = lowpass(noise(d), lambda t: 3000)
save("sfx_hit", [(body[i] * 0.9 + crack[i] * 0.5 * env(i / SR, 0.04, 0.001, 2)) * env(i / SR, d, 0.001, 2.5) for i in range(n(d))])

# Enemy death: longer drop + noise
d = 0.4
body = sweep(300, 40, d, sq)
nz = lowpass(noise(d), lambda t: 2500 * (1 - t / d) + 200)
save("sfx_enemy_die", [(body[i] * 0.4 + nz[i] * 0.6) * env(i / SR, d, 0.002, 1.8) for i in range(n(d))], 0.7)

# Player hurt: harsh square drop
d = 0.22
body = sweep(500, 140, d, sq)
save("sfx_player_hurt", [body[i] * env(i / SR, d, 0.002, 1.5) for i in range(n(d))], 0.5)

# Shield block: metallic clank (inharmonic partials)
d = 0.3
parts = [(820, 1.0, 9), (1290, 0.7, 12), (2130, 0.5, 16), (3410, 0.3, 22)]
clk = noise(0.01)
res = []
for i in range(n(d)):
    t = i / SR
    v = sum(a * math.sin(2 * math.pi * f * t) * math.exp(-k * t) for f, a, k in parts)
    if i < len(clk):
        v += clk[i] * 0.8
    res.append(v)
save("sfx_shield_block", res, 0.65)

# Reflect: bright rising sweep + shimmer partials (the "perfect" sound)
d = 0.45
up = sweep(500, 2400, d * 0.6, sq) + [0.0] * (n(d) - n(d * 0.6))
res = []
for i in range(n(d)):
    t = i / SR
    shimmer = sum(math.sin(2 * math.pi * f * t) for f in (1760, 2637, 3520)) * math.exp(-5 * t) / 3
    res.append(up[i] * 0.35 * env(t, d * 0.6, 0.002, 1) + shimmer * 0.8)
save("sfx_reflect", res, 0.6)

# Dash: short airy whoosh
d = 0.14
s = lowpass(noise(d), lambda t: 1500 + 6000 * (t / d))
save("sfx_dash", [v * math.sin(math.pi * i / n(d)) for i, v in enumerate(s)], 0.45)

# Portal: rising swirl with tremolo
d = 1.1
tone = sweep(110, 880, d)
tone2 = sweep(165, 1320, d)
nz = lowpass(noise(d), lambda t: 400 + 3000 * t / d)
res = []
for i in range(n(d)):
    t = i / SR
    trem = 0.6 + 0.4 * math.sin(2 * math.pi * (4 + 10 * t) * t)
    e = math.sin(math.pi * t / d) ** 0.7
    res.append((tone[i] * 0.5 + tone2[i] * 0.3 + nz[i] * 0.4) * trem * e)
save("sfx_portal", res, 0.65)

# Pickup: two quick rising blips
res = []
for f, d in ((988, 0.07), (1480, 0.12)):
    for i in range(n(d)):
        t = i / SR
        res.append(sq(2 * math.pi * f * t) * env(t, d, 0.002, 1.2))
save("sfx_pickup", res, 0.4)

# Artifact get: arpeggio
res = []
for f in (523, 659, 784, 1047):
    d = 0.09
    for i in range(n(d)):
        t = i / SR
        res.append((sq(2 * math.pi * f * t) * 0.5 + math.sin(2 * math.pi * f * 2 * t) * 0.5) * env(t, d, 0.002, 0.8))
d = 0.35
for i in range(n(d)):
    t = i / SR
    res.append(math.sin(2 * math.pi * 1047 * t) * env(t, d, 0.002, 2))
save("sfx_artifact", res, 0.45)

# Boss roar: low detuned saws with vibrato + noise, soft-clipped
d = 1.4
ph1 = ph2 = 0.0
nz = lowpass(noise(d), lambda t: 900)
res = []
for i in range(n(d)):
    t = i / SR
    f = 75 + 25 * math.sin(math.pi * t / d) + 4 * math.sin(2 * math.pi * 7 * t)
    ph1 += 2 * math.pi * f / SR
    ph2 += 2 * math.pi * f * 1.51 / SR
    v = saw(ph1) + 0.6 * saw(ph2) + 0.8 * nz[i]
    v = math.tanh(2.5 * v)
    e = min(1.0, t / 0.15) * (1 - t / d) ** 0.8
    res.append(v * e)
save("sfx_boss_roar", lowpass(res, lambda t: 1800), 0.8)

# UI confirm: soft blip
d = 0.08
save("sfx_ui_confirm", [math.sin(2 * math.pi * 1200 * i / SR) * env(i / SR, d, 0.002, 2) for i in range(n(d))], 0.35)

# Mirror shatter (final): glassy noise burst + falling partials
d = 1.6
nz = noise(d)
res = []
for i in range(n(d)):
    t = i / SR
    glass = sum(math.sin(2 * math.pi * f * t) * math.exp(-k * t) for f, k in ((2793, 3), (3951, 4), (5274, 6), (1864, 2.5)))
    v = nz[i] * math.exp(-6 * t) * 0.9 + glass * 0.25 * (1 + 0.5 * random.random())
    res.append(v)
save("sfx_mirror_shatter", lowpass(res, lambda t: 9000 - 5000 * t / d), 0.75)

print("ok", sorted(os.listdir(out)))
