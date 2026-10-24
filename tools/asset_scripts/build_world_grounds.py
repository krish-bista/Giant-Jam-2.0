"""Rebuilds the world grounds so the props sit on a layout that makes sense.

Usage: python build_world_grounds.py <original ground dir> <project>/assets/ninja

<original ground dir> holds the grounds as first baked by build_ninja_assets.py /
build_extra_assets.py (city, jungle, grim, sim .png). Their 16 px tiles are reused:
  city.png   -> a walled city block: north street front, a road with sidewalks through the
                middle, a round plaza in the center (the mirror opens there), crash scorches.
  grim.png   -> the same city thousands of years later, reflected left-to-right (the Hollow
                Future is the Fallen City's reversal): ash, cracks, the road broken open.
  jungle.png -> grass with dirt trails from the hunters' camp to a trampled central clearing.
  sim.png    -> the simulation village, cleaned up: no black holes or stray glitch lines,
                a clear holographic boundary instead.
Also writes the extra props the layouts use (road barrier, cars, saucer...) and grim versions.
"""
import math, os, random, sys
from collections import Counter
from PIL import Image, ImageDraw

SRC = sys.argv[1]
OUT = sys.argv[2]
EXTRA = sys.argv[3] if len(sys.argv) > 3 else ""
T = 16
random.seed(11)


def src(name):
    return Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def unique_tiles(img, n):
    c, t = Counter(), {}
    for ty in range(img.height // T):
        for tx in range(img.width // T):
            b = img.crop((tx * T, ty * T, tx * T + T, ty * T + T))
            c[b.tobytes()] += 1
            t[b.tobytes()] = b
    return [t[k] for k, _ in c.most_common(n)]


def gradient_map(img, stops):
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


def tile_fill(img, tiles, box, weights=None):
    x0, y0, x1, y1 = box
    for ty in range(y0, y1):
        for tx in range(x0, x1):
            t = random.choices(tiles, weights)[0] if weights else random.choice(tiles)
            img.alpha_composite(t, (tx * T, ty * T))


def blend(px, x, y, col, a):
    r, g, b, al = px[x, y]
    px[x, y] = (int(r + (col[0] - r) * a), int(g + (col[1] - g) * a), int(b + (col[2] - b) * a), al)


# ---------------- shared pieces ----------------
def stone_wall(w, h, base=(92, 86, 98), seed=0):
    """A pixel stone wall seen from the front: brick courses, a lit cap, a shadow at the foot."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (w, h), base + (255,))
    d = ImageDraw.Draw(img)
    mortar = tuple(max(0, c - 40) for c in base)
    hi = tuple(min(255, c + 26) for c in base)
    lo = tuple(max(0, c - 16) for c in base)
    bh, bw = 5, 11
    for row, y in enumerate(range(5, h - 3, bh)):
        off = (row % 2) * (bw // 2)
        d.line([(0, y), (w, y)], fill=mortar)
        for x in range(-off, w, bw):
            d.line([(x, y), (x, y + bh)], fill=mortar)
            shade = rnd.choice([base, base, lo, hi])
            d.rectangle((x + 1, y + 1, x + bw - 1, y + bh - 1), fill=shade)
            d.line([(x + 1, y + 1), (x + bw - 2, y + 1)], fill=hi)
    d.rectangle((0, 0, w, 4), fill=tuple(min(255, c + 40) for c in base))
    d.line([(0, 4), (w, 4)], fill=mortar)
    for i in range(3):
        d.line([(0, h - 1 - i), (w, h - 1 - i)], fill=tuple(max(0, c - 50 + i * 12) for c in base))
    return img


def foot_shadow(img, y, x0, x1, depth=4, strength=0.45):
    px = img.load()
    for i in range(depth):
        a = strength * (1 - i / depth)
        for x in range(max(0, x0), min(img.width, x1)):
            if 0 <= y + i < img.height:
                blend(px, x, y + i, (10, 8, 14), a)


def puddle(img, cx, cy, rx, ry):
    d = ImageDraw.Draw(img)
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(58, 68, 92, 255))
    d.ellipse((cx - rx + 2, cy - ry + 1, cx + rx - 3, cy + ry - 2), fill=(66, 78, 104, 255))
    d.arc((cx - rx + 2, cy - ry + 1, cx + rx - 2, cy + ry - 1), 190, 260, fill=(150, 170, 200, 255))


def scorch(img, cx, cy, r, seed=0):
    rnd = random.Random(seed)
    px = img.load()
    for y in range(int(cy - r - 2), int(cy + r + 2)):
        for x in range(int(cx - r - 2), int(cx + r + 2)):
            if not (0 <= x < img.width and 0 <= y < img.height):
                continue
            d = math.hypot((x - cx) / r, (y - cy) / (r * 0.7))
            n = rnd.random() * 0.25
            if d < 1.0:
                blend(px, x, y, (22, 16, 14), min(1.0, (1.0 - d) * 1.4 + n) * 0.85)
    dd = ImageDraw.Draw(img)
    for i in range(5):
        a = rnd.random() * math.tau
        x, y = cx + math.cos(a) * r * 0.2, cy + math.sin(a) * r * 0.15
        pts = [(x, y)]
        for _ in range(2):
            a += rnd.uniform(-0.4, 0.4)
            x += math.cos(a) * rnd.uniform(r * 0.25, r * 0.45)
            y += math.sin(a) * rnd.uniform(r * 0.15, r * 0.3)
            pts.append((x, y))
        dd.line(pts, fill=(18, 12, 12, 255))
    # glassy debris specks
    for _ in range(int(r)):
        a, d = rnd.random() * math.tau, rnd.random() * r
        dd.point((cx + math.cos(a) * d, cy + math.sin(a) * d * 0.7), fill=(52, 46, 44, 255))


def tufts(img, spots, col=(88, 130, 54), dark=(56, 92, 40)):
    d = ImageDraw.Draw(img)
    for (x, y) in spots:
        for k in range(random.randint(2, 4)):
            ox = x + random.randint(-3, 3)
            hgt = random.randint(2, 4)
            d.line([(ox, y), (ox + random.choice((-1, 0, 1)), y - hgt)], fill=random.choice((col, dark)))


def cracks(img, count, col, rnd, length=(3, 7), step=(3, 8)):
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rnd.randint(0, img.width), rnd.randint(0, img.height)
        a = rnd.random() * math.tau
        pts = [(x, y)]
        for _ in range(rnd.randint(*length)):
            a += rnd.uniform(-0.8, 0.8)
            x += math.cos(a) * rnd.uniform(*step)
            y += math.sin(a) * rnd.uniform(*step)
            pts.append((x, y))
        d.line(pts, fill=col)


# ---------------- THE FALLEN CITY ----------------
# Ground pixels are world / 3. World 2592 x 1440 -> 864 x 480 px (54 x 30 tiles).
CITY_W, CITY_H = 864, 480
ROAD = (208, 272)          # road y range (world 624..816)
WALK_N = (192, 208)        # north sidewalk
WALK_S = (272, 288)        # south sidewalk
PLAZA = (432, 240, 96)     # center + radius (world 1296, 720, r 288)
WALL_TOP = 48              # top city wall (world 0..144)
WALL_BOT = 448             # bottom wall from here (world 1344..1440)
SIDE = 16                  # side walls (world 48)
CRASHES = [(633, 357, 34), (553, 330, 14), (717, 336, 14), (233, 236, 12), (760, 226, 11)]


def build_city():
    city_src = src("city")
    cobble = unique_tiles(city_src, 18)
    road_tiles = [gradient_map(t, [(0.0, (30, 30, 36)), (0.5, (66, 66, 74)), (1.0, (108, 106, 112))]) for t in cobble]
    walk_tiles = [gradient_map(t, [(0.0, (74, 70, 70)), (0.5, (138, 130, 120)), (1.0, (186, 178, 164))]) for t in cobble]
    img = Image.new("RGBA", (CITY_W, CITY_H))
    tile_fill(img, cobble, (0, 0, CITY_W // T, CITY_H // T))
    tile_fill(img, road_tiles, (0, ROAD[0] // T, CITY_W // T, ROAD[1] // T))
    tile_fill(img, walk_tiles, (0, WALK_N[0] // T, CITY_W // T, WALK_N[1] // T))
    tile_fill(img, walk_tiles, (0, WALK_S[0] // T, CITY_W // T, WALK_S[1] // T))
    d = ImageDraw.Draw(img)
    # Plaza: a paved circle with two curbs and a mirror-line seam across it
    cx, cy, r = PLAZA
    plaza = Image.new("RGBA", (CITY_W, CITY_H))
    tile_fill(plaza, walk_tiles, (0, 0, CITY_W // T, CITY_H // T))
    mask = Image.new("L", (CITY_W, CITY_H), 0)
    ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    img.paste(plaza, (0, 0), mask)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(204, 198, 186, 255), width=2)
    d.ellipse((cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2), outline=(40, 38, 44, 255), width=1)
    d.ellipse((cx - r + 14, cy - r + 14, cx + r - 14, cy + r - 14), outline=(118, 112, 106, 255), width=1)
    d.ellipse((cx - 22, cy - 22, cx + 22, cy + 22), outline=(118, 112, 106, 255), width=1)
    for i in range(8):
        a = i * math.tau / 8
        d.line([(cx + math.cos(a) * 24, cy + math.sin(a) * 24), (cx + math.cos(a) * (r - 15), cy + math.sin(a) * (r - 15))], fill=(124, 118, 110, 255))
    # Curbs along the road (not across the plaza)
    for y, edge in ((ROAD[0], (210, 204, 192)), (ROAD[1] - 1, (210, 204, 192))):
        for x in range(CITY_W):
            if math.hypot(x - cx, y - cy) > r + 1:
                img.putpixel((x, y), edge + (255,))
                yy = y + 1 if y == ROAD[0] else y - 1
                img.putpixel((x, yy), (38, 38, 44, 255))
    # Lane markings: dashed center line (skips the plaza)
    for x in range(4, CITY_W, 22):
        if abs(x + 5 - cx) > r + 4:
            d.rectangle((x, 239, x + 10, 240), fill=(214, 196, 120, 255))
    # Crash scorches where the pods came down
    for i, (x, y, rr) in enumerate(CRASHES):
        scorch(img, x, y, rr, i)
    # Rain puddles on the road and pavement
    for (x, y, rx, ry) in [(120, 230, 9, 4), (300, 258, 12, 4), (540, 220, 8, 3), (660, 252, 10, 4), (812, 234, 9, 3),
                           (160, 120, 7, 3), (380, 150, 9, 3), (700, 140, 8, 3), (110, 330, 8, 3), (480, 360, 10, 4), (300, 410, 7, 3)]:
        puddle(img, x, y, rx, ry)
    # City walls: north, south, and the sides (the road runs out through gaps)
    top = stone_wall(CITY_W, WALL_TOP, seed=1)
    img.alpha_composite(top, (0, 0))
    foot_shadow(img, WALL_TOP, 0, CITY_W, 5, 0.5)
    bot = stone_wall(CITY_W, CITY_H - WALL_BOT, seed=2)
    img.alpha_composite(bot, (0, WALL_BOT))
    foot_shadow(img, WALL_BOT - 3, 0, CITY_W, 3, 0.25)
    for x0 in (0, CITY_W - SIDE):
        for (y0, y1) in ((WALL_TOP, WALK_N[0] - 6), (WALK_S[1] + 6, WALL_BOT)):
            side = stone_wall(SIDE, y1 - y0, seed=3 + x0)
            img.alpha_composite(side, (x0, y0))
    # Weeds at the foot of the walls and along the curbs
    spots = [(x, WALL_TOP + 3) for x in range(10, CITY_W, 37)] + [(x, WALL_BOT - 1) for x in range(20, CITY_W, 41)]
    spots += [(x, WALK_N[0] - 1) for x in range(30, CITY_W, 97)] + [(x, WALK_S[1] + 2) for x in range(60, CITY_W, 89)]
    tufts(img, spots)
    return img


# ---------------- THE HOLLOW FUTURE: the city, reflected and rotted ----------------
def build_grim(city):
    rnd = random.Random(5)
    g = city.transpose(Image.FLIP_LEFT_RIGHT)
    g = gradient_map(g, [(0.0, (14, 12, 16)), (0.35, (44, 40, 46)), (0.7, (86, 80, 84)), (1.0, (140, 132, 128))])
    d = ImageDraw.Draw(g)
    # Broken road: pits where the paving fell through
    for _ in range(16):
        x, y = rnd.randint(30, CITY_W - 30), rnd.randint(ROAD[0] - 8, ROAD[1] + 8)
        w, h = rnd.randint(6, 16), rnd.randint(3, 7)
        d.ellipse((x - w - 1, y - h - 1, x + w + 1, y + h + 1), fill=(30, 26, 30, 255))
        d.ellipse((x - w, y - h, x + w, y + h), fill=(8, 6, 10, 255))
        d.arc((x - w, y - h, x + w, y + h), 20, 160, fill=(64, 58, 62, 255))
    cracks(g, 70, (10, 8, 12, 255), rnd, (2, 4), (4, 9))
    # Faint red seams: the crack still bleeding light through the floor
    seams = Image.new("RGBA", g.size)
    cracks(seams, 9, (150, 30, 40, 255), rnd, (5, 9), (5, 11))
    glow = seams.filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(2))
    g.alpha_composite(glow)
    g.alpha_composite(seams)
    # Ash drifts
    px = g.load()
    for _ in range(90):
        x, y, r = rnd.randint(0, CITY_W - 1), rnd.randint(0, CITY_H - 1), rnd.randint(6, 18)
        for yy in range(y - r, y + r):
            for xx in range(x - r, x + r):
                if 0 <= xx < CITY_W and 0 <= yy < CITY_H and math.hypot(xx - x, (yy - y) * 1.6) < r and rnd.random() < 0.6:
                    blend(px, xx, yy, (120, 114, 112), 0.12)
    return g


# ---------------- THE FIRST HUNT ----------------
JUNGLE_TRAILS = [
    # (points in ground px, half width)
    ([(433, 330), (436, 300), (432, 270)], 9),                 # spawn -> clearing
    ([(433, 330), (395, 352), (345, 372), (300, 382)], 8),     # spawn -> hunters' camp
    ([(345, 240), (290, 228), (230, 200), (175, 150)], 7),     # clearing -> bamboo grove (NW)
    ([(520, 230), (580, 205), (640, 170), (680, 140)], 7),     # clearing -> rock outcrop (NE)
    ([(500, 290), (560, 320), (620, 345)], 6),                 # clearing -> east glade
]
JUNGLE_CLEARING = (432, 240, 92)


def build_jungle():
    jun = src("jungle")
    grass = unique_tiles(jun, 5)
    dirt = jun.crop((44 * T, 10 * T, 45 * T, 11 * T))
    img = Image.new("RGBA", (864, 480))
    tile_fill(img, grass, (0, 0, 54, 30), [10, 2, 2, 1, 1])
    # Dirt mask: trails + the trampled clearing (ragged edge)
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    for pts, hw in JUNGLE_TRAILS:
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            steps = int(math.hypot(x1 - x0, y1 - y0) / 2) + 1
            for s in range(steps + 1):
                t = s / steps
                x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
                w = hw * (1.0 + 0.25 * math.sin(s * 0.35 + i)) + random.uniform(-1.5, 1.5)
                md.ellipse((x - w, y - w * 0.8, x + w, y + w * 0.8), fill=255)
    cx, cy, r = JUNGLE_CLEARING
    poly = []
    ph = random.random() * 10
    for i in range(72):
        a = i * math.tau / 72
        rr = r * (1.0 + 0.07 * math.sin(a * 3 + ph) + 0.04 * math.sin(a * 7 + ph * 2)) + random.uniform(-2, 2)
        poly.append((cx + math.cos(a) * rr * 1.05, cy + math.sin(a) * rr * 0.78))
    md.polygon(poly, fill=255)
    # Hunters' camp: a packed-earth yard
    poly = []
    for i in range(40):
        a = i * math.tau / 40
        rr = 36 + random.uniform(-3, 3) + 4 * math.sin(a * 2)
        poly.append((300 + math.cos(a) * rr * 1.1, 382 + math.sin(a) * rr * 0.8))
    md.polygon(poly, fill=255)
    dirt_layer = Image.new("RGBA", img.size)
    for y in range(0, img.height, T):
        for x in range(0, img.width, T):
            dirt_layer.alpha_composite(dirt, (x, y))
    img.paste(dirt_layer, (0, 0), mask)
    # Edges: a dark grass lip and blades leaning over the dirt
    mp = mask.load()
    px = img.load()
    edge = []
    for y in range(1, img.height - 1):
        for x in range(1, img.width - 1):
            if mp[x, y] == 0 and (mp[x + 1, y] or mp[x - 1, y] or mp[x, y + 1] or mp[x, y - 1]):
                px[x, y] = (72, 118, 46, 255)
                edge.append((x, y))
            elif mp[x, y] and not (mp[x + 1, y] and mp[x - 1, y] and mp[x, y + 1] and mp[x, y - 1]):
                px[x, y] = (122, 78, 50, 255)
    tufts(img, random.sample(edge, len(edge) // 9), (104, 150, 58), (74, 120, 48))
    d = ImageDraw.Draw(img)
    # Darker earth and pebbles on the dirt
    for _ in range(260):
        x, y = random.randint(2, 861), random.randint(2, 477)
        if mp[x, y] and mp[x + 2, y] and mp[x - 2, y]:
            if random.random() < 0.5:
                d.rectangle((x, y, x + random.randint(1, 3), y), fill=(118, 76, 48, 255))
            else:
                d.point((x, y), fill=(168, 150, 124, 255))
                d.point((x, y + 1), fill=(96, 64, 44, 255))
    # Scattered grass tufts and tiny flowers in the open grass (not on the dirt)
    for _ in range(420):
        x, y = random.randint(4, 859), random.randint(4, 475)
        if mp[x, y]:
            continue
        if random.random() < 0.8:
            tufts(img, [(x, y)], (98, 142, 56), (70, 112, 44))
        else:
            c = random.choice([(236, 220, 120), (230, 120, 110), (240, 240, 230)])
            d.point((x, y), fill=c + (255,))
            d.point((x + 1, y + 1), fill=(70, 112, 44, 255))
    return img


# ---------------- THE SIMULATION ----------------
def build_sim():
    sim = src("sim")
    base = Image.new("RGBA", sim.size, (114, 202, 221, 255))
    base.alpha_composite(sim)
    px = base.load()
    W, H = base.size
    # Remove the glitch strips (semi-transparent magenta) by copying the pixel 4 rows up
    orig = sim.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = orig[x, y]
            if r > 200 and g < 120 and b > 160:
                yy = y - 4 if y >= 4 else y + 4
                px[x, y] = px[x, yy]
    # Fill the black "unrendered" tiles with clean holo grass tiles
    holo_grass = [base.crop((tx * T, ty * T, tx * T + T, ty * T + T)) for ty in range(3, 9) for tx in range(3, 11)]
    holo_path = [base.crop((tx * T, ty * T, tx * T + T, ty * T + T)) for ty in (11, 12) for tx in range(4, 10)]
    TW, TH = W // T, H // T
    for ty in range(TH):
        for tx in range(TW):
            if min(tx, ty, TW - 1 - tx, TH - 1 - ty) >= 2:
                continue
            on_path = tx in (19, 20) or ty in (11, 12)
            base.paste(random.choice(holo_path if on_path else holo_grass), (tx * T, ty * T))
    # A clean holographic boundary: the simulation fades out at the edges behind a light wall
    for y in range(H):
        for x in range(W):
            e = min(x, y, W - 1 - x, H - 1 - y)
            if e < 22:
                blend(px, x, y, (20, 60, 86), (1 - e / 22) ** 1.6 * 0.75)
    d = ImageDraw.Draw(base)
    d.rectangle((18, 18, W - 19, H - 19), outline=(190, 250, 255, 255), width=1)
    d.rectangle((20, 20, W - 21, H - 21), outline=(110, 220, 240, 255), width=1)
    for x in range(18, W - 18, 32):
        d.rectangle((x, 16, x + 2, 18), fill=(190, 250, 255, 255))
        d.rectangle((x, H - 19, x + 2, H - 17), fill=(190, 250, 255, 255))
    for y in range(18, H - 18, 32):
        d.rectangle((16, y, 18, y + 2), fill=(190, 250, 255, 255))
        d.rectangle((W - 19, y, W - 17, y + 2), fill=(190, 250, 255, 255))
    return base


# ---------------- extra props ----------------
GRIM = [(0.0, (8, 4, 12)), (0.45, (52, 44, 50)), (0.8, (118, 108, 110)), (1.0, (180, 170, 168))]


def build_props():
    props = os.path.join(OUT, "props")
    if EXTRA:
        for name, out in [("car_wreck", "car_blue"), ("car_wreck_red", "car_red"), ("car_wreck_taxi", "car_taxi"),
                          ("barricade", "road_barrier"), ("saucer_wreck", "saucer_wreck"), ("bones_ribs", "bones_ribs"),
                          ("dino_skull", "dino_skull"), ("pod_broken", "pod_broken"), ("machine_wreck", "machine_wreck")]:
            Image.open(os.path.join(EXTRA, name + ".png")).convert("RGBA").save(os.path.join(props, out + ".png"))
    for name in ["town_house_a", "town_house_b", "town_house_c", "town_shop", "town_red", "ruin_a", "ruin_b", "ruin_c",
                 "ruin_house_big", "ruin_rubble", "lamp_post", "car_blue", "car_red", "car_taxi", "road_barrier",
                 "saucer_wreck", "alien_pod", "tent_torn", "statue_lion", "barricade", "moss_tree", "pod_broken"]:
        img = Image.open(os.path.join(props, name + ".png")).convert("RGBA")
        save(gradient_map(img, GRIM), "props/grim_%s.png" % name)


if __name__ == "__main__":
    build_props()
    city = build_city()
    save(city, "ground/city.png")
    save(build_grim(city), "ground/grim.png")
    save(build_jungle(), "ground/jungle.png")
    save(build_sim(), "ground/sim.png")
    print("grounds rebuilt")
