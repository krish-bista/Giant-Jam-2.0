"""Voices for INVERTED SOUL, made with Kokoro (open-weight neural TTS, Apache-2.0).

Usage (needs `pip install kokoro-onnx soundfile scipy` and the model files
kokoro-v1.0.onnx + voices-v1.0.bin from github.com/thewh1teagle/kokoro-onnx/releases):

    python make_voices_kokoro.py <model dir> <project>/audio/voice [--only speaker,...]

Reads voice_lines.json next to this script: {"speaker", "text", optional "say" (what is spoken
when it differs from the on-screen text) and "speed"}. Writes <speaker>_<md5(text)[:10]>.wav,
the name Voice.say() looks for.

Each character has its own voice, pace and pauses, and only light, natural processing
(a room, a helmet, a radio) instead of heavy robot effects. Both of your reflections are
made from YOUR voice: the ally is pitched slightly up and airy, the Reflection is pitched
down and swells in reversed, like sound played backwards.
"""
import hashlib, json, os, sys
import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt, fftconvolve, resample_poly
from kokoro_onnx import Kokoro

MODEL_DIR, OUT = sys.argv[1], sys.argv[2]
ONLY = set(sys.argv[sys.argv.index("--only") + 1].split(",")) if "--only" in sys.argv else None
HERE = os.path.dirname(os.path.abspath(__file__))
SR = 24000
rng = np.random.default_rng(7)

# voice, speed, lang, sentence pause, clause pause, pitch (semitones)
CAST = {
    "you":        dict(voice=("am_michael", 0.75, "am_puck", 0.25), speed=1.0, lang="en-us", sp=0.28, cp=0.12, pitch=0.0),
    "reflection": dict(voice=("am_michael", 0.75, "am_puck", 0.25), speed=0.97, lang="en-us", sp=0.3, cp=0.12, pitch=1.5),
    "evil":       dict(voice=("am_michael", 0.75, "am_puck", 0.25), speed=1.02, lang="en-us", sp=0.3, cp=0.14, pitch=-2.6),
    "elder":      dict(voice=("bm_george", 1.0), speed=0.97, lang="en-gb", sp=0.3, cp=0.12, pitch=-0.6),
    "narrator":   dict(voice=("af_heart", 1.0), speed=0.97, lang="en-us", sp=0.34, cp=0.14, pitch=0.0),
    "system":     dict(voice=("af_bella", 1.0), speed=1.03, lang="en-us", sp=0.22, cp=0.1, pitch=0.0),
    "echo":       dict(voice=("bf_isabella", 0.7, "bf_emma", 0.3), speed=0.95, lang="en-gb", sp=0.32, cp=0.14, pitch=0.0),
    "terminal":   dict(voice=("af_nicole", 1.0), speed=1.02, lang="en-us", sp=0.28, cp=0.12, pitch=0.0),
    "hypnotic":   dict(voice=("af_nicole", 1.0), speed=0.86, lang="en-us", sp=0.45, cp=0.2, pitch=-1.0),
    "warden":     dict(voice=("am_fenrir", 1.0), speed=0.95, lang="en-us", sp=0.35, cp=0.14, pitch=-3.0),
    "sentinel":   dict(voice=("bm_fable", 1.0), speed=0.92, lang="en-gb", sp=0.4, cp=0.15, pitch=-2.0),
}


# ---------------- DSP ----------------
def band(x, lo=None, hi=None, order=2):
    if lo:
        x = sosfilt(butter(order, lo, "highpass", fs=SR, output="sos"), x)
    if hi:
        x = sosfilt(butter(order, hi, "lowpass", fs=SR, output="sos"), x)
    return x


def room(x, mix=0.15, size=0.5, bright=6000):
    """Convolution reverb with a synthetic decaying-noise impulse (a natural space, not a robot)."""
    n = int(SR * (0.25 + size * 1.6))
    t = np.arange(n) / SR
    ir = rng.normal(0, 1, n) * np.exp(-t * (6.5 / (0.25 + size * 1.6)))
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    ir = band(ir, 120, bright)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet = fftconvolve(x, ir)
    dry = np.concatenate([x, np.zeros(len(wet) - len(x))])
    return dry * (1 - mix) + wet * mix * 0.9


def pitch(x, semis):
    if abs(semis) < 0.05:
        return x
    f = 2 ** (semis / 12.0)
    up, down = 1000, int(round(1000 * f))
    return resample_poly(x, up, down)


def chorus(x, depth=0.0025, rate=0.7, mix=0.35):
    t = np.arange(len(x)) / SR
    idx = np.arange(len(x)) - (depth * SR) * (1 + np.sin(2 * np.pi * rate * t))
    return x * (1 - mix) + np.interp(np.clip(idx, 0, len(x) - 1), np.arange(len(x)), x) * mix


def soft(x, drive=1.4):
    return np.tanh(x * drive) / np.tanh(drive)


def compress(x, thresh=0.35, ratio=3.0):
    env = np.abs(x)
    a = 1 - np.exp(-1 / (0.005 * SR))
    r = 1 - np.exp(-1 / (0.08 * SR))
    e = np.zeros_like(env)
    acc = 0.0
    for i in range(0, len(env), 64):
        v = env[i:i + 64].max()
        acc = acc + (a if v > acc else r) * 64 * (v - acc)
        acc = max(acc, 0.0)
        e[i:i + 64] = acc
    gain = np.where(e > thresh, (thresh + (e - thresh) / ratio) / (e + 1e-9), 1.0)
    return x * gain


def reverse_swell(x, mix=0.4):
    """A reversed reverb that swells INTO each word: the line sounds played backwards first."""
    tail = room(x[::-1], 1.0, 0.7, 5000)[::-1]
    pre = len(tail) - len(x)
    out = np.zeros(len(tail))
    out[pre:] += x
    return out + tail * mix


def echo_taps(x, delay=0.17, fb=0.35, n=3):
    d = int(delay * SR)
    out = np.zeros(len(x) + d * n)
    out[: len(x)] += x
    for k in range(1, n + 1):
        out[d * k: d * k + len(x)] += x * fb ** k
    return out


def vibrato(x, rate=5.0, depth=0.0035):
    t = np.arange(len(x)) / SR
    idx = np.arange(len(x)) - depth * SR * np.sin(2 * np.pi * rate * t)
    return np.interp(np.clip(idx, 0, len(x) - 1), np.arange(len(x)), x)


def bitcrush(x, bits=9, hold=2):
    q = 2 ** bits
    y = np.round(x * q) / q
    return np.repeat(y[::hold], hold)[: len(x)]


FX = {
    "you":        lambda x: room(band(x, 80), 0.08, 0.25),
    "reflection": lambda x: room(chorus(band(x, 160)), 0.28, 0.6, 7000),
    "evil":       lambda x: room(reverse_swell(soft(band(x, 70), 1.25), 0.38), 0.18, 0.6, 5000),
    "elder":      lambda x: room(band(x, 70, 9000), 0.14, 0.4),
    "narrator":   lambda x: room(band(x, 60), 0.2, 0.75),
    "system":     lambda x: room(chorus(band(x, 240, 7000), 0.0015, 0.5, 0.2), 0.08, 0.2),
    "echo":       lambda x: room(band(x, 150, 4200), 0.45, 1.0, 4500) * 0.85,
    "terminal":   lambda x: bitcrush(band(x, 380, 4200, 3), 9, 2) + rng.normal(0, 0.004, len(x)),
    "hypnotic":   lambda x: room(echo_taps(vibrato(x), 0.19, 0.3, 3), 0.25, 0.7),
    "warden":     lambda x: room(soft(band(x, 60, 6000), 1.6), 0.22, 0.6),
    "sentinel":   lambda x: room(chorus(band(x, 90, 6500), 0.004, 1.3, 0.35), 0.3, 0.7),
}


def style(k, spec):
    v = spec["voice"]
    s = k.get_voice_style(v[0]) * v[1]
    for i in range(2, len(v), 2):
        s = s + k.get_voice_style(v[i]) * v[i + 1]
    return s


def main():
    k = Kokoro(os.path.join(MODEL_DIR, "kokoro-v1.0.onnx"), os.path.join(MODEL_DIR, "voices-v1.0.bin"))
    lines = json.load(open(os.path.join(HERE, "voice_lines.json")))
    os.makedirs(OUT, exist_ok=True)
    made = 0
    for ln in lines:
        sp = ln["speaker"]
        if ONLY and sp not in ONLY:
            continue
        spec = CAST[sp]
        text = ln.get("say", ln["text"])
        speed = spec["speed"] * ln.get("speed", 1.0)
        # Pitch-shifting by resampling also changes the pace; mostly compensate for it.
        speed /= (2 ** (spec["pitch"] / 12.0)) ** 0.7
        audio, sr = k.create(text, voice=style(k, spec), speed=speed, lang=spec["lang"],
                             sentence_pause=spec["sp"], clause_pause=spec["cp"])
        x = audio.astype(np.float64)
        x = pitch(x, spec["pitch"])
        x = np.concatenate([np.zeros(int(0.06 * SR)), x, np.zeros(int(0.12 * SR))])
        x = compress(x / (np.max(np.abs(x)) + 1e-9))
        y = FX[sp](x)
        y = y / (np.max(np.abs(y)) + 1e-9) * (0.6 if sp == "echo" else 0.85)
        name = "%s_%s.wav" % (sp, hashlib.md5(ln["text"].encode("utf-8")).hexdigest()[:10])
        sf.write(os.path.join(OUT, name), y.astype(np.float32), SR, subtype="PCM_16")
        made += 1
        print("%-10s %5.1fs  %s" % (sp, len(y) / SR, ln["text"]))
    print("voices made:", made)


if __name__ == "__main__":
    main()
