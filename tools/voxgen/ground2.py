"""Uitbreiding grond: tunnels, zwembaden, waterkanten, extra markeringen, parkeren,
flauwe hellingen, middengeleiders, speeltuin- en bos-ondergrond, wissels."""
import math

from common import T, ROAD, WALK, FLOOR, tile, register, text_pixels
from palette import P
from vox import V, mix, pick, h, blocky
from ground import (new, column, flat, paint, line_y, line_x, paint_bitmap, rijstrook, stoep, gras_tile, water_tile,
                    shear, klinker_fn, track_straight, grass_floor, ASFALT, FIETS, MARK, TEGEL, BAND, GOOT, GRAS, AARDE,
                    ZAND, GRIND, BETON, BETON_D, NATUURSTEEN, WATER, DASH, fietspad_recht, weg_vlak, straat_klinkers,
                    plein_tegels, gras, stoep as stoep_fn, dist, baksteen_fn, RAIL_X)

TEGEL_WIT = mix("tegel_wit", "stuc2", seed=300, weights=[5, 1])

# ------------------------------------------------------------------ markeringen

@tile("grond/weg/rijstrook_stop_tekst")
def stop_tekst():
    m = rijstrook("streep", "kant")
    for y in range(27, 30):
        line_x(m, y, 0, 31)
    px, (tw, th) = text_pixels("STOP")
    for (c, r) in px:
        for sy in range(2):
            paint(m, 1 + c * 2 // 1 if False else 1 + c * 2, 12 + (4 - r) * 2 + sy, MARK)
            paint(m, 2 + c * 2, 12 + (4 - r) * 2 + sy, MARK)
    return m


@tile("grond/weg/pianostrepen")
def pianostrepen():
    m = flat()
    for y in range(T):
        for x in range(4, 28):
            if (y // 2) % 2 == 0:
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/kruis_markering")
def kruis_markering():
    m = flat()
    for i in range(4, 28):
        for k in (0, 1):
            paint(m, i + k, i, P["markering_geel"])
            paint(m, 31 - i - k, i, P["markering_geel"])
    return m


@tile("grond/weg/straat_eenrichting")
def straat_eenrichting():
    m = flat()
    from ground import arrow
    arrow(m, "rechtdoor")
    return m


def kruising(kind):
    """Kruispunt-tile (1 tile = hele kruising van smalle straten) met markering."""
    m = flat()
    if kind in ("stop", "haaientanden"):
        for side in range(4):
            for i in range(4, 28):
                for k in range(2):
                    if kind == "stop":
                        x, y = i, 1 + k
                    else:
                        if (i // 3) % 2:
                            continue
                        x, y = i, 1 + k
                    for _ in range(side):
                        x, y = 31 - y, x
                    paint(m, x, y, MARK)
    return m


register("grond/weg/kruising_stop", lambda: kruising("stop"))
register("grond/weg/kruising_haaientanden", lambda: kruising("haaientanden"))
register("grond/weg/kruising_vlak", lambda: kruising("vlak"))


@tile("grond/weg/rijstrook_doorgetrokken_dubbel")
def doorgetrokken_dubbel():
    m = rijstrook("dubbel", "kant")
    return m


@tile("grond/weg/middengeleider")
def middengeleider():
    """Rijstrook met verhoogde middengeleider (0,5 m) langs de linkerkant."""
    m = rijstrook("geen", "kant")
    for y in range(T):
        for x in range(0, 4):
            column(m, x, y, WALK + 1, BAND if x in (0, 3) else GRAS, BAND)
    for y in range(T):
        if y % 16 == 4:
            for z in range(WALK + 1, WALK + 6):
                m.set(1, y, z, "bord_wit")
            m.set(1, y, WALK + 5, "bord_blauw")
    return m


@tile("grond/weg/middengeleider_breed")
def middengeleider_breed():
    m = new()
    for y in range(T):
        for x in range(T):
            if 10 <= x < 22:
                column(m, x, y, WALK + 1, BAND if x in (10, 21) else GRAS, BAND)
            else:
                column(m, x, y, ROAD, ASFALT)
    line_y(m, 8)
    line_y(m, 23)
    return m


@tile("grond/weg/middengeleider_kop")
def middengeleider_kop():
    m = flat()
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            if 10 <= x < 22 and (y >= 16 or d < 6):
                column(m, x, y, WALK + 1, BAND if (x in (10, 21) or (y < 16 and d > 5)) else GRAS, BAND)
    for y in range(4, 10):
        for x in range(T):
            if (x + y) % 6 < 2 and 6 <= x < 26:
                paint(m, x, y, MARK)
    return m


# ------------------------------------------------------------------ parkeren

@tile("grond/parkeren/parkeervak_haaks")
def parkeervak_haaks():
    m = flat()
    for y in range(4, T):
        paint(m, 0, y, MARK)
    for x in range(T):
        paint(m, x, 4, MARK)
    return m


@tile("grond/parkeren/parkeervak_haaks_eind")
def parkeervak_haaks_eind():
    m = parkeervak_haaks()
    for y in range(4, T):
        paint(m, 31, y, MARK)
    return m


@tile("grond/parkeren/parkeervak_laadpaal")
def parkeervak_laadpaal():
    m = parkeervak_haaks()
    for y in range(8, 28):
        for x in range(4, 28):
            paint(m, x, y, P["bord_groen"])
    paint_bitmap(m, ["###", "#..", "##.", "#..", "###"], 13, 13, MARK, scale=2)
    return m


@tile("grond/parkeren/parkeervak_schuin")
def parkeervak_schuin():
    m = flat()
    for y in range(T):
        x = (y + 4) % 16
        paint(m, x, y, MARK)
        paint(m, x + 16, y, MARK)
    for x in range(T):
        paint(m, x, 0, MARK)
    return m


@tile("grond/parkeren/parkeervak_klinkers")
def parkeervak_klinkers():
    def f(x, y, z):
        return P["markering2"] if x == 0 else klinker_fn(x, y, z)
    return flat(f)


@tile("grond/parkeren/parkeerplaats_rijbaan")
def parkeerplaats_rijbaan():
    m = flat()
    from ground import arrow
    arrow(m, "rechtdoor", 16, 6)
    return m


# ------------------------------------------------------------------ flauwe hellingen (0,5 m per tile)

FLAUW_A = lambda x, y: y // 8
FLAUW_B = lambda x, y: 4 + y // 8

_bron = {
    "weg_vlak": weg_vlak,
    "rijstrook_onderbroken_kant": lambda: rijstrook("onderbroken", "kant"),
    "rijstrook_geen_kant": lambda: rijstrook("geen", "kant"),
    "fietspad_recht": fietspad_recht,
    "stoep_vol": lambda: stoep(""),
    "stoep_rand": lambda: stoep("v"),
    "stoep_goot_rand": lambda: stoep("v", goot=True),
    "straat_klinkers": straat_klinkers,
    "plein_tegels": plein_tegels,
    "gras": gras,
}
for _n, _f in _bron.items():
    register(f"grond/helling/flauw_{_n}_a", (lambda f: lambda: shear(f(), FLAUW_A))(_f))
    register(f"grond/helling/flauw_{_n}_b", (lambda f: lambda: shear(f(), FLAUW_B))(_f))

# extra steile hellingen voor stoep-hoeken en fietspad naast de weg
register("grond/helling/helling_stoep_hoek_buiten", lambda: shear(stoep("vr"), lambda x, y: y // 4))
register("grond/helling/helling_fietspad_eenrichting", lambda: shear(__import__("ground").fietspad_eenrichting(), lambda x, y: y // 4))


@tile("grond/terrein/trap_1m_fietsgoot")
def trap_fietsgoot():
    from ground import trap_1m
    m = trap_1m()
    for y in range(8, 24):
        top = WALK + 1 + (y - 8) // 2
        for x in (4, 5):
            for z in range(top - 1, top + 2):
                m.set(x, y, z, 0)
            m.set(x, y, top - 1, "metaal2")
    return m


@tile("grond/terrein/trap_1m_breed")
def trap_1m_breed():
    m = V(T, T, FLOOR + 8)
    for y in range(T):
        if y < 8:
            top = WALK
        elif y < 24:
            top = WALK + 1 + (y - 8) // 2
        else:
            top = WALK + FLOOR
        for x in range(T):
            column(m, x, y, top, NATUURSTEEN if 8 <= y < 24 else TEGEL, BETON_D)
    return m


# ------------------------------------------------------------------ tunnels

TH = 48  # 6 grond-lagen: plaats tunnel-tiles op laag -6, dak komt op straatniveau


def tunnel(wall=True, line=True, portaal=False, fiets=False):
    m = V(T, T, TH)
    for y in range(T):
        for x in range(T):
            column(m, x, y, ROAD, FIETS if fiets else ASFALT, BETON_D)
            for z in range(40, TH):
                m.set(x, y, z, BETON if z < TH - 1 else "beton_donker")
    if line and not fiets:
        line_y(m, 31, dash=DASH)
        line_y(m, 2)
    if wall:
        for y in range(T):
            for z in range(0, 40):
                for x in (0, 1):
                    m.set(x, y, z, BETON_D if x == 0 else (TEGEL_WIT if 3 <= z < 30 else BETON))
                if 3 <= z < 30 and y % 16 == 0:
                    m.set(1, y, z, "bord_groen" if z == 12 else ("tegel_wit" if z % 2 else "stuc2"))
            m.set(2, y, ROAD, BAND)
            m.set(2, y, ROAD + 1, BAND)
    for y in range(T):
        if y % 4 < 3:
            m.set(16 if not wall else 10, y, 39, "lamp_wit")
            m.set(16 if not wall else 22, y, 39, "lamp_wit")
    if portaal:
        for x in range(T):
            for z in range(36, TH):
                m.set(x, 0, z, "beton_donker" if z in (36, TH - 1) else BETON)
                m.set(x, 1, z, BETON)
        px, (tw, th) = text_pixels("TUNNEL")
        for (c, r) in px:
            m.set(16 - tw // 2 + c, 0, 44 - r, "bord_wit") if not wall else m.set(20 - tw // 2 + c, 0, 44 - r, "bord_wit")
    return m


register("grond/tunnel/tunnel_rijstrook_wand", lambda: tunnel(True))
register("grond/tunnel/tunnel_rijstrook", lambda: tunnel(False))
register("grond/tunnel/tunnel_rijstrook_wand_portaal", lambda: tunnel(True, portaal=True))
register("grond/tunnel/tunnel_rijstrook_portaal", lambda: tunnel(False, portaal=True))
register("grond/tunnel/tunnel_fiets_wand", lambda: tunnel(True, fiets=True))
register("grond/tunnel/tunnel_fiets_wand_portaal", lambda: tunnel(True, fiets=True, portaal=True))


@tile("grond/tunnel/tunnel_middenwand")
def tunnel_middenwand():
    m = tunnel(False, line=False)
    for y in range(T):
        for z in range(0, 40):
            for x in (15, 16):
                m.set(x, y, z, BETON)
        if y % 8 == 2:
            for z in range(4, 10):
                m.set(15, y, z, 0)
                m.set(16, y, z, 0)
    return m


def toerit(depth, wall=True, fiets=False):
    """Toerit naar een tunnel: helling op laag -depth (stijgt 1 laag naar achteren),
    met keerwand tot straatniveau."""
    base = flat(FIETS if fiets else ASFALT)
    if not fiets:
        line_y(base, 31, dash=DASH)
        line_y(base, 2)
    m = shear(base, lambda x, y: y // 4)
    if wall:
        out = V(T, T, depth * FLOOR + 8)
        out.paste(m, 0, 0, 0)
        top = depth * FLOOR + WALK
        for y in range(T):
            o = y // 4
            for z in range(0, top):
                out.set(0, y, z, BETON_D if (z % 12 == 0) else BETON)
                out.set(1, y, z, BETON)
            for z in range(top, top + 6):
                out.set(0, y, z, "metaal_donker" if (z == top + 5 or y % 8 == 0) else 0)
        return out
    return m


for _d in range(1, 7):
    register(f"grond/tunnel/tunnel_toerit_wand_d{_d}", (lambda d: lambda: toerit(d))(_d))
    register(f"grond/tunnel/tunnel_toerit_d{_d}", (lambda d: lambda: toerit(d, False))(_d))
for _d in range(1, 7):
    register(f"grond/tunnel/fietstunnel_toerit_wand_d{_d}", (lambda d: lambda: toerit(d, True, True))(_d))


# ------------------------------------------------------------------ zwembad buiten (plaats op laag -1)

PH = FLOOR + WALK  # 11: rand komt op stoepniveau van laag 0
ZWEMWATER = mix("water_zwembad", "water_zwembad", "water3", seed=301, weights=[3, 3, 1])


def zwembad(edges="", trap=False):
    m = V(T, T, PH + 1)
    for y in range(T):
        for x in range(T):
            ds = []
            if "v" in edges: ds.append(y)
            if "a" in edges: ds.append(31 - y)
            if "l" in edges: ds.append(x)
            if "r" in edges: ds.append(31 - x)
            d = min(ds) if ds else 99
            if d < 3:
                for z in range(PH):
                    m.set(x, y, z, "natuursteen1" if z == PH - 1 else "tegel_wit")
            else:
                m.set(x, y, 0, "paneel_blauw" if (x + y) % 8 else "tegel_wit")
                m.set(x, y, 1, "paneel_blauw" if (x // 4 + y // 4) % 2 else "glas_lood_blauw" if False else "tegel_wit")
                for z in range(2, PH - 2):
                    m.set(x, y, z, ZWEMWATER)
            if d == 3:
                for z in range(2, PH - 2):
                    m.set(x, y, z, ZWEMWATER)
    if trap and "v" in edges:
        for i in range(5):
            for x in range(10, 22):
                for z in range(0, PH - 2 - i * 2):
                    if z < 2 or True:
                        m.set(x, 3 + i, z, "tegel_wit" if z < PH - 3 - i * 2 else "natuursteen1")
    return m


register("grond/zwembad/zwembad_midden", lambda: zwembad(""))
register("grond/zwembad/zwembad_rand", lambda: zwembad("v"))
register("grond/zwembad/zwembad_hoek", lambda: zwembad("vr"))
register("grond/zwembad/zwembad_rand_trap", lambda: zwembad("v", trap=True))
register("grond/zwembad/zwembad_eind", lambda: zwembad("var"))


@tile("grond/zwembad/zwembad_kant_tegels")
def zwembad_kant():
    def f(x, y, z):
        return P["tegel_wit"] if (x // 4 + y // 4) % 2 else P["stuc2"]
    return flat(f, top=WALK)


@tile("grond/zwembad/kinderbad")
def kinderbad():
    m = V(T, T, 6)
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            column(m, x, y, WALK, TEGEL_WIT)
            if d < 13:
                m.set(x, y, WALK - 1, "paneel_blauw")
                m.set(x, y, WALK, ZWEMWATER)
            elif d < 15:
                m.set(x, y, WALK, "natuursteen1")
    return m


# ------------------------------------------------------------------ waterkant

@tile("grond/waterkant/strand")
def strand():
    m = new(8)
    for y in range(T):
        for x in range(T):
            if y < 12:
                m.set(x, y, 0, "zand2")
                m.set(x, y, 1, WATER)
            elif y < 20:
                column(m, x, y, ROAD, ZAND)
            else:
                column(m, x, y, WALK, ZAND)
                if h(x, y, 0, 302) < 0.02:
                    m.set(x, y, WALK, "grind3")
    return m


@tile("grond/waterkant/strand_hoek")
def strand_hoek():
    m = new(8)
    for y in range(T):
        for x in range(T):
            d = min(y, 31 - x)
            if d < 12:
                m.set(x, y, 0, "zand2")
                m.set(x, y, 1, WATER)
            elif d < 20:
                column(m, x, y, ROAD, ZAND)
            else:
                column(m, x, y, WALK, ZAND)
    return m


@tile("grond/waterkant/beschoeiing")
def beschoeiing():
    m = new(8)
    for y in range(T):
        for x in range(T):
            if y < 14:
                m.set(x, y, 0, "waterbodem")
                m.set(x, y, 1, WATER)
            elif y < 16:
                for z in range(0, WALK + 1):
                    m.set(x, y, z, "hout_donker2" if x % 4 else "hout_donker1")
            else:
                column(m, x, y, WALK, GRAS)
    return m


@tile("grond/waterkant/basalt_talud")
def basalt_talud():
    m = new(8)
    for y in range(T):
        for x in range(T):
            if y < 10:
                m.set(x, y, 0, "waterbodem")
                m.set(x, y, 1, WATER)
            elif y < 24:
                top = 1 + (y - 10) // 4
                column(m, x, y, top, pick(["antraciet3", "antraciet1", "alg2"], x // 2, y // 2, 0, 303, [3, 2, 1]), "antraciet3")
            else:
                column(m, x, y, WALK + 2, GRAS)
    return m


@tile("grond/waterkant/boulevard")
def boulevard():
    m = new(10)
    for y in range(T):
        for x in range(T):
            if y < 8:
                m.set(x, y, 0, "waterbodem")
                m.set(x, y, 1, WATER)
            elif y < 10:
                for z in range(0, WALK + 4):
                    m.set(x, y, z, BETON)
            else:
                column(m, x, y, WALK, blocky(["plein1", "plein2", "plein_rood"], size=4, seed=304))
        if x % 8 == 0:
            pass
    return m


def kadetrap(rails):
    """Trap van de kade (laag 0) naar het water (laag -2). Plaats op laag -2."""
    H = FLOOR * 2 + WALK
    m = V(T, T, H + 8)
    for y in range(T):
        top = 2 + int(y * (H - 2) / 31.0)
        for x in range(T):
            if 6 <= x < 26:
                for z in range(0, top):
                    m.set(x, y, z, NATUURSTEEN if z >= top - 1 else "natuursteen3")
            else:
                for z in range(0, H):
                    m.set(x, y, z, lambda a, b, c: baksteen_fn(a, b, c, 305))
        if y < 2:
            for x in range(T):
                if m.get(x, y, 1) == 0:
                    m.set(x, y, 1, WATER)
    for y in range(T):
        top = 2 + int(y * (H - 2) / 31.0)
        for x in (6, 25):
            m.set(x, y, top + 6, "metaal_donker")
            if y % 6 == 0:
                for z in range(top, top + 6):
                    m.set(x, y, z, "metaal_donker")
    return m


register("grond/waterkant/kadetrap", lambda: kadetrap(True))


@tile("grond/waterkant/aanlegplaats")
def aanlegplaats():
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


# ------------------------------------------------------------------ speeltuin en bos

@tile("grond/natuur/speeltuin_rubber")
def speeltuin_rubber():
    def f(x, y, z):
        return pick(["paneel_groen", "paneel_rood", "beton_donker"], x // 4, y // 4, 0, 306, [3, 1, 1])
    return flat(f, top=WALK)


@tile("grond/natuur/speeltuin_zand")
def speeltuin_zand():
    m = flat(ZAND, top=WALK)
    for y in range(T):
        for x in range(T):
            if x in (0, 31) or y in (0, 31):
                m.set(x, y, WALK, "hout2")
    return m


@tile("grond/natuur/bos")
def bos():
    m = gras_tile(tufts=0.25, tall=True, base=mix("gras5", "gras3", "aarde2", "blad5", seed=307))
    for y in range(T):
        for x in range(T):
            r = h(x, y, 0, 308)
            if r < 0.04:
                m.set(x, y, WALK, "blad3")
                m.set(x, y, WALK + 1, "varen" if False else "blad4")
            elif r < 0.07:
                m.set(x, y, WALK, "herfst2")
    return m


@tile("grond/natuur/bosrand")
def bosrand():
    m = gras_tile(tufts=0.15, tall=True)
    for y in range(16, T):
        for x in range(T):
            if h(x, y, 0, 309) < 0.3 + (y - 16) * 0.03:
                m.set(x, y, WALK - 1, pick(["gras5", "aarde2", "blad5"], x, y, 0, 310))
    return m


@tile("grond/natuur/heide")
def heide():
    m = gras_tile(tufts=0.0, base=mix("gras_droog", "gras5", "bloem_paars", seed=311, weights=[3, 2, 2]))
    for y in range(T):
        for x in range(T):
            if h(x, y, 0, 312) < 0.25:
                m.set(x, y, WALK, pick(["bloem_paars", "gras5"], x, y, 1, 313))
    return m


# ------------------------------------------------------------------ spoor: wissel en dubbel

@tile("grond/spoor/trein_wissel")
def trein_wissel():
    from ground import track_arc
    m = new()
    grass_floor(m, T)
    track_straight(m)
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 32 + 80, 0)
    # afbuigende tak: grote boog (r=80) vanaf hetzelfde beginpunt
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
def trein_overweg_fiets():
    from ground import trein_overweg
    m = trein_overweg()
    for y in range(T):
        for x in range(T):
            t = m.top(x, y)
            if t and m.get(x, y, t - 1) not in (P["rail_glim"], P["railgroef"], P["rubber"], P["markering"]):
                m.set(x, y, t - 1, FIETS)
    return m


@tile("grond/spoor/trein_bovenleiding_recht")
def trein_bovenleiding():
    from ground import trein_recht
    m = trein_recht()
    out = V(T, T, 56)
    out.paste(m, 0, 0, 0)
    for y in range(T):
        out.set(16, y, 50, "metaal1")
        if y % 8 == 0:
            for z in range(46, 50):
                out.set(16, y, z, "metaal2")
    return out


@tile("grond/spoor/tram_gras_kruising_weg")
def tram_kruising_weg():
    m = flat()
    from ground import tram_rails_straight
    tram_rails_straight(m)
    for y in (0, 1, 30, 31):
        for x in range(T):
            paint(m, x, y, P["markering"] if (x // 3) % 2 else P["asfalt4"])
    return m


# ------------------------------------------------------------------ in-/uitritten en drempels

@tile("grond/stoep/stoep_inrit_breed")
def stoep_inrit_breed():
    m = stoep("v")
    for x in range(T):
        for y in range(0, 6):
            m.clear(x, y, ROAD, x + 1, y + 1, WALK + 1)
            top = ROAD + (1 if y >= 3 else 0)
            column(m, x, y, top, BAND if y == 0 else klinker_fn, BAND)
    return m


@tile("grond/weg/uitritconstructie")
def uitritconstructie():
    """Stoep loopt door over de zijstraat; auto's rijden via schuine banden omhoog."""
    m = new()
    for y in range(T):
        for x in range(T):
            if y < 3 or y > 28:
                column(m, x, y, ROAD + (1 if y in (2, 29) else 0), BAND, BAND)
            else:
                column(m, x, y, WALK, TEGEL)
    return m


@tile("grond/weg/drempel_plateau")
def drempel_plateau():
    m = new()
    for y in range(T):
        lift = min(2, min(y, 31 - y) // 3)
        for x in range(T):
            column(m, x, y, ROAD + lift, klinker_fn if lift == 2 else ASFALT)
    for x in range(T):
        if (x // 4) % 2 == 0:
            for y in (3, 4, 27, 28):
                paint(m, x, y, MARK)
    return m


@tile("grond/weg/drempel_punaise")
def drempel_punaise():
    m = flat()
    for y in range(T):
        for x in range(T):
            d = dist(x, y, 16, 16)
            if d < 9:
                column(m, x, y, ROAD + (2 if d < 5 else 1), klinker_fn if d < 8 else MARK)
    return m


@tile("grond/weg/drempel_bus")
def drempel_bus():
    """Twee drempelkussens met ruimte voor bussen ertussen."""
    m = flat()
    for x0 in (2, 20):
        for y in range(8, 24):
            for x in range(x0, x0 + 10):
                edge = y in (8, 23) or x in (x0, x0 + 9)
                column(m, x, y, ROAD + (1 if edge else 2), MARK if edge and y in (8, 23) else ASFALT)
    return m


@tile("grond/weg/drempel_asfalt")
def drempel_asfalt():
    m = flat()
    for y in range(10, 22):
        lift = 2 if 13 <= y < 19 else 1
        for x in range(T):
            column(m, x, y, ROAD + lift, ASFALT)
    for x in range(T):
        for y in (10, 21):
            if (x // 2) % 2:
                paint(m, x, y, MARK)
    return m


# ------------------------------------------------------------------ bus- en fietsstroken

@tile("grond/weg/busbaan_vrij")
def busbaan_vrij():
    from ground import BUS
    m = flat(BUS)
    line_y(m, 31, dash=DASH)
    line_y(m, 1)
    px, (tw, th) = text_pixels("BUS")
    for (c, r) in px:
        for sy in range(2):
            for sx in range(2):
                paint(m, 6 + c * 2 + sx, 10 + (4 - r) * 2 + sy, MARK)
    return m


@tile("grond/weg/busstrook_halte")
def busstrook_halte():
    from ground import BUS
    m = flat(BUS)
    line_y(m, 0, dash=(4, 8, 0))
    for y in range(T):
        if (y // 4) % 2 == 0:
            paint(m, 30, y, MARK)
    return m


@tile("grond/weg/fietsstrook")
def fietsstrook():
    m = flat()
    for y in range(T):
        for x in range(18, T):
            paint(m, x, y, FIETS)
        if y % 8 < 4:
            paint(m, 17, y, MARK)
    return m


@tile("grond/weg/fietsstraat")
def fietsstraat():
    """Fietsstraat: rood asfalt, auto te gast."""
    m = flat(FIETS)
    for y in range(T):
        for x in range(12, 20):
            paint(m, x, y, ASFALT)
        if y % 8 < 4:
            paint(m, 1, y, MARK)
            paint(m, 30, y, MARK)
    return m


# gespiegelde varianten (keerwand aan de rechterkant) voor tunnels en toeritten
register("grond/tunnel/tunnel_rijstrook_wand_rechts", lambda: tunnel(True).mirror_x())
register("grond/tunnel/tunnel_rijstrook_wand_rechts_portaal", lambda: tunnel(True, portaal=True).mirror_x())
for _d in range(1, 7):
    register(f"grond/tunnel/tunnel_toerit_wand_rechts_d{_d}", (lambda d: lambda: toerit(d).mirror_x())(_d))


@tile("grond/parkeren/parkeerstrook_langs")
def parkeerstrook_langs():
    """Parkeren parallel aan de rijbaan: vakken van 4 m met T-markering."""
    m = flat()
    for y in range(T):
        if y % 8 < 4:
            paint(m, 31, y, MARK)
    for x in range(20, T):
        paint(m, x, 0, MARK)
    return m


@tile("grond/parkeren/parkeerstrook_langs_klinkers")
def parkeerstrook_langs_klinkers():
    def f(x, y, z):
        return P["markering2"] if (y == 0 and x > 18) else klinker_fn(x, y, z)
    return flat(f)
