"""Tiles of the tram tunnel under the Grote Marktstraat (tunnel sections, ramps, platforms
and the street entrance), the curve that joins the viaduct to the tram network on a paved
square, the footbridge decks with an opening for side stairs and an open train deck."""
from common import T, FLOOR, WALK, ROAD, register, tile, smooth, text_pixels
from palette import P
from vox import V
from .ground import deck_from, _train_deck_base, flat, padded, paver_fn, tram_rails_arc, tram_rails_straight, ASPHALT, CONCRETE, CONCRETE_DARK, PAVING, CURB, RAIL_X
from .ground_extra import tunnel, CEIL, TH
from .extras_business_paths import walkway


def _set_tunnel_rails(m):
    """Lays rails in the road surface of a tunnel tile. Unlike paint() this does not follow
    the top of the column, which is the roof here."""
    for y in range(T):
        for rail in RAIL_X:
            groove = rail + 1 if rail == RAIL_X[0] else rail - 1
            m.set(rail, y, ROAD - 1, P["rail_glim"])
            m.set(groove, y, ROAD - 1, P["railgroef"])


def tram_tunnel(wall=True):
    """Tram tunnel section running along y (place on layer -6): a tunnel without lane
    markings, with rails. wall: retaining wall on the left."""
    m = tunnel(wall, line=False)
    _set_tunnel_rails(m)
    return m


def tram_tunnel_portal(word, wall_on_right):
    """Tunnel section with the entrance beam at the front and `word` on it. Added after
    mirroring, so the word on the tile with its wall on the right reads the right way:
    the two tiles side by side read TRAM TUNNEL."""
    m = tram_tunnel().mirror_x() if wall_on_right else tram_tunnel()
    for x in range(T):
        for z in range(36, TH):
            m.set(x, 0, z, "beton_donker" if z in (36, TH - 1) else CONCRETE)
            m.set(x, 1, z, CONCRETE)
    pixels, (text_width, _) = text_pixels(word)
    centre = 12 if wall_on_right else 20
    for (column_index, row_index) in pixels:
        m.set(centre - text_width // 2 + column_index, 0, 44 - row_index, "bord_wit")
    return m


register("grond/tunnel/tramtunnel_wand", lambda: tram_tunnel())
register("grond/tunnel/tramtunnel_wand_rechts", lambda: tram_tunnel().mirror_x())
register("grond/tunnel/tramtunnel_wand_portaal", lambda: tram_tunnel_portal("TRAM", False))
register("grond/tunnel/tramtunnel_wand_rechts_portaal", lambda: tram_tunnel_portal("TUNNEL", True))
register("grond/tunnel/tramtunnel_kaal", lambda: tram_tunnel(wall=False))


def tram_tunnel_ramp(depth):
    """Tram ramp on layer -depth rising one layer towards the back (+y), with a retaining
    wall and railing on the left up to street level; smoothed by the importer."""
    base = flat(ASPHALT)
    tram_rails_straight(base)
    ramp = padded(base)
    out = V(T, T, depth * FLOOR + 8)
    out.paste(ramp, 0, 0, 0)
    top = depth * FLOOR + WALK
    for y in range(T):
        for z in range(0, top):
            out.set(0, y, z, CONCRETE_DARK if z % 12 == 0 else CONCRETE)
            out.set(1, y, z, CONCRETE)
        for z in range(top, top + 6):
            out.set(0, y, z, "metaal_donker" if (z == top + 5 or y % 8 == 0) else 0)
    return out


for _depth in range(1, 7):
    register(f"grond/tunnel/tramtunnel_toerit_wand_d{_depth}", (lambda depth: lambda: tram_tunnel_ramp(depth))(_depth))
    register(f"grond/tunnel/tramtunnel_toerit_wand_rechts_d{_depth}", (lambda depth: lambda: tram_tunnel_ramp(depth).mirror_x())(_depth))
    smooth(f"grond/tunnel/tramtunnel_toerit_wand_d{_depth}", "steil", keep_x=(0, 1))
    smooth(f"grond/tunnel/tramtunnel_toerit_wand_rechts_d{_depth}", "steil", keep_x=(30, 31))


@tile("grond/tunnel/tramtunnel_perron")
def tram_tunnel_platform():
    """Underground platform beside a tram tunnel (layer -6): tiled wall on the left, the
    platform with a white edge line and tactile strip towards the track on the right."""
    m = tunnel(True, line=False)
    platform_top = 5
    for y in range(T):
        for x in range(2, T):
            for z in range(0, platform_top):
                m.set(x, y, z, PAVING if z == platform_top - 1 else CONCRETE_DARK)
        for z in range(0, platform_top):
            m.set(T - 1, y, z, CURB)
        m.set(T - 3, y, platform_top - 1, P["markering"])
        for x in range(T - 7, T - 4):
            m.set(x, y, platform_top - 1, P["ribbel"] if y % 2 == 0 else P["tegel3"])
    # a bench and a lit sign on the wall every other cell length
    for y in range(8, 24):
        for z in range(platform_top, platform_top + 4):
            m.set(3, y, z, "metaal_donker")
    for y in range(10, 22):
        for z in range(18, 24):
            m.set(2, y, z, "bord_blauw")
    return m


def _platform_with_end_wall(wall_y):
    """Platform tile closed by a wall across it at row wall_y (0: front, T - 1: back)."""
    m = tram_tunnel_platform()
    rows = (0, 1) if wall_y == 0 else (T - 2, T - 1)
    for y in rows:
        for x in range(T):
            for z in range(0, CEIL):
                m.set(x, y, z, CONCRETE if y == wall_y else P["tegel3"])
    return m


register("grond/tunnel/tramtunnel_perron_begin", lambda: _platform_with_end_wall(0))
register("grond/tunnel/tramtunnel_perron_eind", lambda: _platform_with_end_wall(T - 1))


@tile("grond/tram/tram_klinker_bocht")
def tram_pavers_curve():
    """Tram curve (radius 16) around the front-right corner in a clinker square."""
    m = flat(paver_fn)
    tram_rails_arc(m, 32, 0, 16, T)
    return m


@tile("props/ov/tramtunnel_ingang")
def tram_tunnel_entrance():
    """Street entrance of an underground tram stop, 4 x 2 m: a low concrete surround round
    a dark stairwell (open at the front), under a glass canopy with a blue TRAM sign."""
    m = V(32, 16, 28)
    for x in range(32):
        for y in range(16):
            edge = x < 2 or x > 29 or y > 13
            if edge:
                for z in range(0, 8):
                    m.set(x, y, z, CONCRETE)
            else:
                # steps seen going down: darker towards the back; two voxels thick, so they
                # lie above the paving the prop stands on
                step_colour = "interieur3" if y > 8 else ("interieur1" if y % 3 else "beton_donker")
                m.set(x, y, 0, step_colour)
                m.set(x, y, 1, step_colour)
    for x, y in ((1, 1), (30, 1), (1, 14), (30, 14)):
        for z in range(8, 22):
            m.set(x, y, z, "metaal_donker")
    for x in range(32):
        for y in range(16):
            m.set(x, y, 22, "metaal_donker" if x in (0, 31) or y in (0, 15) else "glas_helder")
    for x in range(8, 24):
        for z in range(23, 28):
            m.set(x, 0, z, "bord_blauw")
    pixels, (text_width, _) = text_pixels("TRAM")
    for (column_index, row_index) in pixels:
        m.set(16 - text_width // 2 + column_index, 0, 27 - row_index if 27 - row_index >= 23 else 23, "bord_wit")
    return m


def side_entry_deck():
    """Open footbridge deck with an opening in the left balustrade for stairs coming up
    from the side, closed at the front end of the bridge."""
    m = walkway(False)
    for y in range(8, 24):
        for z in range(2, 10):
            m.set(6, y, z, 0)
    for x in range(6, 26):
        for z in range(2, 9):
            m.set(x, 0, z, "glas_helder")
        m.set(x, 0, 9, "rvs")
    return m


register("grond/brug/loopbrug_open_zijtoegang", lambda: side_entry_deck())
register("grond/brug/loopbrug_open_zijtoegang_rechts", lambda: side_entry_deck().mirror_x())


@tile("grond/brug/brug_dek_trein_kaal")
def train_deck_open():
    """Train bridge deck without parapets, along a platform of an elevated station."""
    return deck_from(_train_deck_base(), "geen")
