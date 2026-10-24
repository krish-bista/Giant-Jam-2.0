"""Adds per-character effects to raw TTS lines. Usage: python process_voices.py <raw dir> <project>/audio/voice"""
import math, os, sys, wave
import numpy as np

RAW, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
SR = 22050
rng = np.random.default_rng(1)


def read(path):
    with wave.open(path) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768
    # trim silence
    idx = np.where(np.abs(x) > 0.01)[0]
    if len(idx):
        x = x[max(0, idx[0] - 300): idx[-1] + 600]
    return x


def write(path, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def onepole_lp(x, fc):
    a = 1 - math.exp(-2 * math.pi * fc / SR)
    y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc); y[i] = acc
    return y


def hp(x, fc):
    return x - onepole_lp(x, fc)


def reverb(x, mix=0.3, decay=0.6, tail=1.2):
    n = len(x) + int(tail * SR)
    out = np.zeros(n); out[:len(x)] = x
    wet = np.zeros(n)
    for dl in (0.0297, 0.0371, 0.0411, 0.0437, 0.0503, 0.0571):
        d = int(dl * SR)
        buf = out.copy()
        for i in range(d, n, d):
            seg = buf[i - d:i] * decay
            buf[i:i + d] += seg[:len(buf[i:i + d])]
        wet += buf
    wet = onepole_lp(wet / 6, 5000)
    return out * (1 - mix) + wet * mix


def echo(x, delay=0.18, fb=0.4, n=3):
    d = int(delay * SR)
    out = np.zeros(len(x) + d * n); out[:len(x)] += x
    for k in range(1, n + 1):
        out[d * k:d * k + len(x)] += x * (fb ** k)
    return out


def distort(x, drive=3.0):
    return np.tanh(x * drive) / np.tanh(drive)


def bitcrush(x, bits=6, hold=3):
    q = 2 ** bits
    y = np.round(x * q) / q
    return np.repeat(y[::hold], hold)[:len(x)]


def ringmod(x, f, depth=0.4):
    t = np.arange(len(x)) / SR
    return x * (1 - depth + depth * np.sin(2 * math.pi * f * t))


def vibrato(x, rate=5.0, depth=0.004):
    t = np.arange(len(x)) / SR
    idx = np.arange(len(x)) - depth * SR * np.sin(2 * math.pi * rate * t)
    idx = np.clip(idx, 0, len(x) - 1)
    return np.interp(idx, np.arange(len(x)), x)


def chorus(x):
    return 0.6 * x + 0.4 * vibrato(x, 0.8, 0.003)


def comb(x, f=180.0, fb=0.6):
    d = max(1, int(SR / f))
    y = x.copy()
    for i in range(d, len(y)):
        y[i] += fb * y[i - d]
    return y


def reverse_swell(x):
    """Evil You: a reversed reverb that swells into each line (sound played backwards)."""
    rev = reverb(x[::-1], mix=1.0, decay=0.7, tail=0.8)[::-1]
    pre = len(rev) - len(x)
    out = np.zeros(len(rev)); out[pre:] += x
    return out + rev * 0.55


FX = {
    "you": lambda x: reverb(x, 0.12, 0.4, 0.4),
    "stranger": lambda x: reverb(onepole_lp(x, 6000), 0.22, 0.5, 0.8),
    "system": lambda x: reverb(chorus(hp(onepole_lp(x, 5200), 280)), 0.18, 0.45, 0.5),
    "terminal": lambda x: bitcrush(ringmod(hp(x, 400), 55, 0.35), 5, 3) + rng.normal(0, 0.012, len(x)),
    "echo": lambda x: reverb(onepole_lp(x, 3500), 0.55, 0.7, 1.6) * 0.8,
    "hypnotic": lambda x: echo(vibrato(x, 6.0, 0.006), 0.16, 0.45, 3),
    "warden": lambda x: reverb(distort(onepole_lp(x, 3500), 2.5), 0.3, 0.6, 1.0),
    "sentinel": lambda x: reverb(comb(x, 140, 0.55), 0.35, 0.6, 1.0),
    "evil": lambda x: reverse_swell(distort(x, 1.6)),
    "narrator": lambda x: reverb(x, 0.35, 0.65, 1.8),
    "elder": lambda x: reverb(onepole_lp(x, 4500), 0.28, 0.55, 1.0),
    "reflection": lambda x: reverb(chorus(hp(x, 250)), 0.45, 0.65, 1.4),
}

n = 0
for f in sorted(os.listdir(RAW)):
    if not f.endswith(".wav"):
        continue
    speaker = f.split("_")[0]
    x = read(os.path.join(RAW, f))
    y = FX.get(speaker, lambda v: v)(x)
    write(os.path.join(OUT, f), y, 0.85 if speaker != "echo" else 0.6)
    n += 1
print("processed", n)
