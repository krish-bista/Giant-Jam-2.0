"""Builds Echo Breach art from Kenney's CC0 1-Bit Pack. Usage: python make_art.py <tilesheet.png> <assets_dir>"""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SHEET = Image.open(sys.argv[1]).convert("RGBA")
OUT = sys.argv[2]
T = 16
OUTLINE = (12, 10, 18, 255)
random.seed(42)


def tile(c, r):
    return SHEET.crop((c * T, r * T, c * T + T, r * T + T))


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def tint(img, color):
    color = hexc(color) if isinstance(color, str) else color
    px = img.load()
    out = Image.new("RGBA", img.size)
    po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] > 0:
                po[x, y] = (color[0], color[1], color[2], 255)
    return out


def outlined(img):
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2))
    src = img.load()
    po = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        po[x + 1 + dx, y + 1 + dy] = OUTLINE
    out.alpha_composite(img, (1, 1))
    return out


def sprite(c, r, color, scale, outline=True):
    img = tile(c, r)
    if color:
        img = tint(img, color)
    if outline:
        img = outlined(img)
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


# ---------------- characters / enemies / bosses ----------------
SPRITES = {
    "characters/player.png": (28, 0, "#bff4ff", 3),
    "characters/mirror_evil_player.png": (28, 0, "#ff3348", 3),
    "characters/room_npc.png": (24, 0, "#e9dfc9", 3),
    "enemies/tut_dummy.png": (24, 7, "#e0cfa9", 3),
    "enemies/city_drone.png": (19, 7, "#6fb7ff", 3),
    "enemies/city_gunner.png": (19, 8, "#ffcf4a", 3),
    "enemies/jungle_raptor.png": (31, 7, "#d6a960", 3),
    "enemies/jungle_raptor_hunter.png": (31, 7, "#ff5a36", 3),
    "enemies/jungle_brute.png": (30, 8, "#a07850", 4),
    "enemies/core_construct.png": (26, 5, "#d38cff", 3),
    "bosses/city_hypno_boss.png": (25, 8, "#ff4fd8", 5),
    "bosses/city_warden.png": (30, 6, "#8fb4e8", 6),
    "bosses/jungle_alpha_rex.png": (29, 8, "#7fd34e", 6),
    "bosses/core_sentinel.png": (29, 5, "#ea55ff", 6),
    "props/prop_helmet.png": (37, 0, "#c8f6ff", 3),
    "props/prop_table.png": (2, 7, None, 3),
    "props/prop_chest_closed.png": (8, 6, None, 3),
    "props/prop_chest_open.png": (9, 6, "#ffd166", 3),
    "props/prop_heal_orb.png": (39, 10, None, 2),
    "props/prop_xp_orb.png": (33, 10, None, 2),
    "props/prop_sword.png": (34, 7, "#e8fbff", 3),
    "props/prop_shield.png": (39, 4, "#9fe8ff", 3),
    "props/prop_artifact.png": (32, 10, "#ffe27a", 2),
    "props/prop_terminal.png": (10, 6, "#c77dff", 3),
}
for rel, (c, r, col, s) in SPRITES.items():
    save(sprite(c, r, col, s), rel)

# player sword / shield overlays
save(sprite(34, 7, "#e8fbff", 2), "characters/player_sword.png")
save(sprite(39, 4, "#9fe8ff", 2), "characters/player_shield.png")

# ---------------- icons (artifacts + abilities) ----------------
def icon(c, r, color, border):
    base = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((0, 0, 31, 31), 5, fill=hexc("#0d0b16"), outline=hexc(border), width=2)
    sp = outlined(tint(tile(c, r), color))  # 18x18
    base.alpha_composite(sp, (7, 7))
    return base

ICONS = {
    "ui/ui_artifact_edge_shard.png": (32, 10, "#ffb04a", "#ffb04a"),
    "ui/ui_artifact_heart_fragment.png": (40, 10, "#ff5d73", "#9be7a0"),
    "ui/ui_artifact_quick_sigil.png": (40, 1, "#7fe0ff", "#9be7a0"),
    "ui/ui_artifact_lucky_coin.png": (41, 3, "#ffd84a", "#9be7a0"),
    "ui/ui_artifact_mirror_polish.png": (39, 13, "#dff6ff", "#6fb7ff"),
    "ui/ui_artifact_blood_echo.png": (41, 11, "#ff3a52", "#6fb7ff"),
    "ui/ui_artifact_hypno_lens.png": (40, 2, "#ff4fd8", "#6fb7ff"),
    "ui/ui_artifact_echo_blade.png": (33, 7, "#bff4ff", "#6fb7ff"),
    "ui/ui_artifact_double_reflection.png": (38, 4, "#e9f7ff", "#ffcf4a"),
    "ui/ui_artifact_glass_heart.png": (41, 10, "#ff9db0", "#ffcf4a"),
}
for rel, (c, r, col, b) in ICONS.items():
    save(icon(c, r, col, b), rel)

def ability_icon(c, r, color, rel):
    base = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((0, 0, 31, 31), 6, fill=hexc("#101826"), outline=hexc(color), width=2)
    base.alpha_composite(outlined(tint(tile(c, r), color)), (7, 7))
    save(base, rel)

ability_icon(34, 7, "#bff4ff", "ui/ui_icon_sword.png")
ability_icon(39, 4, "#7fe0ff", "ui/ui_icon_shield.png")
ability_icon(40, 2, "#ff4fd8", "ui/ui_icon_hypno.png")
ability_icon(40, 1, "#9be7a0", "ui/ui_icon_dash.png")

# ---------------- portals / fx ----------------
def portal(core, glow, rel):
    W, H = 64, 96
    img = Image.new("RGBA", (W, H))
    g = Image.new("RGBA", (W, H))
    dg = ImageDraw.Draw(g)
    shard = [(32, 4), (52, 30), (44, 92), (18, 88), (12, 34)]
    dg.polygon(shard, fill=hexc(glow, 200))
    g = g.filter(ImageFilter.GaussianBlur(5))
    img.alpha_composite(g)
    d = ImageDraw.Draw(img)
    inner = [(32, 10), (47, 32), (41, 86), (21, 83), (17, 36)]
    d.polygon(inner, fill=hexc(core, 235), outline=(255, 255, 255, 255))
    d.line([(32, 10), (30, 50), (41, 86)], fill=(255, 255, 255, 180), width=1)
    d.line([(17, 36), (30, 50), (47, 32)], fill=(255, 255, 255, 140), width=1)
    d.polygon([(26, 22), (32, 14), (34, 30)], fill=(255, 255, 255, 200))
    save(img, rel)

portal("#bdf3ff", "#5fe0ff", "props/prop_portal.png")
portal("#ffd0d6", "#ff2a40", "props/prop_portal_final.png")

bolt = Image.new("RGBA", (16, 8))
db = ImageDraw.Draw(bolt)
db.ellipse((0, 1, 15, 6), fill=(255, 120, 60, 160))
db.ellipse((3, 2, 12, 5), fill=(255, 245, 200, 255))
save(bolt, "props/fx_bolt.png")

# ---------------- backgrounds ----------------
W, H, B = 1280, 720, 48

def floor(base, line, cell=32, line_alpha=60):
    img = Image.new("RGBA", (W, H), hexc(base))
    d = ImageDraw.Draw(img)
    lc = hexc(line, line_alpha)
    for x in range(0, W, cell):
        d.line([(x, 0), (x, H)], fill=lc)
    for y in range(0, H, cell):
        d.line([(0, y), (W, y)], fill=lc)
    return img

def scatter(img, tiles, color, n, scale=2, alpha=255, inner=False):
    for _ in range(n):
        c, r = random.choice(tiles)
        sp = tint(tile(c, r), color)
        if alpha < 255:
            sp.putalpha(sp.getchannel("A").point(lambda v: v * alpha // 255))
        sp = sp.resize((T * scale, T * scale), Image.NEAREST)
        if inner:
            x = random.randint(B + 20, W - B - 20 - sp.width)
            y = random.randint(B + 20, H - B - 20 - sp.height)
        else:
            side = random.choice("tblr")
            if side in "tb":
                x = random.randint(0, W - sp.width)
                y = random.randint(0, B - sp.height // 2) if side == "t" else random.randint(H - B - sp.height // 2, H - sp.height)
            else:
                y = random.randint(0, H - sp.height)
                x = random.randint(0, B - sp.width // 2) if side == "l" else random.randint(W - B - sp.width // 2, W - sp.width)
        img.alpha_composite(sp, (x, y))

def border(img, color, width=4):
    d = ImageDraw.Draw(img)
    d.rectangle((B, B, W - B, H - B), outline=hexc(color), width=width)

def band(img, color, alpha=255):
    d = ImageDraw.Draw(img)
    c = hexc(color, alpha)
    d.rectangle((0, 0, W, B), fill=c); d.rectangle((0, H - B, W, H), fill=c)
    d.rectangle((0, 0, B, H), fill=c); d.rectangle((W - B, 0, W, H), fill=c)

def vignette(img, strength=110):
    v = Image.new("L", (W, H), 0)
    dv = ImageDraw.Draw(v)
    for i in range(40):
        a = int(strength * (1 - i / 40) ** 2)
        dv.rectangle((i * 8, i * 5, W - i * 8, H - i * 5), outline=a, width=8)
    black = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    black.putalpha(v.filter(ImageFilter.GaussianBlur(30)))
    img.alpha_composite(black)

# Amnesia room: soft white/cyan, furniture around the walls
img = floor("#cfe9ee", "#7fb7c4", 32, 70)
band(img, "#5b7d88")
scatter(img, [(5, 6), (3, 6), (4, 6), (1, 8), (0, 8), (6, 7), (3, 7), (4, 7)], "#e8f6f8", 60)
border(img, "#ffffff", 3)
vignette(img, 90)
save(img, "tiles/room_bg.png")

# Tutorial VR box: white grid, cyan glow lines
img = floor("#eef9fb", "#4fd6ee", 48, 110)
band(img, "#bfeef6")
d = ImageDraw.Draw(img)
for i in range(6):
    d.rectangle((B + i * 3, B + i * 3, W - B - i * 3, H - B - i * 3), outline=hexc("#5fe0ff", 160 - i * 25), width=1)
scatter(img, [(37, 12), (38, 12), (43, 10)], "#7fe0ff", 12, 2, 120, inner=True)
save(img, "tiles/tut_bg.png")

# City: blue/grey asphalt, road markings, buildings around
img = floor("#3a4658", "#56657c", 64, 80)
d = ImageDraw.Draw(img)
for x in range(B + 40, W - B, 120):
    d.rectangle((x, H // 2 - 4, x + 60, H // 2 + 4), fill=hexc("#c9d3e0", 120))
for y in (B + 120, H - B - 120):
    d.line([(B, y), (W - B, y)], fill=hexc("#6f7f96", 120), width=3)
band(img, "#1f2735")
scatter(img, [(0, 19), (1, 19), (2, 19), (3, 19), (4, 19), (0, 20), (1, 20), (2, 20), (4, 20), (0, 21), (1, 21), (2, 21), (3, 21), (5, 21), (7, 21)], "#7f93b3", 90)
scatter(img, [(15, 13), (14, 21), (13, 12)], "#8ca0bf", 14, 2, 90, inner=True)
border(img, "#9fb6d8", 3)
vignette(img, 120)
save(img, "tiles/city_bg.png")

# Jungle: green/brown, trees band, grass tufts
img = floor("#3e5a2c", "#4f6e34", 64, 40)
d = ImageDraw.Draw(img)
for _ in range(60):
    x, y = random.randint(B, W - B), random.randint(B, H - B)
    d.ellipse((x - 40, y - 25, x + 40, y + 25), fill=hexc("#4a3a26", 22))
band(img, "#1f2f16")
scatter(img, [(0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (3, 2), (4, 2), (1, 2)], "#5fcf5a", 140, 3)
scatter(img, [(5, 0), (6, 0), (7, 0), (0, 2)], "#78b04a", 60, 2, 160, inner=True)
border(img, "#2c4a1c", 3)
vignette(img, 130)
save(img, "tiles/jungle_bg.png")

# Core: purple/neon, split down the middle (mirror line)
img = floor("#1a0d2e", "#7a2fd6", 40, 90)
band(img, "#0b0516")
scatter(img, [(10, 16), (11, 16), (12, 16), (13, 17), (14, 17), (10, 18), (11, 18), (15, 16)], "#9a4dff", 80)
d = ImageDraw.Draw(img)
for i, a in enumerate((60, 120, 255)):
    w = 10 - i * 4
    d.rectangle((W // 2 - w, B, W // 2 + w, H - B), fill=hexc("#ff4ff0", a))
border(img, "#ff4ff0", 3)
vignette(img, 140)
save(img, "tiles/core_bg.png")

# Final mirror room: black, silver, red
img = floor("#08080b", "#3a3a44", 64, 120)
band(img, "#000000")
scatter(img, [(38, 12), (37, 12), (39, 13)], "#c0c0cc", 50, 2, 200)
d = ImageDraw.Draw(img)
d.line([(W // 2, B), (W // 2, H - B)], fill=hexc("#ff2a40", 90), width=2)
border(img, "#c0c0cc", 3)
vignette(img, 160)
save(img, "tiles/mirror_bg.png")

# ---------------- cutscenes ----------------
def big(c, r, color, scale):
    return sprite(c, r, color, scale)

def mirror_frame(img, box, crack=True):
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=hexc("#101018"))
    for i, col in enumerate(("#f0f0f8", "#a8a8b8", "#5a5a66")):
        d.rectangle((x0 - 8 + i * 4, y0 - 8 + i * 4, x1 + 8 - i * 4, y1 + 8 - i * 4), outline=hexc(col), width=4)
    if crack:
        cx, cy = (x0 + x1) // 2 + 40, y0 + 90
        for _ in range(7):
            ang = random.uniform(0, math.pi * 2)
            px, py = cx, cy
            for _ in range(4):
                ang += random.uniform(-0.5, 0.5)
                nx, ny = px + math.cos(ang) * 50, py + math.sin(ang) * 50
                nx = min(max(nx, x0), x1); ny = min(max(ny, y0), y1)
                d.line([(px, py), (nx, ny)], fill=hexc("#dfe3f0", 200), width=2)
                px, py = nx, ny

def glow(img, center, radius, color, alpha=120):
    g = Image.new("RGBA", (W, H))
    dg = ImageDraw.Draw(g)
    x, y = center
    dg.ellipse((x - radius, y - radius, x + radius, y + radius), fill=hexc(color, alpha))
    img.alpha_composite(g.filter(ImageFilter.GaussianBlur(radius // 2)))

PLAYER = (28, 0)
# 1: the player before a huge cracked mirror
img = Image.new("RGBA", (W, H), hexc("#050507"))
glow(img, (640, 330), 300, "#9aa0b8", 50)
mirror_frame(img, (430, 70, 850, 560))
refl = big(*PLAYER, "#9aa6c0", 12)
img.alpha_composite(refl, (640 - refl.width // 2, 300 - refl.height // 2 + 40))
me = big(*PLAYER, "#bff4ff", 9)
img.alpha_composite(me, (640 - me.width // 2, 560))
save(img, "cutscenes/cut_final_01.png")

# 2: close-up, the reflection smiles (red eyes)
img = Image.new("RGBA", (W, H), hexc("#050507"))
mirror_frame(img, (240, 30, 1040, 690), crack=True)
face = big(*PLAYER, "#8a8fa8", 34)
img.alpha_composite(face, (640 - face.width // 2, 360 - face.height // 2))
d = ImageDraw.Draw(img)
for ex in (560, 720):
    glow(img, (ex, 250), 40, "#ff2030", 200)
    d.rectangle((ex - 14, 238, ex + 14, 262), fill=hexc("#ff3348"))
save(img, "cutscenes/cut_final_02.png")

# 3: the evil you steps out, carrying every artifact
img = Image.new("RGBA", (W, H), hexc("#050507"))
mirror_frame(img, (560, 60, 1000, 600))
glow(img, (520, 380), 220, "#ff2030", 90)
evil = big(*PLAYER, "#ff3348", 16)
img.alpha_composite(evil, (520 - evil.width // 2, 380 - evil.height // 2))
icons = list(ICONS.keys())
for i, rel in enumerate(icons):
    ic = Image.open(os.path.join(OUT, rel)).resize((64, 64), Image.NEAREST)
    a = -math.pi / 2 + i * (2 * math.pi / len(icons))
    img.alpha_composite(ic, (int(520 + math.cos(a) * 250 - 32), int(380 + math.sin(a) * 230 - 32)))
save(img, "cutscenes/cut_final_03.png")

# 4: face to face, red light between them
img = Image.new("RGBA", (W, H), hexc("#050507"))
glow(img, (640, 380), 260, "#ff2030", 110)
d = ImageDraw.Draw(img)
d.rectangle((636, 60, 644, 660), fill=hexc("#ff4050", 220))
me = big(*PLAYER, "#bff4ff", 18)
evil = big(*PLAYER, "#ff3348", 18).transpose(Image.FLIP_LEFT_RIGHT)
img.alpha_composite(me, (380 - me.width // 2, 380 - me.height // 2))
img.alpha_composite(evil, (900 - evil.width // 2, 380 - evil.height // 2))
save(img, "cutscenes/cut_final_04.png")

# Ending: a whole sky over a quiet city
img = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(img)
for y in range(H):
    t = y / H
    col = (int(30 + 150 * t), int(50 + 120 * t), int(90 + 110 * t), 255)
    d.line([(0, y), (W, y)], fill=col)
glow(img, (980, 470), 120, "#ffe6b0", 180)
for x in range(0, W, 48):
    c, r = random.choice([(0, 19), (1, 19), (2, 19), (0, 20), (1, 20), (2, 20), (0, 21), (2, 21)])
    sp = tint(tile(c, r), "#1a2238").resize((48, 48 * random.choice((2, 3, 4))), Image.NEAREST)
    img.alpha_composite(sp, (x, H - sp.height))
save(img, "cutscenes/cut_ending.png")

print("art done")
