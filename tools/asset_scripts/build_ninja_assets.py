"""Builds Echo Breach's art from the CC0 "Ninja Adventure" pack by Pixel-boy.

Usage: python build_ninja_assets.py "<Ninja Adventure - Asset Pack folder>" "<project>/assets/ninja"

Everything is kept at native pixel size (16 px tiles); the game scales sprites x3.
"""
import colorsys, json, math, os, random, shutil, sys
from PIL import Image, ImageDraw, ImageFilter

PACK = sys.argv[1]
OUT = sys.argv[2]
random.seed(7)
T = 16


def p(*parts):
    return os.path.join(PACK, *parts)


def out(rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def load(*parts):
    return Image.open(p(*parts)).convert("RGBA")


def save(img, rel):
    img.save(out(rel))


def copy(rel_out, *parts):
    shutil.copyfile(p(*parts), out(rel_out))


# ---------------- recolor helpers ----------------
def hue_shift(img, deg, sat=1.0, val=1.0, only=None):
    """Rotate hue. `only` = (h_min, h_max) in degrees limits the shift to those hues."""
    img = img.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            hd = h * 360
            if only and not (only[0] <= hd <= only[1]) and s > 0.12:
                continue
            if s > 0.12:
                h = ((hd + deg) % 360) / 360
                s = min(1.0, s * sat)
            v = min(1.0, v * val)
            r2, g2, b2 = colorsys.hsv_to_rgb(h, s, v)
            px[x, y] = (int(r2 * 255), int(g2 * 255), int(b2 * 255), a)
    return img


def gradient_map(img, stops):
    """Map luminance to a color ramp. stops = [(lum, (r,g,b)), ...] sorted by lum."""
    img = img.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            l = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            for i in range(len(stops) - 1):
                l0, c0 = stops[i]
                l1, c1 = stops[i + 1]
                if l <= l1 or i == len(stops) - 2:
                    t = 0 if l1 == l0 else max(0.0, min(1.0, (l - l0) / (l1 - l0)))
                    px[x, y] = tuple(int(c0[k] + (c1[k] - c0[k]) * t) for k in range(3)) + (a,)
                    break
    return img


def cut(img, c, r, w=1, h=1):
    return img.crop((c * T, r * T, (c + w) * T, (r + h) * T))


def trim(img):
    box = img.getbbox()
    return img.crop(box) if box else img


# ---------------- characters ----------------
def character(name, rel, recolor=None):
    for anim in ("Walk", "Idle", "Attack", "Dead", "Jump"):
        src = p("Actor", "Character", name, "SeparateAnim", anim + ".png")
        if os.path.exists(src):
            img = Image.open(src).convert("RGBA")
            if recolor:
                img = recolor(img)
            save(img, "%s_%s.png" % (rel, anim.lower()))
    face = p("Actor", "Character", name, "Faceset.png")
    if os.path.exists(face):
        img = Image.open(face).convert("RGBA")
        if recolor:
            img = recolor(img)
        save(img, rel + "_face.png")


EVIL = lambda im: gradient_map(im, [(0.0, (8, 4, 8)), (0.25, (40, 6, 14)), (0.5, (150, 14, 30)), (0.75, (235, 40, 60)), (1.0, (255, 200, 200))])
HOLO = lambda im: gradient_map(im, [(0.0, (10, 60, 90)), (0.5, (60, 200, 235)), (1.0, (220, 255, 255))])
PURPLE = lambda im: hue_shift(im, 0, 1.0, 1.0) if False else gradient_map(im, [(0.0, (14, 6, 28)), (0.35, (70, 26, 120)), (0.65, (170, 70, 230)), (1.0, (255, 210, 255))])

character("Knight", "chars/player", lambda im: hue_shift(im, 95, 1.9, 1.18))
character("Knight", "chars/evil", EVIL)
character("Knight", "chars/holo", HOLO)
character("Master", "chars/npc")
character("RobotGrey", "enemies/robot", PURPLE)

# Monsters: 4x4 sheets (cols = down, up, left, right; rows = frames)
MON = {
    "eye": ("Eye", "Eye.png", None),
    "octopus": ("Octopus", "SpriteSheet.png", None),
    "cyclope": ("Cyclope", "SpriteSheet.png", lambda im: hue_shift(im, 200, 1.1)),
    "trex": ("Trex", "SpriteSheet.png", None),
    "trex_red": ("Trex", "SpriteSheet.png", lambda im: hue_shift(im, -35, 1.4, 0.85)),
    "bear": ("Bear", "SpriteSheet.png", None),
    "butterfly": ("Butterfly", "SpriteSheet.png", None),
    "skull": ("Skull", "SpriteSheet.png", PURPLE),
}
for key, (folder, file, rc) in MON.items():
    src = p("Actor", "Monster", folder, file)
    if not os.path.exists(src):
        src = p("Actor", "Monster", folder, "SpriteSheet.png")
    img = Image.open(src).convert("RGBA")
    if rc:
        img = rc(img)
    save(img, "enemies/%s.png" % key)

# Bosses
def boss(folder, rel, rc=None, files=("Idle", "Walk", "Attack", "Shoot", "Hit", "Charge", "Jump")):
    for f in files:
        src = p("Actor", "Boss", folder, f + ".png")
        if os.path.exists(src):
            img = Image.open(src).convert("RGBA")
            if rc:
                img = rc(img)
            save(img, "bosses/%s_%s.png" % (rel, f.lower()))
    face = p("Actor", "Boss", folder, "Faceset.png")
    if os.path.exists(face):
        img = Image.open(face).convert("RGBA")
        save(rc(img) if rc else img, "bosses/%s_face.png" % rel)


boss("SquidRed", "squid", lambda im: hue_shift(im, -55, 1.15, 1.05))           # magenta hypnotist
boss("DemonCyclop", "cyclops", lambda im: hue_shift(im, 190, 1.05, 1.0))       # alien-blue warden
boss("GiantRacoon", "beast")                                                    # jungle alpha
for part in ("Head", "Body1", "Body2", "BodyEnd", "Wing", "Faceset"):
    img = load("Actor", "Boss", "DragonGreen", part + ".png")
    img = hue_shift(img, 175, 1.25, 1.05)                                       # neon purple sentinel
    save(img, "bosses/dragon_%s.png" % part.lower())

# ---------------- FX / projectiles / particles ----------------
FX = {
    "slash_arc": ("FX", "Slash", "SpriteSheetArc.png"),
    "slash_01": ("FX", "Slash", "SpriteSheetSlash01.png"),
    "slash_circular": ("FX", "Slash", "SpriteSheetCircular.png"),
    "circular_slash": ("FX", "Attack", "CircularSlash", "SpriteSheet.png"),
    "slash_curved": ("FX", "Attack", "SlashCurved", "SpriteSheet.png"),
    "cut_x": ("FX", "Attack", "CutX", "SpriteSheet.png"),
    "explosion": ("FX", "Elemental", "Explosion", "SpriteSheet.png"),
    "shield_blue": ("FX", "Magic", "Shield", "SpriteSheetBlue.png"),
    "shield_yellow": ("FX", "Magic", "Shield", "SpriteSheetYellow.png"),
    "spark": ("FX", "Magic", "Spark", "SpriteSheet.png"),
    "circle_white": ("FX", "Magic", "Circle", "SpriteSheetWhite.png"),
    "circle_spark": ("FX", "Magic", "Circle", "SpriteSheetSpark.png"),
    "aura": ("FX", "Magic", "Aura", "SpriteSheet.png"),
    "smoke": ("FX", "Smoke", "Smoke", "SpriteSheet.png"),
    "smoke_circular": ("FX", "Smoke", "SmokeCircular", "SpriteSheet.png"),
    "thunder": ("FX", "Elemental", "Thunder", "SpriteSheet.png"),
    "energy_ball": ("FX", "Projectile", "EnergyBall.png"),
    "big_energy_ball": ("FX", "Projectile", "BigEnergyBall.png"),
    "fireball": ("FX", "Projectile", "Fireball.png"),
}
for key, parts in FX.items():
    copy("fx/%s.png" % key, *parts)
for part in ("Spark", "Wood", "Vase", "Rock", "RockGray", "Leaf", "Rain", "Grass", "Clouds"):
    copy("fx/particle_%s.png" % part.lower(), "FX", "Particle", part + ".png")
copy("fx/shadow.png", "Actor", "Character", "Shadow.png")
# Magenta energy ball for hypno and purple for the core
save(hue_shift(load("FX", "Projectile", "EnergyBall.png"), 120, 1.2), "fx/energy_ball_pink.png")
save(hue_shift(load("FX", "Projectile", "BigEnergyBall.png"), 90, 1.2), "fx/big_energy_ball_purple.png")

# ---------------- weapons ----------------
sword = load("Items", "Weapons", "Sword", "Sprite.png")
sword = gradient_map(sword, [(0.0, (20, 30, 60)), (0.4, (90, 150, 210)), (0.8, (200, 245, 255)), (1.0, (255, 255, 255))])
save(sword, "weapons/divine_sword.png")
evil_sword = gradient_map(load("Items", "Weapons", "Sword", "Sprite.png"), [(0.0, (10, 0, 4)), (0.5, (160, 10, 30)), (1.0, (255, 160, 160))])
save(evil_sword, "weapons/evil_sword.png")

def mirror_shield(frame_dark, frame_light, glass_a, glass_b, rel):
    W, H = 12, 15
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    d.ellipse((0, 0, W - 1, H - 1), fill=frame_dark)
    d.ellipse((1, 1, W - 2, H - 2), fill=frame_light)
    # glass gradient
    glass = Image.new("RGBA", (W, H))
    gp = glass.load()
    for y in range(H):
        for x in range(W):
            t = (x * 0.6 + y) / (W * 0.6 + H)
            gp[x, y] = tuple(int(glass_a[k] + (glass_b[k] - glass_a[k]) * t) for k in range(3)) + (255,)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse((2, 2, W - 3, H - 3), fill=255)
    img.paste(glass, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.line([(4, 4), (6, 3)], fill=(255, 255, 255, 255))
    d.line([(3, 6), (4, 5)], fill=(255, 255, 255, 230))
    d.point((7, 10), fill=(255, 255, 255, 180))
    d.point((W // 2, 0), fill=(255, 240, 150, 255))
    d.point((W // 2, H - 1), fill=(255, 240, 150, 255))
    save(img, rel)

mirror_shield((70, 50, 20, 255), (230, 190, 90, 255), (120, 170, 210), (235, 250, 255), "weapons/mirror_shield.png")
mirror_shield((20, 0, 4, 255), (120, 20, 30, 255), (40, 0, 10), (200, 40, 60), "weapons/evil_shield.png")

# ---------------- props ----------------
NAT = load("Backgrounds", "Tilesets", "TilesetNature.png")
ELE = load("Backgrounds", "Tilesets", "TilesetElement.png")
CAMP = load("Backgrounds", "Tilesets", "tileset_camp.png")
HOUSE = load("Backgrounds", "Tilesets", "TilesetHouse.png")
VIL = load("Backgrounds", "Tilesets", "TilesetVillageAbandoned.png")
TOW = load("Backgrounds", "Tilesets", "TilesetTowers.png")
FLOOR = load("Backgrounds", "Tilesets", "TilesetFloor.png")
DETAIL = load("Backgrounds", "Tilesets", "TilesetFloorDetail.png")
IFLOOR = load("Backgrounds", "Tilesets", "Interior", "TilesetInteriorFloor.png")
BED = load("Backgrounds", "Tilesets", "tileset_bed.png")

PROPS = {
    # jungle
    "tree_green": (NAT, 16, 0, 2, 2), "tree_roots": (NAT, 6, 0, 2, 2), "tree_bush": (NAT, 0, 0, 2, 2),
    "tree_pine": (NAT, 2, 0, 2, 2), "tree_big": (NAT, 3, 18, 3, 3), "tree_cluster": (NAT, 16, 2, 4, 3),
    "tree_cluster_olive": (NAT, 20, 2, 4, 3), "pine_cluster": (NAT, 0, 2, 4, 3), "tree_dead": (NAT, 4, 0, 2, 2),
    "tree_thin": (NAT, 13, 16, 1, 3), "bamboo": (NAT, 11, 8, 1, 3), "stump": (NAT, 2, 8, 2, 2),
    "bush_a": (NAT, 0, 10, 1, 1), "bush_b": (NAT, 1, 10, 1, 1), "bush_c": (NAT, 2, 10, 1, 1), "bush_d": (NAT, 9, 10, 1, 1),
    "fern": (NAT, 4, 11, 1, 1), "flower_sun": (NAT, 0, 11, 1, 1), "flower_red": (NAT, 3, 11, 1, 1),
    "rock_brown": (NAT, 13, 8, 2, 2), "rock_grey": (NAT, 17, 8, 2, 2), "rock_brown_small": (NAT, 15, 9, 1, 1),
    "rock_grey_small": (NAT, 19, 9, 1, 1), "rocks_brown": (NAT, 12, 5, 4, 3), "rocks_grey": (NAT, 16, 5, 4, 3),
    "boulder_brown": (NAT, 17, 10, 4, 3), "boulder_grey": (NAT, 17, 14, 4, 3), "log": (NAT, 12, 14, 1, 2),
    "frog_statue": (VIL, 9, 6, 2, 2),
    # crystals (core)
    "crystal_purple": (NAT, 2, 14, 1, 1), "crystal_blue": (NAT, 1, 14, 1, 1),
    "gem_block_purple": (NAT, 2, 16, 1, 1), "gem_block_blue": (NAT, 1, 16, 1, 1), "gem_rock": (NAT, 7, 16, 2, 2),
    # destructibles
    "barrel": (HOUSE, 16, 15, 1, 1), "crate": (CAMP, 9, 8, 1, 1), "crate_b": (ELE, 0, 0, 1, 1),
    "pot": (ELE, 2, 9, 1, 1), "vase": (CAMP, 6, 7, 1, 1), "sack": (ELE, 3, 0, 1, 1),
    # city ruins
    "ruin_a": (VIL, 0, 0, 4, 3), "ruin_b": (VIL, 11, 0, 3, 3), "ruin_c": (VIL, 17, 0, 3, 3), "ruin_d": (VIL, 4, 0, 2, 3),
    "ruin_house_big": (VIL, 12, 6, 4, 5), "ruin_rubble": (VIL, 6, 1, 3, 2), "ruin_wall": (VIL, 9, 1, 3, 2),
    "moss_trees": (VIL, 0, 6, 4, 3), "moss_tree": (VIL, 4, 6, 2, 2), "pillar": (VIL, 2, 3, 1, 3), "pillar_broken": (VIL, 3, 4, 1, 2),
    "shrine_ruin": (VIL, 0, 3, 2, 3), "statue_lion": (HOUSE, 1, 20, 2, 2), "statue_orb": (HOUSE, 3, 15, 2, 2),
    "lamp_post": (CAMP, 6, 5, 1, 2), "banner_post": (CAMP, 7, 5, 1, 2), "tent": (CAMP, 4, 0, 3, 3), "tent_torn": (CAMP, 10, 0, 3, 3),
    "firepit": (CAMP, 10, 3, 2, 2), "sign": (ELE, 0, 2, 1, 1), "grave": (ELE, 4, 2, 1, 1),
    "arch": (HOUSE, 29, 20, 3, 3), "head_statue": (HOUSE, 29, 14, 2, 2),
    # room furniture
    "table": (ELE, 11, 1, 4, 1), "drawer": (ELE, 1, 7, 1, 2), "bookshelf": (ELE, 8, 7, 2, 2), "shelf": (ELE, 10, 7, 2, 2),
    "dresser": (ELE, 6, 7, 2, 2), "plant": (ELE, 0, 7, 1, 2), "stool": (ELE, 5, 7, 1, 1), "mat": (ELE, 13, 4, 3, 3),
    "candle": (CAMP, 13, 7, 1, 1), "door": (ELE, 1, 5, 1, 2),
}
props_meta = {}
for key, (src, c, r, w, h) in PROPS.items():
    img = trim(cut(src, c, r, w, h))
    save(img, "props/%s.png" % key)
    props_meta[key] = [img.width, img.height]

# Crystal towers recolored to neon purple
for i, c in enumerate((18, 20, 22)):
    img = trim(cut(TOW, c, 4, 2, 2))
    img = hue_shift(img, 200, 1.3, 1.05, only=(40, 140))
    save(img, "props/crystal_tower_%d.png" % i)
    props_meta["crystal_tower_%d" % i] = [img.width, img.height]
for key in ("gem_rock", "arch", "pillar", "pillar_broken", "head_statue", "statue_orb"):
    img = Image.open(out("props/%s.png" % key))
    save(hue_shift(img, 210, 1.4, 0.85), "props/%s_core.png" % key)
    props_meta[key + "_core"] = list(img.size)
    save(gradient_map(img, [(0.0, (6, 6, 10)), (0.5, (70, 70, 85)), (1.0, (220, 220, 235))]), "props/%s_silver.png" % key)
    props_meta[key + "_silver"] = list(img.size)

# Explosive barrel: barrel recolored red with a pale hazard band
eb = gradient_map(Image.open(out("props/barrel.png")), [(0.0, (40, 6, 6)), (0.5, (190, 30, 30)), (1.0, (255, 170, 120))])
d = ImageDraw.Draw(eb)
cy = eb.height // 2
d.line([(2, cy), (eb.width - 3, cy)], fill=(255, 220, 80, 255))
d.point((eb.width // 2, cy - 2), fill=(255, 255, 255, 255))
save(eb, "props/barrel_explosive.png")
props_meta["barrel_explosive"] = list(eb.size)
# Hologram crate for the tutorial
save(HOLO(Image.open(out("props/crate.png"))), "props/crate_holo.png")
props_meta["crate_holo"] = props_meta["crate"]
save(HOLO(Image.open(out("props/barrel.png"))), "props/barrel_holo.png")
props_meta["barrel_holo"] = props_meta["barrel"]

# Treasure chest (closed / open)
chest = load("Items", "Treasure", "BigTreasureChest.png")
save(chest.crop((0, 0, 16, 14)), "props/chest_closed.png")
save(chest.crop((16, 0, 32, 14)), "props/chest_open.png")
props_meta["chest_closed"] = [16, 14]
props_meta["chest_open"] = [16, 14]

# Bed from the bed tileset (first bed, 2x3)
bed = trim(cut(BED, 0, 0, 2, 3))
save(bed, "props/bed.png")
props_meta["bed"] = list(bed.size)

# Animated scenery
copy("props/flower_anim.png", "Backgrounds", "Animated", "Flower", "SpriteSheet16x16.png")
copy("props/plant_anim.png", "Backgrounds", "Animated", "Plant", "SpriteSheet16x16.png")
copy("props/ripples_purple.png", "Backgrounds", "Animated", "Water Ripples", "SpriteSheetPurple.png")
for color in ("Black", "Red", "Gray"):
    copy("props/flag_%s.png" % color.lower(), "Backgrounds", "Animated", "Flag", "Flag%s16x16.png" % color)

with open(out("props/props.json"), "w") as f:
    json.dump(props_meta, f, indent=1)

# ---------------- ground ----------------
def tile_of(src, c, r):
    return cut(src, c, r)

def blob(src, c0, r0):
    """3x3 autotile pieces: returns dict of corner/edge/center tiles."""
    names = [["tl", "t", "tr"], ["l", "c", "r"], ["bl", "b", "br"]]
    return {names[j][i]: tile_of(src, c0 + i, r0 + j) for j in range(3) for i in range(3)}

def bake(tw, th, base_tiles, patches=(), decals=(), lines=()):
    img = Image.new("RGBA", (tw * T, th * T))
    for ty in range(th):
        for tx in range(tw):
            t = random.choices([b[0] for b in base_tiles], [b[1] for b in base_tiles])[0]
            img.alpha_composite(t, (tx * T, ty * T))
    occupied = set()
    for (pieces, count, wmin, wmax, hmin, hmax) in patches:
        for _ in range(count):
            for _try in range(30):
                w, h = random.randint(wmin, wmax), random.randint(hmin, hmax)
                x0, y0 = random.randint(1, tw - w - 1), random.randint(1, th - h - 1)
                cells = {(x, y) for x in range(x0 - 1, x0 + w + 1) for y in range(y0 - 1, y0 + h + 1)}
                if cells & occupied:
                    continue
                occupied |= cells
                for y in range(h):
                    for x in range(w):
                        k = ("t" if y == 0 else "b" if y == h - 1 else "") + ("l" if x == 0 else "r" if x == w - 1 else "")
                        k = {"": "c", "t": "t", "b": "b", "l": "l", "r": "r"}.get(k, k)
                        img.alpha_composite(pieces[k], ((x0 + x) * T, (y0 + y) * T))
                break
    for (tiles, count) in decals:
        for _ in range(count):
            t = random.choice(tiles)
            img.alpha_composite(t, (random.randint(0, tw * T - 16), random.randint(0, th * T - 16)))
    for fn in lines:
        fn(img)
    return img

grass = [(tile_of(FLOOR, 11, 12), 10), (tile_of(FLOOR, 12, 12), 2), (tile_of(FLOOR, 13, 12), 2), (tile_of(FLOOR, 14, 12), 1), (tile_of(FLOOR, 15, 12), 1)]
dirt_blob = blob(FLOOR, 11, 7)
tufts = [tile_of(DETAIL, i, 2) for i in range(0, 9)]
debris = [tile_of(DETAIL, i, 0) for i in range(0, 15)]

# Jungle 54x30
save(bake(54, 30, grass, patches=[(dirt_blob, 10, 2, 5, 2, 3)], decals=[(tufts, 260), (debris[:6], 40)]), "ground/jungle.png")

# City 54x30: dark cobblestone with dirt patches and debris
cobble = [(tile_of(IFLOOR, c, r), 1) for c in (12, 13, 14, 16, 17, 18) for r in (12, 13, 14)]
brown_blob = blob(FLOOR, 11, 14)
def road(img):
    d = ImageDraw.Draw(img)
    for y in (img.height // 2 - 1,):
        for x in range(0, img.width, 22):
            d.rectangle((x, y, x + 10, y + 1), fill=(190, 180, 150, 120))
save(bake(54, 30, cobble, decals=[(tufts, 70), (debris[:4], 18)], lines=[road]), "ground/city.png")

# Core 54x30: ornate tiles recolored neon purple, with the mirror line
orn = hue_shift(IFLOOR.crop((15 * T, 6 * T, 19 * T, 10 * T)), 160, 1.4, 1.15)
def core_line(img):
    d = ImageDraw.Draw(img)
    cx = img.width // 2
    d.rectangle((cx - 2, 0, cx + 1, img.height), fill=(255, 90, 240, 255))
    d.rectangle((cx - 4, 0, cx + 3, img.height), outline=(140, 40, 200, 160))
core = Image.new("RGBA", (54 * T, 30 * T))
for y in range(0, 30 * T, orn.height):
    for x in range(0, 54 * T, orn.width):
        core.alpha_composite(orn, (x, y))
dd = ImageDraw.Draw(core)
for _ in range(70):
    x, y = random.randint(0, core.width), random.randint(0, core.height)
    dd.line([(x, y), (x + random.randint(-12, 12), y + random.randint(-12, 12))], fill=(20, 8, 30, 200))
core_line(core)
save(core, "ground/core.png")

# Final mirror room 34x19: black ornate tiles with silver lines and a red seam
fin_tile = gradient_map(IFLOOR.crop((15 * T, 6 * T, 19 * T, 10 * T)), [(0.0, (34, 34, 44)), (0.5, (118, 118, 134)), (1.0, (210, 210, 228))])
fin = Image.new("RGBA", (34 * T, 19 * T))
for y in range(0, fin.height, fin_tile.height):
    for x in range(0, fin.width, fin_tile.width):
        fin.alpha_composite(fin_tile, (x, y))
ImageDraw.Draw(fin).rectangle((fin.width // 2 - 1, 0, fin.width // 2, fin.height), fill=(200, 20, 40, 200))
save(fin, "ground/final.png")

# Amnesia room 27x15: warm ornate floor, brick walls
room_tile = IFLOOR.crop((15 * T, 0, 19 * T, 4 * T))
room = Image.new("RGBA", (27 * T, 15 * T))
for y in range(0, room.height, room_tile.height):
    for x in range(0, room.width, room_tile.width):
        room.alpha_composite(room_tile, (x, y))
brick = IFLOOR.crop((0, 6 * T, 4 * T, 10 * T))
brick = hue_shift(brick, 0, 0.6, 0.55)
for x in range(0, room.width, brick.width):
    room.alpha_composite(brick.crop((0, 0, brick.width, 3 * T)), (x, 0))
for y in range(3 * T, room.height, T):
    room.alpha_composite(brick.crop((0, 0, T, T)), (0, y))
    room.alpha_composite(brick.crop((0, 0, T, T)), (room.width - T, y))
    room.alpha_composite(brick.crop((0, 0, T, T)), (0, room.height - T) if y == 3 * T else (0, y))
for x in range(0, room.width, T):
    room.alpha_composite(brick.crop((0, 0, T, T)), (x, room.height - T))
shade = Image.new("RGBA", room.size, (0, 0, 0, 0))
ImageDraw.Draw(shade).rectangle((0, 3 * T, room.width, 3 * T + 5), fill=(0, 0, 0, 90))
room.alpha_composite(shade)
save(room, "ground/room.png")

# Tutorial VR grid 34x20
vr = Image.new("RGBA", (34 * T, 20 * T), (226, 247, 252, 255))
d = ImageDraw.Draw(vr)
for x in range(0, vr.width, T):
    d.line([(x, 0), (x, vr.height)], fill=(140, 220, 240, 255))
for y in range(0, vr.height, T):
    d.line([(0, y), (vr.width, y)], fill=(140, 220, 240, 255))
for x in range(0, vr.width, 4 * T):
    d.line([(x, 0), (x, vr.height)], fill=(60, 190, 230, 255))
for y in range(0, vr.height, 4 * T):
    d.line([(0, y), (vr.width, y)], fill=(60, 190, 230, 255))
save(vr, "ground/tutorial.png")

# ---------------- UI ----------------
copy("ui/font.ttf", "Ui", "Font", "NormalFont.ttf")
copy("ui/dialog_box.png", "Ui", "Dialog", "DialogBoxFaceset.png")
copy("ui/dialog_simple.png", "Ui", "Dialog", "DialogueBoxSimple.png")
copy("ui/faceset_box.png", "Ui", "Dialog", "FacesetBox.png")
copy("ui/lifebar_under.png", "Ui", "Receptacle", "LifeBarMiniUnder.png")
copy("ui/lifebar_progress.png", "Ui", "Receptacle", "LifeBarMiniProgress.png")
copy("ui/heart.png", "Ui", "Receptacle", "IconHeart.png")
copy("ui/life_pot.png", "Items", "Potion", "LifePot.png")

# ---------------- cutscene panels (new style) ----------------
def up(img, s):
    return img.resize((img.width * s, img.height * s), Image.NEAREST)

def glow(canvas, center, radius, color, alpha=120):
    g = Image.new("RGBA", canvas.size)
    ImageDraw.Draw(g).ellipse((center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius), fill=color + (alpha,))
    canvas.alpha_composite(g.filter(ImageFilter.GaussianBlur(radius // 2)))

def frame_mirror(canvas, box, cracked=True):
    d = ImageDraw.Draw(canvas)
    x0, y0, x1, y1 = box
    d.rectangle(box, fill=(14, 16, 26, 255))
    for i, col in enumerate(((240, 240, 250), (170, 170, 190), (80, 80, 96))):
        d.rectangle((x0 - 10 + i * 4, y0 - 10 + i * 4, x1 + 10 - i * 4, y1 + 10 - i * 4), outline=col + (255,), width=4)
    if cracked:
        cx, cy = (x0 + x1) // 2 + 50, y0 + 110
        for _ in range(8):
            a = random.uniform(0, math.tau); px, py = cx, cy
            for _ in range(4):
                a += random.uniform(-0.5, 0.5)
                nx, ny = min(max(px + math.cos(a) * 60, x0), x1), min(max(py + math.sin(a) * 60, y0), y1)
                d.line([(px, py), (nx, ny)], fill=(225, 230, 245, 210), width=2); px, py = nx, ny

W, H = 1280, 720
knight = Image.open(out("chars/player_idle.png")).crop((0, 0, 16, 16))
knight_up = Image.open(out("chars/player_idle.png")).crop((16, 0, 32, 16))
evil = Image.open(out("chars/evil_idle.png")).crop((0, 0, 16, 16))
evil_l = Image.open(out("chars/evil_idle.png")).crop((32, 0, 48, 16))
me_r = Image.open(out("chars/player_idle.png")).crop((48, 0, 64, 16))

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); glow(c, (640, 320), 320, (150, 160, 190), 50)
frame_mirror(c, (420, 60, 860, 560)); r = up(gradient_map(knight, [(0, (20, 20, 30)), (1, (150, 160, 190))]), 14)
c.alpha_composite(r, (640 - r.width // 2, 330 - r.height // 2)); m = up(knight_up, 10); c.alpha_composite(m, (640 - m.width // 2, 560))
save(c, "cutscenes/final_01.png")

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); frame_mirror(c, (240, 30, 1040, 690))
f = up(gradient_map(knight, [(0, (10, 10, 16)), (1, (130, 130, 150))]), 36); c.alpha_composite(f, (640 - f.width // 2, 380 - f.height // 2))
for ex in (563, 707):
    glow(c, (ex, 330), 50, (255, 30, 40), 220)
save(c, "cutscenes/final_02.png")

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); frame_mirror(c, (600, 60, 1020, 600)); glow(c, (520, 380), 240, (255, 30, 40), 90)
e = up(evil, 20); c.alpha_composite(e, (520 - e.width // 2, 380 - e.height // 2))
icons = sorted(f for f in os.listdir(os.path.join(os.path.dirname(OUT), "ui")) if f.startswith("ui_artifact_") and f.endswith(".png"))
for i, ic in enumerate(icons):
    im = up(Image.open(os.path.join(os.path.dirname(OUT), "ui", ic)).convert("RGBA"), 2)
    a = -math.pi / 2 + i * math.tau / max(len(icons), 1)
    c.alpha_composite(im, (int(520 + math.cos(a) * 260 - 32), int(380 + math.sin(a) * 240 - 32)))
save(c, "cutscenes/final_03.png")

c = Image.new("RGBA", (W, H), (5, 5, 8, 255)); glow(c, (640, 380), 280, (255, 30, 40), 110)
ImageDraw.Draw(c).rectangle((636, 60, 644, 660), fill=(255, 60, 70, 230))
a1 = up(me_r, 20); a2 = up(evil_l, 20)
c.alpha_composite(a1, (380 - a1.width // 2, 380 - a1.height // 2)); c.alpha_composite(a2, (900 - a2.width // 2, 380 - a2.height // 2))
save(c, "cutscenes/final_04.png")

# Ending: a whole sky over quiet trees
c = Image.new("RGBA", (W, H))
d = ImageDraw.Draw(c)
for y in range(H):
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(40 + 170 * t), int(70 + 130 * t), int(120 + 100 * t), 255))
glow(c, (930, 430), 150, (255, 230, 180), 200)
trees = [Image.open(out("props/%s.png" % n)) for n in ("tree_green", "tree_pine", "tree_big", "tree_bush", "tree_roots")]
x = -40
while x < W:
    tr = random.choice(trees)
    sil = gradient_map(tr, [(0.0, (16, 22, 40)), (1.0, (40, 52, 80))])
    sc = random.choice((5, 6, 7))
    sil = up(sil, sc)
    c.alpha_composite(sil, (x, H - sil.height + random.randint(0, 40)))
    x += sil.width // 2 + random.randint(0, 30)
save(c, "cutscenes/ending.png")

print("ninja assets built:", len(props_meta), "props")
