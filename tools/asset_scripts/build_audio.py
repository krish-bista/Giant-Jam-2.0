"""Builds Echo Breach audio: synthesized signature sounds + picks from CC0 packs.

Usage: python build_audio.py "<Ninja Adventure pack>" "<kenney downloads dir>" "<project>/audio"
"""
import math, os, shutil, sys, wave
import numpy as np

PACK, KEN, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
SR = 44100
rng = np.random.default_rng(3)
SFX = os.path.join(OUT, "sfx")
MUS = os.path.join(OUT, "music")
os.makedirs(SFX, exist_ok=True)
os.makedirs(MUS, exist_ok=True)


def save(name, x, gain=0.9):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fade = int(0.005 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(SFX, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())


def t(d):
    return np.arange(int(d * SR)) / SR


def env(d, a=0.002, k=6.0):
    tt = t(d)
    e = np.exp(-k * tt)
    n = int(a * SR)
    if n > 0:
        e[:n] *= np.linspace(0, 1, n)
    return e


def noise(d):
    return rng.uniform(-1, 1, int(d * SR))


def lowpass(x, fc):
    a = 1 - math.exp(-2 * math.pi * fc / SR)
    y = np.zeros_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc); y[i] = acc
    return y


def highpass(x, fc):
    return x - lowpass(x, fc)


def sweep(f0, f1, d, shape=np.sin):
    tt = t(d)
    f = f0 * (f1 / f0) ** (tt / d)
    return shape(2 * math.pi * np.cumsum(f) / SR)


def reverb(x, mix=0.3, decay=0.55):
    out = np.concatenate([x, np.zeros(int(0.9 * SR))])
    wet = np.zeros_like(out)
    for dl, g in ((0.0297, 1.0), (0.0371, 0.9), (0.0411, 0.85), (0.0437, 0.8), (0.053, 0.7)):
        n = int(dl * SR)
        buf = np.zeros_like(out)
        for i in range(n, len(out)):
            buf[i] = out[i - n] + decay * buf[i - n]
        wet += buf * g
    wet = lowpass(wet, 6000)
    return out * (1 - mix) + wet / 5 * mix * 3


def pad(x, d):
    n = int(d * SR)
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:max(n, len(x))]


def mix(*layers):
    n = max(len(l) for l in layers)
    return sum(pad(l, n / SR) for l in layers)


# ---- Perfect deflect: click + metallic shimmer + rising air + sub thump + reverb ----
d = 1.1
click = noise(0.012) * np.linspace(1, 0, int(0.012 * SR))
ring = np.zeros(int(d * SR)); tt = t(d)
for f, a, k in ((1975, 1.0, 3.2), (2961, 0.8, 4.0), (3951, 0.6, 5.0), (5274, 0.45, 6.5), (2093, 0.5, 3.0), (7040, 0.25, 9.0)):
    ring += a * np.sin(2 * math.pi * f * tt + 0.6 * np.sin(2 * math.pi * 5.5 * tt)) * np.exp(-k * tt)
air = highpass(noise(0.22), 2500) * np.sin(np.linspace(0, math.pi, int(0.22 * SR))) ** 2
air = air * np.linspace(0.3, 1, len(air))
thump = sweep(140, 45, 0.16) * env(0.16, 0.001, 18)
deflect = mix(click * 1.2, ring * 0.55, air * 0.35, thump * 0.9)
save("sfx_deflect", reverb(deflect, 0.35), 0.95)

# ---- Late block: dull metal clank ----
d = 0.35; tt = t(d)
clank = sum(a * np.sin(2 * math.pi * f * tt) * np.exp(-k * tt) for f, a, k in ((620, 1, 14), (1130, 0.7, 18), (1720, 0.4, 22)))
save("sfx_block", mix(clank, noise(0.02) * 0.6, sweep(120, 60, 0.1) * env(0.1, 0.001, 30) * 0.6), 0.8)

# ---- Sword draw: metallic scrape rising + ring ("shing") ----
d = 0.5; tt = t(d)
scrape = highpass(noise(0.28), 3500) * np.linspace(0.2, 1, int(0.28 * SR)) * np.sin(np.linspace(0, math.pi, int(0.28 * SR)))
shing = sum(a * np.sin(2 * math.pi * f * tt) * np.exp(-k * tt) for f, a, k in ((3200, 1, 6), (4800, 0.6, 8), (6400, 0.3, 10)))
save("sfx_sword_draw", reverb(mix(scrape * 0.7, np.concatenate([np.zeros(int(0.22 * SR)), shing * 0.5])), 0.25), 0.7)

# ---- Sword swings: three airy whooshes ----
for i, (lo, hi, d) in enumerate(((700, 3800, 0.2), (900, 4600, 0.18), (500, 3000, 0.28))):
    n = noise(d)
    tt = t(d)
    cutoff = lo + (hi - lo) * np.sin(np.pi * tt / d)
    y = np.zeros_like(n); acc = 0.0
    for j, v in enumerate(n):
        a = 1 - math.exp(-2 * math.pi * cutoff[j] / SR); acc += a * (v - acc); y[j] = acc
    save("sfx_swing_%d" % (i + 1), y * np.sin(np.pi * tt / d) ** 1.5, 0.6)

# ---- Spin attack whoosh ----
d = 0.45; tt = t(d)
n = noise(d); y = np.zeros_like(n); acc = 0.0
for j, v in enumerate(n):
    c = 800 + 3500 * (0.5 + 0.5 * math.sin(2 * math.pi * 6 * tt[j]))
    a = 1 - math.exp(-2 * math.pi * c / SR); acc += a * (v - acc); y[j] = acc
save("sfx_spin", y * np.sin(np.pi * tt / d), 0.65)

# ---- Crit / riposte sting ----
d = 0.5; tt = t(d)
sting = sum(np.sin(2 * math.pi * f * tt) * np.exp(-4 * tt) for f in (1046, 1568, 2093))
save("sfx_crit", reverb(mix(sting, noise(0.01)), 0.3), 0.7)

# ---- Combo tick ----
for i, f in enumerate((880, 1175, 1568)):
    d = 0.09; tt = t(d)
    save("sfx_combo_%d" % (i + 1), np.sign(np.sin(2 * math.pi * f * tt)) * np.exp(-30 * tt) * 0.6 + np.sin(2 * math.pi * f * 2 * tt) * np.exp(-25 * tt), 0.35)

# ---- Heartbeat (final) ----
d = 0.8; tt = t(d)
beat = np.zeros(int(d * SR))
for start in (0.0, 0.22):
    s = int(start * SR); seg = sweep(70, 40, 0.15) * env(0.15, 0.003, 22)
    beat[s:s + len(seg)] += seg
save("sfx_heartbeat", lowpass(beat, 300), 0.9)

# ---- Boss roar (layered, growly) ----
d = 1.5; tt = t(d)
f = 70 + 30 * np.sin(np.pi * tt / d) + 5 * np.sin(2 * math.pi * 9 * tt)
ph = 2 * math.pi * np.cumsum(f) / SR
roar = np.tanh(3 * (((ph / math.pi) % 2 - 1) + 0.6 * ((ph * 1.49 / math.pi) % 2 - 1) + 0.7 * lowpass(noise(d), 900)))
roar *= np.minimum(1, tt / 0.12) * (1 - tt / d) ** 0.7
save("sfx_boss_roar", reverb(lowpass(roar, 2200), 0.3), 0.85)

# ---- Portal hum/whoosh ----
d = 1.2; tt = t(d)
port = (sweep(110, 880, d) * 0.5 + sweep(165, 1320, d) * 0.3 + lowpass(noise(d), 1500) * 0.4) * (0.6 + 0.4 * np.sin(2 * math.pi * (4 + 10 * tt) * tt)) * np.sin(np.pi * tt / d) ** 0.7
save("sfx_portal", reverb(port, 0.3), 0.7)

# ---- Dash ----
d = 0.16; tt = t(d)
save("sfx_dash", highpass(noise(d), 1500) * np.sin(np.pi * tt / d), 0.45)

# ---------------- picks from packs ----------------
def pick(name, *path):
    src = os.path.join(*path)
    ext = os.path.splitext(src)[1]
    for old_ext in (".wav", ".ogg"):
        old = os.path.join(SFX, name + old_ext)
        if old_ext != ext and os.path.exists(old):
            os.remove(old)
            if os.path.exists(old + ".import"):
                os.remove(old + ".import")
    shutil.copyfile(src, os.path.join(SFX, name + ext))

NS = os.path.join(PACK, "Audio", "Sounds")
KI = os.path.join(KEN, "x_kenney_impact-sounds", "Audio")
KS = os.path.join(KEN, "x_kenney_sci-fi-sounds", "Audio")
KU = os.path.join(KEN, "x_kenney_interface-sounds", "Audio")
KR = os.path.join(KEN, "x_kenney_rpg-audio", "Audio")
pick("sfx_hit", NS, "Hit & Impact", "Hit2.wav")
pick("sfx_hit_heavy", NS, "Hit & Impact", "Impact3.wav")
pick("sfx_player_hurt", NS, "Hit & Impact", "Hit5.wav")
pick("sfx_enemy_die", NS, "Hit & Impact", "Impact.wav")
pick("sfx_explosion", NS, "Elemental", "Explosion2.wav")
pick("sfx_explosion_big", NS, "Elemental", "Explosion5.wav")
pick("sfx_break_wood", KI, "impactPlank_medium_002.ogg")
pick("sfx_break_pot", KI, "impactGlass_medium_001.ogg")
pick("sfx_break_crystal", KI, "impactGlass_heavy_002.ogg")
pick("sfx_coin", NS, "Bonus", "Coin.wav")
pick("sfx_pickup", NS, "Bonus", "PowerUp1.wav")
pick("sfx_artifact", NS, "Bonus", "Bonus2.wav")
pick("sfx_heal", NS, "Magic & Skill", "Heal.wav")
pick("sfx_hypno", NS, "Magic & Skill", "Magic3.wav")
pick("sfx_laser", KS, "laserSmall_000.ogg")
pick("sfx_boss_attack", KS, "laserLarge_000.ogg")
pick("sfx_boss_die", KS, "lowFrequency_explosion_000.ogg")
pick("sfx_glitch", KU, "glitch_002.ogg")
pick("sfx_chest_open", KR, "metalLatch.ogg")
pick("sfx_ui_confirm", NS, "Menu", "Accept.wav")
pick("sfx_dialogue", NS, "Menu", "Move1.wav")
pick("sfx_mirror_shatter", KI, "impactGlass_heavy_000.ogg")
pick("sfx_reflect", KI, "impactBell_heavy_000.ogg")
pick("sfx_shield_block", KI, "impactMetal_medium_000.ogg")
pick("sfx_slam", NS, "Hit & Impact", "Impact5.wav")
pick("sfx_jump", NS, "Jump & Bounce", "Jump2.wav")
for i in range(3):
    pick("sfx_step_grass_%d" % i, KI, "footstep_grass_00%d.ogg" % i)
    pick("sfx_step_stone_%d" % i, KI, "footstep_concrete_00%d.ogg" % i)
    pick("sfx_step_wood_%d" % i, KI, "footstep_wood_00%d.ogg" % i)
pick("amb_rain", NS, "Ambient", "Rain2.wav")
pick("amb_wind", NS, "Ambient", "Wind.wav")
pick("amb_river", NS, "Ambient", "River.wav")
pick("amb_hum", KS, "spaceEngineLow_001.ogg")
for old in ("sfx_sword_swing", "sfx_artifact"):
    pass

# ---------------- music (Ninja Adventure, CC0) ----------------
MUSIC = {
    "music_room": "9 - Quiet.ogg", "music_tutorial": "13 - Mystical.ogg",
    "music_city": "28 - Tension.ogg", "music_city_boss": "17 - Fight.ogg",
    "music_jungle": "11 - Clearing.ogg", "music_jungle_boss": "10 - Dark Castle.ogg",
    "music_core": "21 - Dungeon.ogg", "music_core_boss": "24 - Final Area.ogg",
    "music_final": "14 - Curse.ogg", "music_ending": "16 - Melancholia.ogg",
}
for f in os.listdir(MUS):
    if f.startswith("music_"):
        os.remove(os.path.join(MUS, f))
for key, src in MUSIC.items():
    shutil.copyfile(os.path.join(PACK, "Audio", "Musics", src), os.path.join(MUS, key + ".ogg"))
print("audio built")
