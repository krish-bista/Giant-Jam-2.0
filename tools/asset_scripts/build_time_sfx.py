"""Synthesizes the time-rift sounds (world clock, cracking, shattering, time restored).

Usage: python build_time_sfx.py <project_root>
Writes WAV files into <project_root>/audio/sfx/.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 44100
random.seed(11)


def save(path, samples, gain=0.85):
    peak = max(1e-6, max(abs(s) for s in samples))
    fade = int(0.004 * SR)
    n = len(samples)
    frames = bytearray()
    for i, s in enumerate(samples):
        v = s / peak * gain
        if i > n - fade:
            v *= (n - i) / fade
        frames += struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))


def lowpass(samples, fc):
    a = 1.0 - math.exp(-2 * math.pi * fc / SR)
    y = 0.0
    out = []
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(samples, fc):
    lp = lowpass(samples, fc)
    return [s - l for s, l in zip(samples, lp)]


def click(freq, dur, noise=0.4, decay=60.0):
    out = []
    for i in range(int(dur * SR)):
        t = i / SR
        e = math.exp(-t * decay)
        out.append(e * (math.sin(2 * math.pi * freq * t) + noise * random.uniform(-1, 1)))
    return out


def tick():
    s = click(2600, 0.05, 0.5, 90.0)
    s2 = click(5200, 0.05, 0.0, 140.0)
    return [a + 0.4 * b for a, b in zip(s, s2)]


def tock():
    s = click(1350, 0.07, 0.35, 55.0)
    s2 = click(680, 0.07, 0.0, 45.0)
    return [a + 0.6 * b for a, b in zip(s, s2)]


def ping(freq, dur, decay):
    return [math.exp(-i / SR * decay) * math.sin(2 * math.pi * freq * i / SR) for i in range(int(dur * SR))]


def mix_into(buf, src, start):
    for i, v in enumerate(src):
        j = start + i
        if j < len(buf):
            buf[j] += v


def crack():
    dur = 0.45
    buf = [0.0] * int(dur * SR)
    # the sharp snap
    snap = highpass([random.uniform(-1, 1) * math.exp(-i / SR * 70.0) for i in range(int(0.08 * SR))], 2500)
    mix_into(buf, [v * 1.6 for v in snap], 0)
    # glassy pings
    for f in (4100, 5600, 7300, 3300):
        mix_into(buf, [v * 0.35 for v in ping(f * random.uniform(0.95, 1.05), 0.3, 22.0)], int(random.uniform(0, 0.02) * SR))
    # the crack running through the glass: tiny ticks
    t = 0.04
    while t < 0.32:
        burst = highpass([random.uniform(-1, 1) * math.exp(-i / SR * 400.0) for i in range(int(0.012 * SR))], 3000)
        mix_into(buf, [v * random.uniform(0.3, 0.8) for v in burst], int(t * SR))
        t += random.uniform(0.008, 0.03)
    return buf


def shatter_big():
    dur = 2.2
    buf = [0.0] * int(dur * SR)
    # the boom
    boom = [math.exp(-i / SR * 3.2) * (math.sin(2 * math.pi * (58 - 18 * i / SR) * i / SR) + 0.5 * math.sin(2 * math.pi * 92 * i / SR)) for i in range(int(1.6 * SR))]
    mix_into(buf, [v * 0.9 for v in boom], 0)
    # the burst of glass
    noise = highpass([random.uniform(-1, 1) * math.exp(-i / SR * 4.5) for i in range(int(1.2 * SR))], 1800)
    mix_into(buf, [v * 0.8 for v in noise], 0)
    # hundreds of falling shards
    for _ in range(140):
        start = random.expovariate(2.2)
        if start > 1.9:
            continue
        f = random.uniform(2500, 9000)
        mix_into(buf, [v * random.uniform(0.08, 0.3) * math.exp(-start * 1.2) for v in ping(f, 0.18, random.uniform(25, 60))], int(start * SR))
    return buf


def time_restore():
    dur = 1.1
    out = []
    ph1 = ph2 = ph3 = 0.0
    for i in range(int(dur * SR)):
        t = i / SR
        p = t / dur
        f = 380 + 1300 * p * p
        ph1 += 2 * math.pi * f / SR
        ph2 += 2 * math.pi * f * 1.5 / SR
        ph3 += 2 * math.pi * f * 2.01 / SR
        e = min(1.0, t / 0.05) * (1.0 - p) ** 0.6
        trem = 0.75 + 0.25 * math.sin(2 * math.pi * 14 * t)
        out.append(e * trem * (math.sin(ph1) + 0.5 * math.sin(ph2) + 0.3 * math.sin(ph3)))
    # chime at the end
    mix_into(out, [v * 0.8 for v in ping(1760, 0.5, 9.0)], int(0.55 * SR))
    mix_into(out, [v * 0.5 for v in ping(2637, 0.45, 10.0)], int(0.6 * SR))
    return out


def time_warn():
    """A reversed whoosh: swells up and cuts off, like a sound played backwards."""
    dur = 0.9
    n = int(dur * SR)
    raw = [random.uniform(-1, 1) for _ in range(n)]
    out = []
    y = 0.0
    for i, s in enumerate(raw):
        p = i / n
        fc = 200 + 3200 * p ** 2
        a = 1.0 - math.exp(-2 * math.pi * fc / SR)
        y += a * (s - y)
        out.append(y * p ** 2.2)
    # a low reversed tone under it
    for i in range(n):
        p = i / n
        out[i] += 0.5 * p ** 3 * math.sin(2 * math.pi * (110 + 60 * p) * i / SR)
    return out


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    out = os.path.join(root, "audio", "sfx")
    os.makedirs(out, exist_ok=True)
    save(os.path.join(out, "sfx_clock_tick.wav"), tick(), 0.7)
    save(os.path.join(out, "sfx_clock_tock.wav"), tock(), 0.8)
    save(os.path.join(out, "sfx_crack.wav"), crack(), 0.85)
    save(os.path.join(out, "sfx_shatter_big.wav"), shatter_big(), 0.95)
    save(os.path.join(out, "sfx_time_restore.wav"), time_restore(), 0.75)
    save(os.path.join(out, "sfx_time_warn.wav"), time_warn(), 0.8)
    print("time sfx written to", out)


if __name__ == "__main__":
    main()
