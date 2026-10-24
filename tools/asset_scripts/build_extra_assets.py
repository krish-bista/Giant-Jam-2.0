"""Second asset pass: Wise Elder, grim world enemies + boss, world weapons, HUD/artifact icons,
big mirror portals, VR helmet, simulation world, improved cutscenes and two ending panels.

Usage: python build_extra_assets.py "<Ninja Adventure - Asset Pack>" "<project root>"
Run after build_ninja_assets.py.
"""
import colorsys, math, os, random, shutil, sys
from PIL import Image, ImageDraw, ImageFilter

PACK, ROOT = sys.argv[1], sys.argv[2]
NIN = os.path.join(ROOT, "assets", "ninja")
UI = os.path.join(ROOT, "assets", "ui")
random.seed(11)
T = 16
W, H = 1280, 720


def p(*parts):
    return os.path.join(PACK, *parts)


def load(*parts):
    return Image.open(p(*parts)).convert("RGBA")


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def nin(rel):
    return os.path.join(NIN, rel)


def hue_shift(img, deg, sat=1.0, val=1.0):
    img = img.copy(); px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            if s > 0.12:
                h = ((h * 360 + deg) % 360) / 360
                s = min(1.0, s * sat)
            v = min(1.0, v * val)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return img


def gradient_map(img, stops):
    img = img.copy(); px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            l = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            for i in range(len(stops) - 1):
                l0, c0 = stops[i]; l1, c1 = stops[i + 1]
                if l <= l1 or i == len(stops) - 2:
                    t = 0 if l1 == l0 else max(0.0, min(1.0, (l - l0) / (l1 - l0)))
                    px[x, y] = tuple(int(c0[k] + (c1[k] - c0[k]) * t) for k in range(3)) + (a,)
                    break
    return img


def up(img, s):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)


def outlined(img, col=(12, 10, 18, 255)):
    out = Image.new("RGBA", (img.width + 2, img.height + 2)); src = img.load(); po = out.load()
    for y in range(img.height):
        for x in range(img.width):
            if src[x, y][3] > 0:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        po[x + 1 + dx, y + 1 + dy] = col
    out.alpha_composite(img, (1, 1))
    return out


def glow(canvas, center, radius, color, alpha=120):
    g = Image.new("RGBA", canvas.size)
    ImageDraw.Draw(g).ellipse((center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius), fill=color + (alpha,))
    canvas.alpha_composite(g.filter(ImageFilter.GaussianBlur(max(1, radius // 2))))


GRIM_BONE = [(0.0, (10, 4, 16)), (0.35, (58, 42, 72)), (0.7, (150, 140, 160)), (1.0, (228, 222, 236))]
HOLO = [(0.0, (8, 50, 80)), (0.5, (60, 190, 230)), (1.0, (220, 255, 255))]

# ---------------- characters ----------------
def character(name, rel, recolor=None):
    for anim in ("Walk", "Idle", "Attack"):
        img = load("Actor", "Character", name, "SeparateAnim", anim + ".png")
        save(recolor(img) if recolor else img, nin("%s_%s.png" % (rel, anim.lower())))
    face = load("Actor", "Character", name, "Faceset.png")
    save(recolor(face) if recolor else face, nin(rel + "_face.png"))

character("OldMan3", "chars/elder")
character("Skeleton", "enemies/husk", lambda im: gradient_map(im, GRIM_BONE))
character("SkeletonDemon", "enemies/brute_demon", lambda im: gradient_map(im, [(0.0, (14, 2, 6)), (0.4, (80, 20, 40)), (0.75, (170, 120, 130)), (1.0, (240, 220, 220))]))
save(hue_shift(load("Actor", "Monster", "Skull", "SpriteSheet.png"), -95, 1.1, 0.9), nin("enemies/wraith.png"))
save(hue_shift(load("Actor", "Monster", "Eye2", "Eye2.png") if os.path.exists(p("Actor", "Monster", "Eye2", "Eye2.png")) else load("Actor", "Monster", "Eye2", "SpriteSheet.png"), -25, 1.1, 0.85), nin("enemies/seer.png"))

# Grim wyrm (replaces the blue dragon): ash-black body, bone plates
for part in ("Head", "Body1", "Body2", "BodyEnd", "Wing", "Faceset"):
    img = load("Actor", "Boss", "DragonGreen", part + ".png")
    img = gradient_map(img, [(0.0, (6, 2, 6)), (0.3, (34, 18, 26)), (0.55, (96, 70, 74)), (0.8, (196, 180, 170)), (1.0, (245, 236, 220))])
    save(img, nin("bosses/wyrm_%s.png" % part.lower()))

# ---------------- weapons ----------------
save(load("Items", "Weapons", "Bow", "Sprite.png"), nin("weapons/bow.png"))
save(gradient_map(load("Items", "Weapons", "Bow", "Arrow.png"), [(0.0, (90, 40, 0)), (0.6, (255, 200, 80)), (1.0, (255, 255, 220))]), nin("weapons/arrow.png"))
save(load("Items", "Weapons", "Axe", "Sprite.png"), nin("weapons/axe.png"))
save(hue_shift(load("Items", "Weapons", "MagicWand", "Sprite.png"), 200, 1.2), nin("weapons/wand.png"))

# ---------------- icons (HUD + artifacts) from the pack's skill icons ----------------
SK = p("Ui", "Skill Icon")
def skill(folder, name):
    return Image.open(os.path.join(SK, folder, name + ".png")).convert("RGBA")

for out_name, (folder, name) in {
    "ui_icon_sword": ("Spell", "AttackUpgrade"), "ui_icon_shield": ("Spell", "Counter"),
    "ui_icon_hypno": ("Spell", "Vision"), "ui_icon_dash": ("Items & Weapon", "Boot"),
    "ui_icon_bow": ("Items & Weapon", "Arrow"), "ui_icon_axe": ("Spell", "Cut"), "ui_icon_wand": ("Spell", "OrbDarkness"),
}.items():
    save(up(skill(folder, name), 2), os.path.join(UI, out_name + ".png"))

for art, (folder, name) in {
    "edge_shard": ("Spell", "Cut"), "heart_fragment": ("Spell", "Heal"), "quick_sigil": ("Spell", "Upgrade"),
    "lucky_coin": ("Spell", "LuckUpgrade"), "mirror_polish": ("Spell", "DefenseUpgrade"), "blood_echo": ("Spell", "Necromancy"),
    "hypno_lens": ("Spell", "OrbDarkness"), "echo_blade": ("Spell", "MagicWeapon"), "double_reflection": ("Spell", "Permutation"),
    "glass_heart": ("Spell", "Explosion"),
}.items():
    save(up(skill(folder, name), 2), os.path.join(UI, "ui_artifact_%s.png" % art))

# ---------------- big mirror portal ----------------
def mirror(path, frame_dark, frame_mid, frame_light, glass_a, glass_b, crack_col):
    w, h = 44, 66
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    # ornate frame: outer oval + crest + feet
    d.ellipse((2, 6, w - 3, h - 6), fill=frame_dark)
    d.ellipse((4, 8, w - 5, h - 8), fill=frame_mid)
    d.ellipse((5, 9, w - 6, h - 9), fill=frame_light)
    d.polygon([(w // 2, 0), (w // 2 + 6, 7), (w // 2, 10), (w // 2 - 6, 7)], fill=frame_light, outline=frame_dark)
    d.rectangle((w // 2 - 7, h - 8, w // 2 + 6, h - 1), fill=frame_dark)
    d.rectangle((w // 2 - 6, h - 7, w // 2 + 5, h - 3), fill=frame_mid)
    for side in (-1, 1):
        cx = w // 2 + side * 17
        d.ellipse((cx - 3, h // 2 - 3, cx + 3, h // 2 + 3), fill=frame_light, outline=frame_dark)
    glass = Image.new("RGBA", (w, h)); gp = glass.load()
    for y in range(h):
        for x in range(w):
            t = (x * 0.5 + y) / (w * 0.5 + h)
            gp[x, y] = tuple(int(glass_a[k] + (glass_b[k] - glass_a[k]) * t) for k in range(3)) + (255,)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((8, 12, w - 9, h - 12), fill=255)
    img.paste(glass, (0, 0), mask)
    d = ImageDraw.Draw(img)
    # reflections and a crack
    d.line([(14, 20), (19, 15)], fill=(255, 255, 255, 230), width=2)
    d.line([(13, 28), (16, 25)], fill=(255, 255, 255, 180))
    pts = [(27, 18), (24, 27), (28, 33), (23, 44)]
    d.line(pts, fill=crack_col, width=1)
    d.line([(24, 27), (18, 31)], fill=crack_col)
    save(img, path)

mirror(nin("props/mirror_portal.png"), (60, 44, 20, 255), (170, 130, 60, 255), (240, 205, 120, 255), (110, 175, 220), (235, 252, 255), (200, 235, 255, 255))
mirror(nin("props/mirror_portal_final.png"), (20, 20, 26, 255), (110, 110, 125, 255), (210, 210, 225, 255), (60, 10, 20), (190, 60, 80), (255, 200, 200, 255))

# ---------------- VR helmet (Ninja-style) ----------------
hel = Image.new("RGBA", (16, 13))
d = ImageDraw.Draw(hel)
d.ellipse((1, 0, 14, 12), fill=(58, 64, 82, 255))
d.ellipse((2, 1, 13, 10), fill=(92, 100, 124, 255))
d.rectangle((2, 5, 13, 8), fill=(20, 30, 48, 255))
d.rectangle((3, 6, 12, 7), fill=(90, 230, 255, 255))
d.point((4, 2), fill=(200, 210, 230, 255)); d.point((5, 2), fill=(200, 210, 230, 255))
d.rectangle((0, 6, 1, 8), fill=(40, 44, 58, 255)); d.rectangle((14, 6, 15, 8), fill=(40, 44, 58, 255))
save(outlined(hel), nin("props/vr_helmet.png"))

# ---------------- grave ----------------
ELE = load("Backgrounds", "Tilesets", "TilesetElement.png")
grave = ELE.crop((4 * T, 2 * T, 5 * T, 3 * T))
canvas = Image.new("RGBA", (20, 20))
d = ImageDraw.Draw(canvas)
d.ellipse((1, 12, 18, 19), fill=(70, 50, 36, 255))
d.ellipse((3, 13, 16, 18), fill=(98, 72, 50, 255))
canvas.alpha_composite(grave, (2, 1))
save(canvas, nin("props/grave_mound.png"))

# ---------------- simulation world ----------------
FLOOR = load("Backgrounds", "Tilesets", "TilesetFloor.png")
IF = load("Backgrounds", "Tilesets", "Interior", "TilesetInteriorFloor.png")
DETAIL = load("Backgrounds", "Tilesets", "TilesetFloorDetail.png")
HOUSE = load("Backgrounds", "Tilesets", "TilesetHouse.png")
NAT = load("Backgrounds", "Tilesets", "TilesetNature.png")
def cut(src, c, r, w=1, h=1):
    return src.crop((c * T, r * T, (c + w) * T, (r + h) * T))
def trim(img):
    b = img.getbbox(); return img.crop(b) if b else img

TW, TH = 40, 24
sim = Image.new("RGBA", (TW * T, TH * T))
grass = [cut(FLOOR, 0, 12), cut(FLOOR, 1, 12), cut(FLOOR, 2, 12), cut(FLOOR, 3, 12)]
stone = [cut(IF, c, r) for c in (1, 2, 5, 6) for r in (12, 13)]
for ty in range(TH):
    for tx in range(TW):
        plaza = 13 <= tx <= 26 and 8 <= ty <= 15
        path = (ty in (11, 12)) or (tx in (19, 20))
        t = random.choice(stone) if (plaza or path) else random.choices(grass, [8, 2, 2, 1])[0]
        sim.alpha_composite(t, (tx * T, ty * T))
for _ in range(160):
    sim.alpha_composite(cut(DETAIL, random.randint(0, 8), 2), (random.randint(0, TW * T - 16), random.randint(0, TH * T - 16)))
sim = gradient_map(sim, [(0.0, (10, 40, 60)), (0.35, (40, 120, 150)), (0.65, (110, 200, 220)), (1.0, (230, 255, 255))])
d = ImageDraw.Draw(sim)
for x in range(0, sim.width, T):
    if (x // T) % 4 == 0:
        d.line([(x, 0), (x, sim.height)], fill=(170, 250, 255, 60))
for y in range(0, sim.height, T):
    if (y // T) % 4 == 0:
        d.line([(0, y), (sim.width, y)], fill=(170, 250, 255, 60))
# Unrendered edges: the simulation dissolves into the void
px = sim.load()
for ty in range(TH):
    for tx in range(TW):
        edge = min(tx, ty, TW - 1 - tx, TH - 1 - ty)
        if edge < 2 and random.random() < (0.85 - edge * 0.4):
            for y in range(ty * T, ty * T + T):
                for x in range(tx * T, tx * T + T):
                    px[x, y] = (4, 10, 20, 255)
            if random.random() < 0.3:
                d.rectangle((tx * T + 2, ty * T + 2, tx * T + 13, ty * T + 13), outline=(60, 200, 240, 120))
# glitch strips
for _ in range(6):
    y = random.randint(40, sim.height - 40); x = random.randint(40, sim.width - 200)
    d.rectangle((x, y, x + random.randint(40, 160), y + random.randint(1, 3)), fill=(255, 80, 200, 110))
save(sim, nin("ground/sim.png"))

for key, (src, c, r, w, h) in {
    "house_a": (HOUSE, 0, 0, 3, 3), "house_b": (HOUSE, 4, 0, 3, 3), "house_c": (HOUSE, 12, 0, 3, 3),
    "torii": (HOUSE, 0, 5, 2, 2), "dojo_sign": (HOUSE, 4, 4, 2, 1), "statue": (HOUSE, 3, 15, 2, 2),
    "tree": (NAT, 16, 0, 2, 2), "tree_big": (NAT, 3, 18, 3, 3), "scarecrow": (ELE, 15, 0, 1, 1), "fence": (HOUSE, 9, 4, 3, 1),
}.items():
    img = trim(cut(src, c, r, w, h))
    save(img, nin("props/%s.png" % key))
    save(gradient_map(img, HOLO), nin("props/holo_%s.png" % key))

# City houses (intact) for a readable town
for key, (c, r) in {"town_house_a": (0, 0), "town_house_b": (4, 0), "town_house_c": (8, 0), "town_shop": (16, 0), "town_red": (12, 0)}.items():
    save(trim(cut(HOUSE, c, r, 3, 3)), nin("props/%s.png" % key))
save(trim(cut(HOUSE, 9, 4, 3, 1)), nin("props/barricade.png"))
# Crashed alien pod: a crystal tower recolored alien green
TOW = load("Backgrounds", "Tilesets", "TilesetTowers.png")
save(hue_shift(trim(cut(TOW, 18, 4, 2, 2)), 60, 1.4, 1.1), nin("props/alien_pod.png"))

# Grim versions of scenery
for key in ("tree_dead", "pillar", "pillar_broken", "rocks_grey", "boulder_grey", "statue_orb", "head_statue", "ruin_wall", "grave", "crystal_purple", "gem_rock"):
    img = Image.open(nin("props/%s.png" % key)).convert("RGBA")
    save(gradient_map(img, [(0.0, (8, 4, 12)), (0.45, (50, 38, 62)), (0.8, (120, 108, 130)), (1.0, (190, 180, 196))]), nin("props/grim_%s.png" % key))

# Grim ground: ashen tiles with cracks and dried blood veins
orn = IF.crop((15 * T, 6 * T, 19 * T, 10 * T))
orn = gradient_map(orn, [(0.0, (26, 20, 32)), (0.5, (80, 66, 90)), (1.0, (150, 136, 162))])
g = Image.new("RGBA", (54 * T, 30 * T))
for y in range(0, g.height, orn.height):
    for x in range(0, g.width, orn.width):
        g.alpha_composite(orn, (x, y))
d = ImageDraw.Draw(g)
for _ in range(120):
    x, y = random.randint(0, g.width), random.randint(0, g.height)
    pts = [(x, y)]
    for _ in range(random.randint(2, 5)):
        x += random.randint(-14, 14); y += random.randint(-14, 14); pts.append((x, y))
    d.line(pts, fill=(14, 6, 12, 230))
for _ in range(26):
    x, y = random.randint(0, g.width), random.randint(0, g.height)
    pts = [(x, y)]
    for _ in range(random.randint(3, 7)):
        x += random.randint(-18, 18); y += random.randint(-18, 18); pts.append((x, y))
    d.line(pts, fill=(120, 16, 30, 200))
bones = [DETAIL.crop((i * T, 0, i * T + T, T)) for i in (11, 12, 13)]
for _ in range(40):
    b = gradient_map(random.choice(bones), [(0.0, (30, 20, 30)), (1.0, (170, 160, 170))])
    g.alpha_composite(b, (random.randint(0, g.width - 16), random.randint(0, g.height - 16)))
save(g, nin("ground/grim.png"))

# ---------------- cutscene panels (portraits instead of blown-up sprites) ----------------
def frame_mirror(canvas, box, cracked=True):
    d = ImageDraw.Draw(canvas)
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=(14, 16, 26, 255))
    for i, col in enumerate(((240, 240, 250), (170, 170, 190), (80, 80, 96))):
        d.rectangle((x0 - 10 + i * 4, y0 - 10 + i * 4, x1 + 10 - i * 4, y1 + 10 - i * 4), outline=col + (255,), width=4)
    if cracked:
        cx, cy = (x0 + x1) // 2 + 60, y0 + 120
        for _ in range(9):
            a = random.uniform(0, math.tau); px_, py_ = cx, cy
            for _ in range(4):
                a += random.uniform(-0.5, 0.5)
                nx, ny = min(max(px_ + math.cos(a) * 70, x0), x1), min(max(py_ + math.sin(a) * 70, y0), y1)
                d.line([(px_, py_), (nx, ny)], fill=(225, 230, 245, 210), width=2); px_, py_ = nx, ny

def cut_bg(img, tol=26):
    img = img.copy(); px = img.load(); w, h = img.size
    bg = px[0, 0]
    seen = set(); stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        c = px[x, y]
        if c[3] == 0 or sum(abs(c[k] - bg[k]) for k in range(3)) <= tol:
            px[x, y] = (0, 0, 0, 0)
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return img

me_face = cut_bg(Image.open(nin("chars/player_face.png")).convert("RGBA"))
evil_face = cut_bg(Image.open(nin("chars/evil_face.png")).convert("RGBA"))
me_idle = Image.open(nin("chars/player_idle.png")).convert("RGBA")
evil_idle = Image.open(nin("chars/evil_idle.png")).convert("RGBA")

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); glow(c, (640, 300), 320, (150, 160, 190), 50)
frame_mirror(c, (430, 60, 850, 540))
ghost = gradient_map(me_face, [(0, (16, 18, 28)), (1, (160, 170, 200))])
f = up(ghost, 9); c.alpha_composite(f, (640 - f.width // 2, 300 - f.height // 2))
back = up(me_idle.crop((16, 0, 32, 16)), 10); c.alpha_composite(back, (640 - back.width // 2, 560))
save(c, nin("cutscenes/final_01.png"))

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); frame_mirror(c, (300, 30, 980, 690))
f = up(evil_face, 15); c.alpha_composite(f, (640 - f.width // 2, 360 - f.height // 2))
glow(c, (640, 360), 260, (255, 30, 40), 60)
save(c, nin("cutscenes/final_02.png"))

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); frame_mirror(c, (620, 70, 1020, 600)); glow(c, (500, 380), 240, (255, 30, 40), 90)
e = up(evil_idle.crop((0, 0, 16, 16)), 20); c.alpha_composite(e, (500 - e.width // 2, 380 - e.height // 2))
icons = sorted(f for f in os.listdir(UI) if f.startswith("ui_artifact_") and f.endswith(".png"))
for i, ic in enumerate(icons):
    im = up(Image.open(os.path.join(UI, ic)).convert("RGBA"), 1)
    a = -math.pi / 2 + i * math.tau / max(len(icons), 1)
    c.alpha_composite(im, (int(500 + math.cos(a) * 260 - 24), int(380 + math.sin(a) * 240 - 24)))
save(c, nin("cutscenes/final_03.png"))

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); glow(c, (640, 360), 300, (255, 30, 40), 100)
ImageDraw.Draw(c).rectangle((636, 40, 644, 680), fill=(255, 60, 70, 230))
a1 = up(me_face, 8); a2 = up(evil_face.transpose(Image.FLIP_LEFT_RIGHT), 8)
c.alpha_composite(a1, (330 - a1.width // 2, 360 - a1.height // 2)); c.alpha_composite(a2, (950 - a2.width // 2, 360 - a2.height // 2))
save(c, nin("cutscenes/final_04.png"))

# ---------------- ending panels ----------------
def sky(colors):
    img = Image.new("RGBA", (W, H)); d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        seg = min(int(t * (len(colors) - 1)), len(colors) - 2)
        lt = t * (len(colors) - 1) - seg
        c0, c1 = colors[seg], colors[seg + 1]
        d.line([(0, y), (W, y)], fill=tuple(int(c0[k] + (c1[k] - c0[k]) * lt) for k in range(3)) + (255,))
    return img

trees = [Image.open(nin("props/%s.png" % n)).convert("RGBA") for n in ("tree_green", "tree_pine", "tree_big", "tree_bush", "tree_roots")]
houses = [Image.open(nin("props/%s.png" % n)).convert("RGBA") for n in ("town_house_a", "town_house_b", "town_house_c", "town_shop", "town_red")]

# Divine: dawn, sun rays, mirror shards rising as light, the hero's face in the sky
c = sky([(40, 60, 120), (190, 120, 150), (255, 190, 130), (255, 230, 170)])
sun = (640, 470)
rays = Image.new("RGBA", (W, H)); dr = ImageDraw.Draw(rays)
for i in range(18):
    a = i * math.tau / 18
    dr.polygon([sun, (sun[0] + math.cos(a - 0.05) * 1200, sun[1] + math.sin(a - 0.05) * 1200), (sun[0] + math.cos(a + 0.05) * 1200, sun[1] + math.sin(a + 0.05) * 1200)], fill=(255, 245, 210, 40))
c.alpha_composite(rays.filter(ImageFilter.GaussianBlur(6)))
glow(c, sun, 170, (255, 245, 210), 230)
ghost = gradient_map(me_face, [(0, (255, 210, 150)), (1, (255, 255, 240))]); ghost = up(ghost, 6); ghost.putalpha(ghost.getchannel("A").point(lambda v: v * 70 // 255))
c.alpha_composite(ghost, (640 - ghost.width // 2, 70))
for _ in range(40):
    x, y = random.randint(0, W), random.randint(80, 520); s = random.randint(3, 8)
    shard = Image.new("RGBA", (s * 4, s * 4)); ImageDraw.Draw(shard).polygon([(s * 2, 0), (s * 3, s * 2), (s * 2, s * 4), (s, s * 2)], fill=(255, 255, 235, 200))
    c.alpha_composite(shard.filter(ImageFilter.GaussianBlur(1)), (x, y))
x = -40
while x < W:
    tr = random.choice(trees + houses[:2])
    sil = up(gradient_map(tr, [(0.0, (60, 40, 50)), (1.0, (120, 80, 80))]), random.choice((4, 5, 6)))
    c.alpha_composite(sil, (x, H - sil.height + random.randint(0, 30)))
    x += sil.width // 2 + random.randint(0, 30)
save(c, nin("cutscenes/ending_divine.png"))

# Evil: blood sky, burning town, the reflection looming with glowing eyes, cracked glass
c = sky([(6, 0, 4), (60, 4, 12), (150, 20, 20), (60, 6, 10)])
looming = up(evil_face, 10); looming.putalpha(looming.getchannel("A").point(lambda v: v * 200 // 255))
c.alpha_composite(looming, (640 - looming.width // 2, 20))
for ex in (585, 695):
    glow(c, (ex, 165), 40, (255, 40, 40), 230)
x = -20
while x < W:
    hs = random.choice(houses + trees[:2])
    sil = up(gradient_map(hs, [(0.0, (6, 0, 2)), (1.0, (30, 4, 8))]), random.choice((4, 5)))
    c.alpha_composite(sil, (x, H - sil.height + random.randint(0, 20)))
    glow(c, (x + sil.width // 2, H - sil.height + 10), 28, (255, 120, 40), 90)
    x += sil.width - 10
d = ImageDraw.Draw(c)
for _ in range(6):
    a = random.uniform(0, math.tau); px_, py_ = 640, 300
    for _ in range(6):
        a += random.uniform(-0.4, 0.4)
        nx, ny = px_ + math.cos(a) * 90, py_ + math.sin(a) * 90
        d.line([(px_, py_), (nx, ny)], fill=(255, 220, 220, 150), width=2); px_, py_ = nx, ny
save(c, nin("cutscenes/ending_evil.png"))
print("extra assets built")
