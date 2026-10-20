"""Ground tiles, extension 2: extra road markings, parking, gentle slopes, stairs,
tunnels and access ramps, outdoor pools, waterfront tiles, playground / woodland
ground, railway switches and catenary, driveways, speed bumps, bus and bike lanes.

Builds on the base helpers in ground.py. Every tile is a 32x32 (T) voxel model
(1 voxel = 12.5 cm; x = left->right, y = front->back, z = up; front = y=0)
registered via @tile / register from common.py; generate.py writes them out as
.vox + .tile.json. Road surface tops out at z=ROAD (2), sidewalk/grass at
z=WALK (3); one ground layer is FLOOR (8) voxels.

`tunnel` and `access_ramp` are also used by extras5.py.
"""
from functools import partial

from common import T, ROAD, WALK, FLOOR, tile, register, slopes, smooth, text_pixels
from palette import P
from vox import V, mix, pick, h, blocky
from ground import (new, column, flat, paint, line_y, line_x, paint_bitmap, lane, sidewalk, grass_tile, water_tile,
                    padded, paver_fn, track_straight, grass_floor, arrow, bike_path_one_way, stairs_1m, train_level_crossing,
                    train_straight, tram_rails_straight, ASPHALT, BIKE_ASPHALT, BUS, MARK, PAVING, CURB, GRASS, SAND,
                    CONCRETE, CONCRETE_DARK, NATURAL_STONE, WATER, DASH, bike_path_straight, road_plain, street_pavers,
                    square_tiles, grass, dist, brick_fn)

PAVING_WHITE = mix("tegel_wit", "stuc2", seed=300, weights=[5, 1])


# ------------------------------------------------------------------ shared helpers

def stamp_text(m, text, x0, y0, c=MARK, scale=2):
    """Paint `text` (5-row bitmap font) onto the top surface of `m`, magnified by `scale`.

    (x0, y0) is the lower-left corner; the top font row ends up at the highest y,
    so the text reads correctly for someone driving in +y direction.
    """
    px, _ = text_pixels(text)
    for (cx, r) in px:
        for sy in range(scale):
            for sx in range(scale):
                paint(m, x0 + cx * scale + sx, y0 + (4 - r) * scale + sy, c)


def water_bed(m, x, y, bed="waterbodem"):
    """Fill column (x, y) with a bed voxel at z=0 and one layer of water at z=1."""
    m.set(x, y, 0, bed)
    m.set(x, y, 1, WATER)


# ------------------------------------------------------------------ markings

@tile("grond/weg/rijstrook_stop_tekst")
def stop_text():
    """Lane with a 3-voxel stop line near the back and "STOP" painted in front of it."""
    m = lane("streep", "kant")
    for y in range(27, 30):
        line_x(m, y, 0, 31)
    stamp_text(m, "STOP", 1, 12)
    return m


@tile("grond/weg/pianostrepen")
def piano_stripes():
    """Flat asphalt with transverse 'piano' stripes (2 voxels on, 2 off) across x=4..27."""
    m = flat()
    for y in range(T):
        for x in range(4, 28):
            if (y // 2) % 2 == 0:
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/kruis_markering")
def cross_marking():
    """Yellow X (2 voxels wide) painted diagonally across the tile."""
    m = flat()
    for i in range(4, 28):
        for k in (0, 1):
            paint(m, i + k, i, P["markering_geel"])
            paint(m, 31 - i - k, i, P["markering_geel"])
    return m


@tile("grond/weg/straat_eenrichting")
def street_one_way():
    """Flat asphalt with a single straight-ahead arrow."""
    m = flat()
    arrow(m, "rechtdoor")
    return m


def crossing(kind):
    """Intersection tile (one tile = a whole crossing of narrow streets).

    kind: "stop" = solid 2-voxel stop line on all four sides, "haaientanden" =
    dashed 'shark teeth' line on all four sides, anything else = plain asphalt.
    """
    m = flat()
    if kind in ("stop", "haaientanden"):
        for side in range(4):
            for i in range(4, 28):
                if kind == "haaientanden" and (i // 3) % 2:
                    continue
                for k in range(2):
                    x, y = i, 1 + k
                    # rotate the front-edge line by 90 degrees `side` times
                    for _ in range(side):
                        x, y = 31 - y, x
                    paint(m, x, y, MARK)
    return m


register("grond/weg/kruising_stop", lambda: crossing("stop"))
register("grond/weg/kruising_haaientanden", lambda: crossing("haaientanden"))
register("grond/weg/kruising_vlak", lambda: crossing("vlak"))


@tile("grond/weg/rijstrook_doorgetrokken_dubbel")
def solid_double():
    """Lane with a double solid centre line and an edge line."""
    return lane("dubbel", "kant")


@tile("grond/weg/middengeleider")
def traffic_island():
    """Lane with a raised traffic island (grass between curbs, x=0..3) along the left side,
    with a white keep-right sign post (blue top) every 16 voxels."""
    m = lane("geen", "kant")
    for y in range(T):
        for x in range(0, 4):
            column(m, x, y, WALK + 1, CURB if x in (0, 3) else GRASS, CURB)
    for y in range(T):
        if y % 16 == 4:
            for z in range(WALK + 1, WALK + 6):
                m.set(1, y, z, "bord_wit")
            m.set(1, y, WALK + 5, "bord_blauw")
    return m


@tile("grond/weg/middengeleider_breed")
def traffic_island_wide():
    """Wide central island (x=10..21, grass between curbs) with an edge line on both carriageways."""
    m = new()
    for y in range(T):
        for x in range(T):
            if 10 <= x < 22:
                column(m, x, y, WALK + 1, CURB if x in (10, 21) else GRASS, CURB)
            else:
                column(m, x, y, ROAD, ASPHALT)
    line_y(m, 8)
    line_y(m, 23)
    return m


@tile("grond/weg/middengeleider_kop")
def traffic_island_head():
    """Rounded front end of the wide island, with diagonal hatching in front of it."""
    m = flat()
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            if 10 <= x < 22 and (y >= 16 or d < 6):
                column(m, x, y, WALK + 1, CURB if (x in (10, 21) or (y < 16 and d > 5)) else GRASS, CURB)
    for y in range(4, 10):
        for x in range(T):
            if (x + y) % 6 < 2 and 6 <= x < 26:
                paint(m, x, y, MARK)
    return m


# ------------------------------------------------------------------ parking

@tile("grond/parkeren/parkeervak_haaks")
def parking_bay_perpendicular():
    """Perpendicular parking bay: line along the left edge and a front line at y=4."""
    m = flat()
    for y in range(4, T):
        paint(m, 0, y, MARK)
    for x in range(T):
        paint(m, x, 4, MARK)
    return m


@tile("grond/parkeren/parkeervak_haaks_eind")
def parking_bay_perpendicular_end():
    """Last perpendicular bay of a row: also closed on the right edge."""
    m = parking_bay_perpendicular()
    for y in range(4, T):
        paint(m, 31, y, MARK)
    return m


@tile("grond/parkeren/parkeervak_laadpaal")
def parking_bay_charger():
    """Perpendicular bay painted green with a large 'E' (EV charging)."""
    m = parking_bay_perpendicular()
    for y in range(8, 28):
        for x in range(4, 28):
            paint(m, x, y, P["bord_groen"])
    paint_bitmap(m, ["###", "#..", "##.", "#..", "###"], 13, 13, MARK, scale=2)
    return m


@tile("grond/parkeren/parkeervak_schuin")
def parking_bay_angled():
    """Angled (diagonal) parking bays, two per tile, with a line along the front."""
    m = flat()
    for y in range(T):
        x = (y + 4) % 16
        paint(m, x, y, MARK)
        paint(m, x + 16, y, MARK)
    for x in range(T):
        paint(m, x, 0, MARK)
    return m


@tile("grond/parkeren/parkeervak_klinkers")
def parking_bay_pavers():
    """Brick-paver parking bay with a marking row along the left edge."""
    def f(x, y, z):
        return P["markering2"] if x == 0 else paver_fn(x, y, z)
    return flat(f)


@tile("grond/parkeren/parkeerplaats_rijbaan")
def parking_lot_aisle():
    """Parking-lot aisle: asphalt with a straight-ahead arrow starting at y=6."""
    m = flat()
    arrow(m, "rechtdoor", 16, 6)
    return m


# ------------------------------------------------------------------ gentle slopes (0.5 m per tile)

# Made by the importer (addons/vox_tiles/slopes.gd): grond/helling/flauw_<name>_a (lower
# half of a 1 m rise over two tiles, 0..3 voxels) and _b (upper half, 4..7 voxels).
for _p in ("weg/weg_vlak", "weg/rijstrook_onderbroken_kant", "weg/rijstrook_geen_kant", "fietspad/fietspad_recht",
           "stoep/stoep_vol", "stoep/stoep_rand", "stoep/stoep_goot_rand", "weg/straat_klinkers",
           "plein/plein_tegels", "natuur/gras"):
    slopes("grond/" + _p, "flauw_a", "flauw_b")

# extra steep slopes for sidewalk corners and the one-way bike path beside the road
slopes("grond/stoep/stoep_hoek_buiten", "steil")
slopes("grond/fietspad/fietspad_eenrichting", "steil")


def _stair_top(y):
    """Top height of the 1 m stairs at row y: landing (y<8), 8 steps of 2 rows, upper landing."""
    if y < 8:
        return WALK
    if y < 24:
        return WALK + 1 + (y - 8) // 2
    return WALK + FLOOR


@tile("grond/terrein/trap_1m_fietsgoot")
def stairs_bike_gutter():
    """1 m stairs with a metal bicycle gutter (x=4..5) cut into the steps."""
    m = stairs_1m()
    for y in range(8, 24):
        top = _stair_top(y)
        for x in (4, 5):
            for z in range(top - 1, top + 2):
                m.set(x, y, z, 0)
            m.set(x, y, top - 1, "metaal2")
    return m


@tile("grond/terrein/trap_1m_breed")
def stairs_1m_wide():
    """Full-width 1 m stone stairs between paved landings."""
    m = V(T, T, FLOOR + 8)
    for y in range(T):
        top = _stair_top(y)
        for x in range(T):
            column(m, x, y, top, NATURAL_STONE if 8 <= y < 24 else PAVING, CONCRETE_DARK)
    return m


# ------------------------------------------------------------------ tunnels

TH = 48     # 6 ground layers: place tunnel tiles on layer -6, the roof ends up at street level
CEIL = 40   # first z of the concrete roof slab; walls run from z=0 up to here


def tunnel(wall=True, line=True, portal=False, bicycle=False):
    """Tunnel section (T x T x TH) running along y.

    wall: concrete retaining wall with white tiling on the left (x=0..1), plus curb.
    line: paint lane markings (car tunnels only).
    portal: add the entrance beam with the word TUNNEL on the front face (y=0).
    bicycle: red bike-path asphalt instead of car asphalt.
    Ceiling lamps run along y (x=10 and 22 with a wall, centred otherwise).
    """
    m = V(T, T, TH)
    for y in range(T):
        for x in range(T):
            column(m, x, y, ROAD, BIKE_ASPHALT if bicycle else ASPHALT, CONCRETE_DARK)
            for z in range(CEIL, TH):
                m.set(x, y, z, CONCRETE if z < TH - 1 else "beton_donker")
    if line and not bicycle:
        line_y(m, 31, dash=DASH)
        line_y(m, 2)
    if wall:
        for y in range(T):
            for z in range(0, CEIL):
                for x in (0, 1):
                    m.set(x, y, z, CONCRETE_DARK if x == 0 else (PAVING_WHITE if 3 <= z < 30 else CONCRETE))
                # every 16 voxels a vertical tile band with a green (emergency exit) mark
                if 3 <= z < 30 and y % 16 == 0:
                    m.set(1, y, z, "bord_groen" if z == 12 else ("tegel_wit" if z % 2 else "stuc2"))
            m.set(2, y, ROAD, CURB)
            m.set(2, y, ROAD + 1, CURB)
    lamp_xs = (10, 22) if wall else (16,)
    for y in range(T):
        if y % 4 < 3:
            for x in lamp_xs:
                m.set(x, y, CEIL - 1, "lamp_wit")
    if portal:
        for x in range(T):
            for z in range(36, TH):
                m.set(x, 0, z, "beton_donker" if z in (36, TH - 1) else CONCRETE)
                m.set(x, 1, z, CONCRETE)
        px, (tw, _) = text_pixels("TUNNEL")
        cx = 20 if wall else 16   # text centre; shifted right when the wall is on the left
        for (c, r) in px:
            m.set(cx - tw // 2 + c, 0, 44 - r, "bord_wit")
    return m


register("grond/tunnel/tunnel_rijstrook_wand", lambda: tunnel(True))
register("grond/tunnel/tunnel_rijstrook", lambda: tunnel(False))
register("grond/tunnel/tunnel_rijstrook_wand_portaal", lambda: tunnel(True, portal=True))
register("grond/tunnel/tunnel_rijstrook_portaal", lambda: tunnel(False, portal=True))
register("grond/tunnel/tunnel_fiets_wand", lambda: tunnel(True, bicycle=True))
register("grond/tunnel/tunnel_fiets_wand_portaal", lambda: tunnel(True, bicycle=True, portal=True))


@tile("grond/tunnel/tunnel_middenwand")
def tunnel_center_wall():
    """Tunnel without side wall but with a central dividing wall (x=15..16) with openings every 8 voxels."""
    m = tunnel(False, line=False)
    for y in range(T):
        for z in range(0, CEIL):
            for x in (15, 16):
                m.set(x, y, z, CONCRETE)
        if y % 8 == 2:
            for z in range(4, 10):
                m.set(15, y, z, 0)
                m.set(16, y, z, 0)
    return m


def access_ramp(depth, wall=True, bicycle=False):
    """Tunnel access ramp: a slope on layer -depth rising one layer (1 m) towards the back (+y).

    wall: add a retaining wall on the left (x=0..1) up to street level, topped with a
    metal railing. bicycle: bike-path asphalt and no lane markings.
    """
    base = flat(BIKE_ASPHALT if bicycle else ASPHALT)
    if not bicycle:
        line_y(base, 31, dash=DASH)
        line_y(base, 2)
    m = padded(base)   # smoothed into a slope by the importer (smooth() below)
    if not wall:
        return m
    out = V(T, T, depth * FLOOR + 8)
    out.paste(m, 0, 0, 0)
    top = depth * FLOOR + WALK   # street (sidewalk) level relative to the ramp layer
    for y in range(T):
        for z in range(0, top):
            out.set(0, y, z, CONCRETE_DARK if (z % 12 == 0) else CONCRETE)
            out.set(1, y, z, CONCRETE)
        for z in range(top, top + 6):
            out.set(0, y, z, "metaal_donker" if (z == top + 5 or y % 8 == 0) else 0)
    return out


for _d in range(1, 7):
    register(f"grond/tunnel/tunnel_toerit_wand_d{_d}", partial(access_ramp, _d))
    register(f"grond/tunnel/tunnel_toerit_d{_d}", partial(access_ramp, _d, False))
    smooth(f"grond/tunnel/tunnel_toerit_wand_d{_d}", "steil", keep_x=(0, 1))
    smooth(f"grond/tunnel/tunnel_toerit_d{_d}", "steil")
for _d in range(1, 7):
    register(f"grond/tunnel/fietstunnel_toerit_wand_d{_d}", partial(access_ramp, _d, True, True))
    smooth(f"grond/tunnel/fietstunnel_toerit_wand_d{_d}", "steil", keep_x=(0, 1))


# ------------------------------------------------------------------ outdoor pool (place on layer -1)

PH = FLOOR + WALK    # 11: the rim ends up at sidewalk level of layer 0
POOL_TOP = PH - 4    # water fills up to (excluding) this height: 50 cm below the rim
POOL_WATER = mix("water_zwembad", "water_zwembad", "water3", seed=301, weights=[3, 3, 1])


def _edge_distance(x, y, edges):
    """Distance (voxels) from (x, y) to the nearest edge named in `edges`
    (v/a/l/r = front/back/left/right); 99 when no edges are given."""
    ds = [d for e, d in (("v", y), ("a", 31 - y), ("l", x), ("r", 31 - x)) if e in edges]
    return min(ds) if ds else 99


def pool(edges="", stairs=False):
    """Pool section. `edges` (v/a/l/r) get a 3-voxel tiled rim with a stone coping;
    stairs=True adds steps into the water along the front rim (requires "v")."""
    m = V(T, T, PH + 1)
    for y in range(T):
        for x in range(T):
            if _edge_distance(x, y, edges) < 3:
                for z in range(PH):
                    m.set(x, y, z, "natuursteen1" if z == PH - 1 else "tegel_wit")
            else:
                # blue floor with white tile lines and a coarse checker pattern
                m.set(x, y, 0, "paneel_blauw" if (x + y) % 8 else "tegel_wit")
                m.set(x, y, 1, "paneel_blauw" if (x // 4 + y // 4) % 2 else "tegel_wit")
                for z in range(2, POOL_TOP):
                    m.set(x, y, z, POOL_WATER)
    if stairs and "v" in edges:
        for i in range(5):
            for x in range(10, 22):
                for z in range(0, PH - 2 - i * 2):
                    m.set(x, 3 + i, z, "tegel_wit" if z < PH - 3 - i * 2 else "natuursteen1")
    return m


register("grond/zwembad/zwembad_midden", lambda: pool(""))
register("grond/zwembad/zwembad_rand", lambda: pool("v"))
register("grond/zwembad/zwembad_hoek", lambda: pool("vr"))
register("grond/zwembad/zwembad_rand_trap", lambda: pool("v", stairs=True))
register("grond/zwembad/zwembad_eind", lambda: pool("var"))


@tile("grond/zwembad/zwembad_kant_tegels")
def pool_edge():
    """Pool deck: 4x4 checker of white tiles and plaster at sidewalk height."""
    def f(x, y, z):
        return P["tegel_wit"] if (x // 4 + y // 4) % 2 else P["stuc2"]
    return flat(f, top=WALK)


@tile("grond/zwembad/kinderbad")
def paddling_pool():
    """Round paddling pool (r=13) sunk into a white-tiled deck, with a stone rim."""
    m = V(T, T, 6)
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            column(m, x, y, WALK, PAVING_WHITE)
            if d < 13:
                # sunken: water 25 cm below the rim
                m.set(x, y, WALK - 3, "paneel_blauw")
                m.set(x, y, WALK - 2, POOL_WATER)
                m.set(x, y, WALK - 1, 0)
                m.set(x, y, WALK, 0)
            elif d < 15:
                m.set(x, y, WALK, "natuursteen1")
    return m


# ------------------------------------------------------------------ waterfront

def _beach(dfun, pebbles):
    """Beach: water where dfun(x, y) < 12, wet sand at road height up to 20, dry sand beyond.
    pebbles=True scatters a few gravel voxels on the dry sand."""
    m = new(8)
    for y in range(T):
        for x in range(T):
            d = dfun(x, y)
            if d < 12:
                water_bed(m, x, y, "zand2")
            elif d < 20:
                column(m, x, y, ROAD, SAND)
            else:
                column(m, x, y, WALK, SAND)
                if pebbles and h(x, y, 0, 302) < 0.02:
                    m.set(x, y, WALK, "grind3")
    return m


@tile("grond/waterkant/strand")
def beach():
    """Straight beach: water at the front (y<12), sand rising towards the back."""
    return _beach(lambda x, y: y, True)


@tile("grond/waterkant/strand_hoek")
def beach_corner():
    """Beach corner: water along the front and right edges."""
    return _beach(lambda x, y: min(y, 31 - x), False)


@tile("grond/waterkant/beschoeiing")
def revetment():
    """Water at the front, a wooden revetment (y=14..15) and grass behind it."""
    m = new(8)
    for y in range(T):
        for x in range(T):
            if y < 14:
                water_bed(m, x, y)
            elif y < 16:
                for z in range(0, WALK + 1):
                    m.set(x, y, z, "hout_donker2" if x % 4 else "hout_donker1")
            else:
                column(m, x, y, WALK, GRASS)
    return m


@tile("grond/waterkant/basalt_talud")
def basalt_slope():
    """Water at the front, a sloping basalt embankment (y=10..23) and a grass dike top."""
    m = new(8)
    for y in range(T):
        for x in range(T):
            if y < 10:
                water_bed(m, x, y)
            elif y < 24:
                top = 1 + (y - 10) // 4
                column(m, x, y, top, pick(["antraciet3", "antraciet1", "alg2"], x // 2, y // 2, 0, 303, [3, 2, 1]), "antraciet3")
            else:
                column(m, x, y, WALK + 2, GRASS)
    return m


@tile("grond/waterkant/boulevard")
def boulevard():
    """Seaside promenade: water at the front, a raised concrete wall (y=8..9), paved boulevard behind."""
    m = new(10)
    for y in range(T):
        for x in range(T):
            if y < 8:
                water_bed(m, x, y)
            elif y < 10:
                for z in range(0, WALK + 4):
                    m.set(x, y, z, CONCRETE)
            else:
                column(m, x, y, WALK, blocky(["plein1", "plein2", "plein_rood"], size=4, seed=304))
    return m


def quay_stairs():
    """Stone stairs from the quay (layer 0) down to the water (layer -2) between brick
    side walls, with metal handrails. Place on layer -2."""
    H = FLOOR * 2 + WALK
    m = V(T, T, H + 8)
    brick = lambda a, b, c: brick_fn(a, b, c, 305)

    def step_top(y):
        return 2 + int(y * (H - 2) / 31.0)

    for y in range(T):
        top = step_top(y)
        for x in range(T):
            if 6 <= x < 26:
                for z in range(0, top):
                    m.set(x, y, z, NATURAL_STONE if z >= top - 1 else "natuursteen3")
            else:
                for z in range(0, H):
                    m.set(x, y, z, brick)
        if y < 2:
            for x in range(T):
                if m.get(x, y, 1) == 0:
                    m.set(x, y, 1, WATER)
    for y in range(T):
        top = step_top(y)
        for x in (6, 25):
            m.set(x, y, top + 6, "metaal_donker")
            if y % 6 == 0:
                for z in range(top, top + 6):
                    m.set(x, y, z, "metaal_donker")
    return m


register("grond/waterkant/kadetrap", quay_stairs)


@tile("grond/waterkant/aanlegplaats")
def mooring():
    """Water tile with a wooden jetty along the back (y>=24) and three mooring posts."""
    m = water_tile()
    for y in range(T):
        for x in range(T):
            if y >= 24:
                for z in range(0, WALK):
                    m.set(x, y, z, "hout1" if z == WALK - 1 else "hout_donker2")
    for x in (2, 14, 26):
        for z in range(0, WALK + 4):
            m.set(x, 23, z, "hout_donker2")
    return m


# ------------------------------------------------------------------ playground and woodland

@tile("grond/natuur/speeltuin_rubber")
def playground_rubber():
    """Rubber playground tiles in 4x4 blocks (mostly green, some red and dark)."""
    def f(x, y, z):
        return pick(["paneel_groen", "paneel_rood", "beton_donker"], x // 4, y // 4, 0, 306, [3, 1, 1])
    return flat(f, top=WALK)


@tile("grond/natuur/speeltuin_zand")
def playground_sand():
    """Sandpit with a wooden border along all four edges."""
    m = flat(SAND, top=WALK)
    for y in range(T):
        for x in range(T):
            if x in (0, 31) or y in (0, 31):
                m.set(x, y, WALK, "hout2")
    return m


@tile("grond/natuur/bos")
def woods():
    """Forest floor: tall grass mixed with earth and leaves, scattered fallen leaves."""
    m = grass_tile(base=mix("gras5", "gras3", "aarde2", "blad5", seed=307))
    for y in range(T):
        for x in range(T):
            r = h(x, y, 0, 308)
            if r < 0.06:
                m.set(x, y, WALK - 1, "blad3")
            elif r < 0.09:
                m.set(x, y, WALK - 1, "herfst2")
    return m


@tile("grond/natuur/bosrand")
def forest_edge():
    """Grass blending into forest floor towards the back (+y)."""
    m = grass_tile()
    for y in range(16, T):
        for x in range(T):
            if h(x, y, 0, 309) < 0.3 + (y - 16) * 0.03:
                m.set(x, y, WALK - 1, pick(["gras5", "aarde2", "blad5"], x, y, 0, 310))
    return m


@tile("grond/natuur/heide")
def heath():
    """Heathland: dry grass with patches of purple heather."""
    m = grass_tile(base=mix("gras_droog", "gras5", "bloem_paars", seed=311, weights=[3, 2, 2]))
    for y in range(T):
        for x in range(T):
            if h(x, y, 0, 312) < 0.25:
                m.set(x, y, WALK - 1, pick(["bloem_paars", "gras5"], x, y, 1, 313))
    return m


# ------------------------------------------------------------------ rail: switch and extras

@tile("grond/spoor/trein_wissel")
def train_switch():
    """Railway switch: straight track plus a diverging branch on a large arc (r=80)
    starting from the same point, with a switch lever at x=30."""
    m = new()
    grass_floor(m, T)
    track_straight(m)
    # diverging branch: two rails 5.5 voxels either side of the arc's centre line
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16 + 80, 0)
            dd = abs(d - 80)
            if abs(dd - 5.5) < 0.55:
                m.set(x, y, 4, "rail_glim")
                m.set(x, y, 3, "rail")
    for y in range(20, T):
        m.set(30, y, 4, "metaal2")
    return m


@tile("grond/spoor/trein_overweg_fiets")
def train_level_crossing_bike():
    """Level crossing with the road surface replaced by bike-path asphalt
    (rails, rail grooves, rubber and markings are kept)."""
    m = train_level_crossing()
    keep = (P["rail_glim"], P["railgroef"], P["rubber"], P["markering"])
    for y in range(T):
        for x in range(T):
            t = m.top(x, y)
            if t and m.get(x, y, t - 1) not in keep:
                m.set(x, y, t - 1, BIKE_ASPHALT)
    return m


@tile("grond/spoor/trein_bovenleiding_recht")
def train_catenary():
    """Straight track with an overhead contact wire at z=50 and hangers every 8 voxels."""
    out = V(T, T, 56)
    out.paste(train_straight(), 0, 0, 0)
    for y in range(T):
        out.set(16, y, 50, "metaal1")
        if y % 8 == 0:
            for z in range(46, 50):
                out.set(16, y, z, "metaal2")
    return out


@tile("grond/spoor/tram_gras_kruising_weg")
def tram_road_crossing():
    """Tram rails in asphalt with striped crossing borders at the front and back edges."""
    m = flat()
    tram_rails_straight(m)
    for y in (0, 1, 30, 31):
        for x in range(T):
            paint(m, x, y, P["markering"] if (x // 3) % 2 else P["asfalt4"])
    return m


# ------------------------------------------------------------------ driveways and speed bumps

@tile("grond/stoep/stoep_inrit_breed")
def sidewalk_entrance_wide():
    """Sidewalk with a full-width lowered driveway along the front (y=0..5)."""
    m = sidewalk("v")
    for x in range(T):
        for y in range(0, 6):
            m.clear(x, y, ROAD, x + 1, y + 1, WALK + 1)
            top = ROAD + (1 if y >= 3 else 0)
            column(m, x, y, top, CURB if y == 0 else paver_fn, CURB)
    return m


@tile("grond/weg/uitritconstructie")
def exit_crossing():
    """Exit construction: the sidewalk continues across the side street; cars drive up via
    sloped curbs at the front and back."""
    m = new()
    for y in range(T):
        for x in range(T):
            if y < 3 or y > 28:
                column(m, x, y, ROAD + (1 if y in (2, 29) else 0), CURB, CURB)
            else:
                column(m, x, y, WALK, PAVING)
    return m


@tile("grond/weg/drempel_plateau")
def speed_bump_plateau():
    """Speed table: asphalt ramps up to a paved plateau, with dashed markings on the ramps."""
    m = new()
    for y in range(T):
        lift = min(2, min(y, 31 - y) // 3)
        for x in range(T):
            column(m, x, y, ROAD + lift, paver_fn if lift == 2 else ASPHALT)
    for x in range(T):
        if (x // 4) % 2 == 0:
            for y in (3, 4, 27, 28):
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/drempel_punaise")
def speed_bump_dome():
    """Round 'drawing-pin' speed bump: paved dome with a marked rim."""
    m = flat()
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            if d < 9:
                column(m, x, y, ROAD + (2 if d < 5 else 1), paver_fn if d < 8 else MARK)
    return m


@tile("grond/weg/drempel_bus")
def speed_bump_bus():
    """Two speed cushions with room for buses to straddle them."""
    m = flat()
    for x0 in (2, 20):
        for y in range(8, 24):
            for x in range(x0, x0 + 10):
                edge = y in (8, 23) or x in (x0, x0 + 9)
                column(m, x, y, ROAD + (1 if edge else 2), MARK if edge and y in (8, 23) else ASPHALT)
    return m


@tile("grond/weg/drempel_asfalt")
def speed_bump_asphalt():
    """Full-width asphalt speed bump (y=10..21) with dashed edge markings."""
    m = flat()
    for y in range(10, 22):
        lift = 2 if 13 <= y < 19 else 1
        for x in range(T):
            column(m, x, y, ROAD + lift, ASPHALT)
    for x in range(T):
        for y in (10, 21):
            if (x // 2) % 2:
                paint(m, x, y, MARK)
    return m


# ------------------------------------------------------------------ bus and bike lanes

@tile("grond/weg/busbaan_vrij")
def bus_lane_separate():
    """Dedicated bus lane with "BUS" painted on it."""
    m = flat(BUS)
    line_y(m, 31, dash=DASH)
    line_y(m, 1)
    stamp_text(m, "BUS", 6, 10)
    return m


@tile("grond/weg/busstrook_halte")
def bus_lane_stop():
    """Bus lane at a stop: block markings along the right edge."""
    m = flat(BUS)
    line_y(m, 0, dash=(4, 8, 0))
    for y in range(T):
        if (y // 4) % 2 == 0:
            paint(m, 30, y, MARK)
    return m


@tile("grond/weg/fietsstrook")
def bike_lane():
    """Road with a red cycle lane on the right (x>=18) behind a dashed line."""
    m = flat()
    for y in range(T):
        for x in range(18, T):
            paint(m, x, y, BIKE_ASPHALT)
        if y % 8 < 4:
            paint(m, 17, y, MARK)
    return m


@tile("grond/weg/fietsstraat")
def bike_street():
    """Bicycle street: red asphalt with a grey centre strip ('cars are guests')."""
    m = flat(BIKE_ASPHALT)
    for y in range(T):
        for x in range(12, 20):
            paint(m, x, y, ASPHALT)
        if y % 8 < 4:
            paint(m, 1, y, MARK)
            paint(m, 30, y, MARK)
    return m


# mirrored variants (retaining wall on the right) for tunnels and access ramps
def _mirrored(make, *args, **kwargs):
    """Build `make(*args, **kwargs)` and mirror it along x."""
    return make(*args, **kwargs).mirror_x()


register("grond/tunnel/tunnel_rijstrook_wand_rechts", partial(_mirrored, tunnel, True))
register("grond/tunnel/tunnel_rijstrook_wand_rechts_portaal", partial(_mirrored, tunnel, True, portal=True))
for _d in range(1, 7):
    register(f"grond/tunnel/tunnel_toerit_wand_rechts_d{_d}", partial(_mirrored, access_ramp, _d))
    smooth(f"grond/tunnel/tunnel_toerit_wand_rechts_d{_d}", "steil", keep_x=(30, 31))


@tile("grond/parkeren/parkeerstrook_langs")
def parking_lane_parallel():
    """Parallel parking along the carriageway: 4 m bays with a T-marking."""
    m = flat()
    for y in range(T):
        if y % 8 < 4:
            paint(m, 31, y, MARK)
    for x in range(20, T):
        paint(m, x, 0, MARK)
    return m


@tile("grond/parkeren/parkeerstrook_langs_klinkers")
def parking_lane_parallel_pavers():
    """Paver version of the parallel parking lane (marking row at the front, x>18)."""
    def f(x, y, z):
        return P["markering2"] if (y == 0 and x > 18) else paver_fn(x, y, z)
    return flat(f)
