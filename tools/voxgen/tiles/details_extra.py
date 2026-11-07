"""More facade and roof details (``details/...`` tiles), extending details.py.

Registers roof installations (cooling units, air handlers, vents), solar panels and a
solar water heater, a loose dormer, sun shading (awnings, roller shutters, screens),
facade lettering (``facade_text``, also used by building_campus), flags on wall poles for every
flag in props_extra.FLAGS, entrance steps for classic houses and garage door variants.

Facade parts are drawn on details.att() canvases with y = wd(m, d) (d = 0 against the
wall, front = y=0 side); roof parts use a plain V canvas. Sizes are in voxels of 12.5 cm,
z is up.
"""
import math

from common import register, tile, text_pixels, PICTO
from palette import lit_colour
from vox import V
from .details import att, att_box, wd, pole_flag, stripe, striped_cloth
from .props_extra import FLAGS


# ------------------------------------------------------------------ roof: installations and solar panels

@tile("details/dak/koelinstallatie")
def cooling_unit():
    """Rooftop cooling unit with six fans on top and a grille on the front."""
    m = V(24, 16, 10)
    m.box(0, 0, 0, 24, 16, 1, "metaal2")
    m.box(1, 1, 1, 23, 15, 7, "metaal1")
    for cx in (6, 12, 18):
        for cy in (5, 11):
            m.cyl(cx, cy, 2.6, 7, 8, "metaal_donker")
            m.set(cx, cy, 8, "metaal3")
            m.set(cx - 1, cy, 7, "rooster")
    for x in range(2, 23, 2):
        m.box(x, 0, 2, x + 1, 1, 6, "rooster")
    return m


@tile("details/dak/luchtbehandeling")
def air_handler():
    """Air-handling unit box with a vertical exhaust duct on the right side."""
    m = V(32, 12, 12)
    m.box(0, 2, 0, 28, 12, 9, "metaal1")
    m.box(0, 2, 9, 28, 12, 10, "metaal2")
    m.box(29, 7, 2, 30, 8, 7, "metaal3")
    m.cyl(30, 7, 2, 0, 11, "metaal3")
    for x in range(2, 26, 6):
        m.box(x, 1, 2, x + 4, 2, 7, "rooster")
    return m


@tile("details/dak/airco_buitenunit")
def ac_outdoor_unit():
    """Air-conditioning outdoor unit with a round fan grille on the front."""
    m = V(8, 6, 7)
    m.box(0, 1, 0, 8, 5, 6, "stuc1")
    for x in range(1, 7):
        for z in range(1, 5):
            if math.hypot(x + 0.5 - 4, z + 0.5 - 3) < 2.4:
                m.set(x, 0, z, "rooster" if (x + z) % 2 else "metaal2")
    return m


@tile("details/dak/ventilatiekap")
def vent_cap():
    """Round zinc ventilation pipe with a mushroom cap."""
    m = V(6, 6, 8)
    m.cyl(3, 3, 1.4, 0, 6, "zink1")
    m.cyl(3, 3, 2.6, 6, 7, "zink2")
    m.cyl(3, 3, 1.6, 7, 8, "zink2")
    return m


@tile("details/dak/zonnepanelen_schuin_rij")
def solar_panels_pitched():
    """Row of solar panels tilted towards the front on three A-frame supports."""
    m = V(32, 12, 8)
    for y in range(10):
        z = 1 + y // 2
        for x in range(32):
            m.set(x, y + 1, z, "metaal3" if x % 8 == 0 else "zonnepaneel")
    for x in (1, 15, 30):
        m.box(x, 1, 0, x + 1, 11, 1, "metaal2")
        m.box(x, 10, 0, x + 1, 11, 6, "metaal2")
    return m


@tile("details/dak/zonnepanelen_groot")
def solar_panels_large():
    """Flat 32x32 solar panel field for a full flat roof."""
    m = V(32, 32, 3)
    for y in range(32):
        for x in range(32):
            m.set(x, y, 1, "metaal3" if (x % 8 == 0 or y % 12 == 0) else "zonnepaneel")
        m.set(0, y, 0, "metaal2")
        m.set(31, y, 0, "metaal2")
    return m


@tile("details/dak/zonnepanelen_klein")
def solar_panels_small():
    """Small flat solar panel field (two panels)."""
    m = V(16, 12, 3)
    for y in range(12):
        for x in range(16):
            m.set(x, y, 1, "metaal3" if (x % 8 == 0 or y == 0) else "zonnepaneel")
    return m


@tile("details/dak/zonneboiler")
def solar_water_heater():
    """Solar water heater: tilted collector with a stainless storage tank behind it."""
    m = V(16, 12, 10)
    for y in range(10):
        z = 1 + y // 2
        for x in range(1, 15):
            m.set(x, y, z, "metaal3" if x in (1, 14) else ("glas_helder" if x % 2 else "metaal_donker"))
    m.box(1, 10, 7, 15, 12, 9, "rvs")
    return m


@tile("details/dak/dakkapel_los")
def dormer_single():
    """Free-standing dormer box with a zinc roof slab and a two-pane window on the front."""
    m = V(16, 12, 12)
    m.box(0, 0, 0, 16, 12, 10, "kozijn_wit")
    m.box(-1, -1, 10, 17, 13, 11, "zink1")
    m.box(2, 0, 2, 14, 1, 9, "glas1")
    m.box(8, 0, 2, 9, 1, 9, "kozijn_wit")
    return m


# ------------------------------------------------------------------ sun shading

def sun_shading(cols, width=24, depth=8, drop_arm=False):
    """Fabric sun shade against the wall, striped with ``cols`` in 3-voxel bands.

    drop_arm=False: folding-arm awning, nearly horizontal cloth with a valance (8 high).
    drop_arm=True: drop-arm awning, cloth sloping 1:1 down to the front with side arms (14 high).
    """
    m = att(width, depth, 14 if drop_arm else 8)
    hgt = m.sz
    if drop_arm:
        for d in range(depth):
            z = hgt - 1 - d
            for x in range(width):
                m.set(x, wd(m, d), z, stripe(cols, x))
        for x in (0, width - 1):
            for d in range(depth):
                m.set(x, wd(m, d), hgt - 2 - d, "metaal3")
    else:
        striped_cloth(m, cols, width, depth, hgt, 3)
    att_box(m, 0, width, 0, 1, hgt - 1, hgt, "metaal3")  # wall rail
    return m


register("details/zonwering/knikarmscherm_streep", lambda: sun_shading(["luifel_geel", "luifel_wit"]))
register("details/zonwering/knikarmscherm_groen", lambda: sun_shading(["luifel_groen"]))
register("details/zonwering/knikarmscherm_antraciet", lambda: sun_shading(["antraciet2"]))
register("details/zonwering/uitvalscherm_oranje", lambda: sun_shading(["luifel_oranje", "luifel_oranje", "luifel_wit"], 12, 6, True))
register("details/zonwering/uitvalscherm_blauw", lambda: sun_shading(["luifel_blauw", "luifel_wit"], 12, 6, True))


@tile("details/zonwering/rolluik")
def roller_shutter():
    """Metal roller shutter (window size) with its housing on top."""
    m = att(12, 1, 18)
    for z in range(18):
        c = "antraciet1" if z == 17 else ("metaal1" if z % 2 else "metaal2")
        att_box(m, 0, 12, 0, 1, z, z + 1, c)
    return m


@tile("details/zonwering/screen")
def screen():
    """Fabric window screen with dark side rails and housing."""
    m = att(12, 1, 18)
    for z in range(18):
        for x in range(12):
            m.set(x, wd(m, 0), z, "antraciet1" if (z == 17 or x in (0, 11)) else "antraciet2")
    return m


@tile("details/zonwering/markies")
def roll_awning():
    """Dutch 'markies': quarter-round striped awning, deepest at the top."""
    m = att(12, 4, 10)
    for d in range(4):
        r = 4 - d
        for z in range(10 - r * 2, 10):
            for x in range(12):
                m.set(x, wd(m, d), z, "luifel_rood" if (x // 2) % 2 else "luifel_wit")
    return m


# ------------------------------------------------------------------ facade lettering

WORDS = ["MINISTERIE", "HOTEL", "THEATER", "BIOSCOOP", "STATION", "BAKKERIJ", "APOTHEEK", "ZWERVR", "MUSEUM", "SCHOOL",
         "RAADHUIS", "BIBLIOTHEEK", "ZWEMBAD", "SPORTHAL", "POLITIE", "MARKT", "CAFE", "HAVEN", "KERK"]


def facade_text(word, scale=2, letter="goud", plate=None, lit=False):
    """Facade lettering for ``word`` in the common 3x5 pixel font.

    scale: voxels per font pixel. letter: letter colour, drawn in its glowing twin
    (palette.lit_colour) so the letters light up at night; ``lamp_warm`` when lit=True.
    plate: optional backing plate colour on the wall layer; letters sit one layer in front
    of it. The canvas has a 2-voxel margin and an even width (so it centres on the grid).
    """
    px, (tw, th) = text_pixels(word)
    w = tw * scale + 4
    w += w % 2
    hgt = 5 * scale + 4
    m = att(w, 2, hgt)
    if plate:
        att_box(m, 0, w, 0, 1, 0, hgt, plate)
    c = "lamp_warm" if lit else lit_colour(letter)   # letters glow at night
    for (col, row) in px:
        # font row 0 is the top line
        att_box(m, 2 + col * scale, 2 + (col + 1) * scale, 1, 2, 2 + (4 - row) * scale, 2 + (5 - row) * scale, c)
    return m


for _w in WORDS:
    register(f"details/tekst/tekst_{_w.lower()}", lambda w=_w: facade_text(w))
for _w in ("HOTEL", "THEATER", "BIOSCOOP", "CAFE", "ZWERVR"):
    register(f"details/tekst/lichtreclame_{_w.lower()}", lambda w=_w: facade_text(w, 2, plate="bord_zwart", lit=True))
for _w in ("BAKKER", "SLAGER", "KAAS", "BLOEMEN", "FIETSEN", "KAPPER"):
    register(f"details/tekst/bord_{_w.lower()}", lambda w=_w: facade_text(w, 1, "bord_wit", "deur_groen"))


# Letters with a diaeresis: drawn as the plain letter with two dots in the row above it.
DIAERESIS = {"Ë": "E", "Ï": "I", "Ö": "O", "Ü": "U"}


def name_lettering(lines, scale=2, letter="goud", plate=None, line_gap=2):
    """Facade lettering of several centred ``lines`` (3x5 pixel font, ``scale`` voxels per
    pixel), for the names of buildings. A letter with a diaeresis (Ë) gets its two dots in
    the gap above its line. plate: optional backing plate on the wall layer, the letters one
    layer in front of it. att() canvas: the wall on the centre plane, the letters stick out
    to the front (y=0); width even so it centres on the 0.5 m grid."""
    rendered = []
    for line in lines:
        plain = "".join(DIAERESIS.get(char, char) for char in line.upper())
        pixels, (text_width, _) = text_pixels(plain)
        dots = []
        for index, char in enumerate(line.upper()):
            if char in DIAERESIS:
                dots += [(index * 4, -1), (index * 4 + 2, -1)]
        rendered.append((pixels + dots, text_width))
    margin = 2 * scale
    widest = max(text_width for _, text_width in rendered)
    width = widest * scale + 2 * margin
    width += width % 2
    line_height = 5 + line_gap
    height = (len(lines) * line_height - line_gap) * scale + 2 * margin
    model = att(width, 2, height)
    if plate:
        att_box(model, 0, width, 0, 1, 0, height, plate)
    for line_index, (pixels, text_width) in enumerate(rendered):
        left = (width - text_width * scale) // 2
        top_row = height - margin - line_index * line_height * scale   # z above the top pixel row
        for column, row in pixels:
            x0 = left + column * scale
            z0 = top_row - (row + 1) * scale
            att_box(model, x0, x0 + scale, 1, 2, z0, z0 + scale, lit_colour(letter))
    return model


# The big name on the station hall, and the names of the ministries without "Ministerie van"
# (one per building that carries "tekst/tekst_ministerie" in the city).
register("details/tekst/tekst_den_haag_centraal",
         lambda: name_lettering(["DEN HAAG CENTRAAL"], 3, "bord_wit", plate="bord_blauw"))
register("details/tekst/tekst_ministerie_financien",
         lambda: name_lettering(["FINANCIËN"], 2))
register("details/tekst/tekst_ministerie_justitie_en_veiligheid",
         lambda: name_lettering(["JUSTITIE EN VEILIGHEID"], 1))
register("details/tekst/tekst_ministerie_binnenlandse_zaken",
         lambda: name_lettering(["BINNENLANDSE ZAKEN"], 1))
register("details/tekst/tekst_ministerie_vws",
         lambda: name_lettering(["VOLKSGEZONDHEID,", "WELZIJN EN SPORT"], 1))


# The emblems of the parody supermarkets: (pictogram in PICTO, badge shape "vierkant" or
# "rond"). Original marks, not after the real chains' logos.
BRAND_EMBLEMS = {"derrek": ("mandje", "vierkant"), "alfred_steyhn": ("tulp", "rond")}


def draw_badge(model, left, bottom, size, picto_name, shape, background, foreground, depth=1):
    """A ``size`` x ``size`` badge with its bottom-left at (left, bottom) on depth layer
    ``depth`` of an att() canvas: a square with cut corners ("vierkant") or a disc ("rond")
    in ``background``, with the pictogram PICTO[picto_name] in ``foreground``, centred and
    scaled up as far as it fits."""
    rows = PICTO[picto_name]
    background, foreground = lit_colour(background), lit_colour(foreground)   # emblems glow at night
    centre = size / 2
    for x in range(size):
        for z in range(size):
            if shape == "rond":
                inside = math.hypot(x + 0.5 - centre, z + 0.5 - centre) <= centre
            else:
                inside = min(x, size - 1 - x) + min(z, size - 1 - z) >= 1
            if inside:
                att_box(model, left + x, left + x + 1, depth, depth + 1, bottom + z, bottom + z + 1, background)
    picto_width, picto_height = len(rows[0]), len(rows)
    room = size - 4 if shape == "vierkant" else int(size * 0.72)
    scale = max(1, room // max(picto_width, picto_height))
    picto_left = left + (size - picto_width * scale) // 2
    picto_top = bottom + (size + picto_height * scale) // 2
    for row_index, line in enumerate(rows):
        for column, pixel in enumerate(line):
            if pixel == "#":
                x0 = picto_left + column * scale
                z0 = picto_top - (row_index + 1) * scale
                att_box(model, x0, x0 + scale, depth, depth + 1, z0, z0 + scale, foreground)


def draw_emblem(model, left, bottom, size, brand, background, foreground, depth=1):
    """The emblem of supermarket ``brand`` (BRAND_EMBLEMS) as a badge, see draw_badge."""
    picto_name, shape = BRAND_EMBLEMS[brand]
    draw_badge(model, left, bottom, size, picto_name, shape, background, foreground, depth)


def brand_sign(word, scale, plate, letter="bord_wit", brand=None):
    """Big facade sign of a shop chain: ``word`` in ``letter`` on a ``plate`` with a rim in
    the letter colour; with ``brand`` the chain's emblem (a ``letter``-coloured badge with
    the pictogram in the plate colour) stands left of the name. att() canvas, wall on the
    centre plane."""
    pixels, (text_width, _) = text_pixels(word)
    margin = 2 * scale
    height = 5 * scale + 2 * margin
    badge = height - 4 if brand else 0
    width = text_width * scale + 2 * margin + (badge + margin if brand else 0)
    width += width % 2
    model = att(width, 2, height)
    att_box(model, 0, width, 0, 1, 0, height, letter)                 # rim
    att_box(model, 1, width - 1, 0, 1, 1, height - 1, plate)
    left = margin
    if brand:
        draw_emblem(model, margin, 2, badge, brand, letter, plate)
        left += badge + margin
    for column, row in pixels:
        x0 = left + column * scale
        z0 = height - margin - (row + 1) * scale
        att_box(model, x0, x0 + scale, 1, 2, z0, z0 + scale, lit_colour(letter))
    return model


def brand_logo(brand, plate, size=20):
    """Free-standing logo for a facade (``size`` voxels square, 2.5 m by default): the
    emblem of ``brand`` with a white pictogram on its house colour, framed by a white
    rim of the same shape. att() canvas, wall on the centre plane."""
    model = att(size, 2, size)
    draw_emblem(model, 0, 0, size, brand, "bord_wit", "bord_wit", depth=0)
    draw_emblem(model, 1, 1, size - 2, brand, plate, "bord_wit", depth=1)
    return model


register("details/tekst/tekst_derrek", lambda: brand_sign("DERREK", 3, "winkel_rood", brand="derrek"))
register("details/tekst/tekst_alfred_steyhn", lambda: brand_sign("ALFRED STEYHN", 2, "winkel_lichtblauw",
                                                                 brand="alfred_steyhn"))
register("details/tekst/logo_derrek", lambda: brand_logo("derrek", "winkel_rood"))
register("details/tekst/logo_alfred_steyhn", lambda: brand_logo("alfred_steyhn", "winkel_lichtblauw"))


# ------------------------------------------------------------------ made-up shop and company names

def name_sign(lines, picto, plate, letter, badge, mark, shape="vierkant", scale=1):
    """Name sign of a (made-up) business: its emblem (a ``badge``-coloured badge with the
    pictogram ``picto`` in ``mark``) on the left, the name in ``lines`` (one or two) in
    ``letter`` to its right, each line centred. With a ``plate`` colour the sign is a board
    with a rim in the letter colour; without, loose letters and emblem on the wall. att()
    canvas: the wall on the centre plane, the front at y=0; width even."""
    rendered = [text_pixels(line) for line in lines]
    margin = 2 * scale
    height = 2 * margin + (len(lines) * 6 - 1) * scale
    badge_size = height - 2 * scale
    text_width = max(width for _, (width, _) in rendered) * scale
    text_left = margin + badge_size + margin
    width = text_left + text_width + margin
    width += width % 2
    model = att(width, 2, height)
    if plate:
        att_box(model, 0, width, 0, 1, 0, height, letter)
        att_box(model, 1, width - 1, 0, 1, 1, height - 1, plate)
    draw_badge(model, margin, scale, badge_size, picto, shape, badge, mark)
    for line_index, (pixels, (line_width, _)) in enumerate(rendered):
        left = text_left + (text_width - line_width * scale) // 2
        top = height - margin - line_index * 6 * scale
        for column, row in pixels:
            x0 = left + column * scale
            z0 = top - (row + 1) * scale
            att_box(model, x0, x0 + scale, 1, 2, z0, z0 + scale, lit_colour(letter))
    return model


# Shop kind (the bg_ suffix of the shop ground floors in the city) -> its pictogram and
# its made-up names: (lines, plate, letter colour, badge colour, pictogram colour, shape).
# Names are data (they end up on the facades); none is a real brand.
SHOP_NAMES = {
    "bakker": ("brood", [
        (["KORSTJE", "EN ZOON"], "deur_rood", "bord_wit", "bord_geel", "deur_rood", "rond"),
        (["GOUDEN", "KORST"], "bord_zwart", "goud", "goud", "bord_zwart", "vierkant"),
        (["BAKKERIJ", "DEEGNIET"], "luifel_wit", "deur_rood", "deur_rood", "luifel_wit", "rond")]),
    "cafe": ("koffie", [
        (["KOFFIE", "KLETS"], "hout_donker1", "luifel_wit", "luifel_wit", "hout_donker1", "rond"),
        (["CAFE", "HOEKJE"], "deur_groen", "goud", "goud", "deur_groen", "vierkant"),
        (["BONEN", "BAR"], "bord_zwart", "bloem_oranje", "bloem_oranje", "bord_zwart", "rond")]),
    "kleding": ("shirt", [
        (["MODE", "MAATJE"], "bord_zwart", "bord_wit", "bloem_roze", "bord_zwart", "vierkant"),
        (["JASSEN", "JANSEN"], "deur_blauw", "bord_wit", "bord_wit", "deur_blauw", "rond"),
        (["KLEREN", "KASTJE"], "luifel_wit", "bord_zwart", "bord_zwart", "luifel_wit", "vierkant")]),
    "boekhandel": ("boek", [
        (["BOEKJE", "OPEN"], "deur_blauw", "luifel_wit", "luifel_wit", "deur_blauw", "vierkant"),
        (["PAGINA", "TWEE"], "deur_groen", "goud", "goud", "deur_groen", "rond")]),
    "restaurant": ("bestek", [
        (["EETHUIS", "DE VORK"], "bord_zwart", "goud", "goud", "bord_zwart", "rond"),
        (["TAFEL", "VOOR 2"], "deur_rood", "luifel_wit", "luifel_wit", "deur_rood", "vierkant"),
        (["BISTRO", "BORDJE"], "deur_groen", "luifel_wit", "luifel_wit", "deur_groen", "rond")]),
    "bloemist": ("bloem", [
        (["STEELTJE", "BLOEMEN"], "deur_groen", "bord_wit", "bloem_roze", "deur_groen", "rond"),
        (["FLEUR", "EN FLORA"], "luifel_wit", "deur_groen", "bloem_geel", "deur_groen", "vierkant")]),
    "juwelier": ("diamant", [
        (["GLIMMER", "JUWELEN"], "bord_zwart", "goud", "goud", "bord_zwart", "vierkant"),
        (["KARAAT", "KEES"], "deur_blauw", "bord_wit", "bord_wit", "deur_blauw", "rond")]),
    "ijssalon": ("ijsje", [
        (["BOLLETJE", "IJS"], "bloem_roze", "bord_wit", "bord_wit", "bloem_roze", "rond"),
        (["KOUD", "KOUDER"], "paneel_blauw", "bord_wit", "bord_wit", "paneel_blauw", "vierkant")]),
    "slager": ("hakmes", [
        (["WORST", "WIM"], "deur_rood", "bord_wit", "bord_wit", "deur_rood", "vierkant"),
        (["SLAGERIJ", "ROSBIEF"], "luifel_wit", "bord_rood2", "bord_rood2", "luifel_wit", "rond")]),
    "fietsenwinkel": ("fiets", [
        (["TRAPPERS", "FIETSEN"], "bord_zwart", "bord_geel", "bord_geel", "bord_zwart", "vierkant"),
        (["SPAAK", "EN ZADEL"], "bord_blauw", "bord_wit", "bord_wit", "bord_blauw", "rond")]),
    "drogist": ("capsule", [
        (["PLEISTER", "DROGIST"], "luifel_wit", "bord_groen", "bord_groen", "luifel_wit", "rond"),
        (["ZALFJE", "EN ZO"], "bloem_roze", "bord_wit", "bord_wit", "bloem_roze", "vierkant")]),
    "kapper": ("schaar", [
        (["KNIPPIE", "KAPSALON"], "bord_zwart", "bord_wit", "bord_wit", "bord_zwart", "vierkant"),
        (["HAAR", "KLOPT"], "luifel_wit", "bord_zwart", "bloem_paars", "luifel_wit", "rond")]),
    "snackbar": ("friet", [
        (["FRIETJE", "FATSOEN"], "bord_geel", "bord_rood", "bord_rood", "bord_geel", "rond"),
        (["DE", "VETPOT"], "bord_rood", "bord_geel", "bord_geel", "bord_rood", "vierkant")]),
    "supermarkt": ("mandje", [
        (["BUURT", "SUPER"], "bord_groen", "bord_wit", "bord_wit", "bord_groen", "vierkant"),
        (["KOOPJE", "MARKT"], "bloem_oranje", "bord_wit", "bord_wit", "bloem_oranje", "rond")]),
    "telefoon": ("telefoon", [
        (["BEREIK", "TELECOM"], "paneel_blauw", "bord_wit", "bord_wit", "paneel_blauw", "vierkant"),
        (["BELLEN", "EN ZO"], "bord_oranje", "bord_wit", "bord_wit", "bord_oranje", "rond")]),
    "bar": ("bier", [
        (["DE", "TAPKRAAN"], "hout_donker1", "goud", "goud", "hout_donker1", "rond"),
        (["DORST", "BAR"], "bord_zwart", "bord_rood", "bord_rood", "bord_zwart", "vierkant")]),
    "dierenwinkel": ("poot", [
        (["POOTJE", "DIEREN"], "deur_groen", "bord_wit", "bord_wit", "deur_groen", "rond"),
        (["KWISPEL", "EN KO"], "luifel_geel", "hout_donker1", "hout_donker1", "luifel_geel", "vierkant")]),
}

for _kind, (_picto, _names) in SHOP_NAMES.items():
    for _number, (_lines, _plate, _letter, _badge, _mark, _shape) in enumerate(_names, 1):
        register(f"details/tekst/naam_{_kind}_{_number}",
                 lambda lines=_lines, picto=_picto, plate=_plate, letter=_letter, badge=_badge, mark=_mark, shape=_shape:
                 name_sign(lines, picto, plate, letter, badge, mark, shape))

# Office towers: big loose letters (scale 2) with an emblem, no board.
OFFICE_NAMES = [
    (["POLDERTECH"], "golf", "bord_wit", "paneel_blauw", "bord_wit", "rond"),
    (["DIJK EN DAM", "ADVOCATEN"], "blokken", "bord_wit", "deur_blauw", "bord_wit", "vierkant"),
    (["HOFSTAD", "VERZEKERD"], "ruit", "bord_wit", "deur_rood", "bord_wit", "vierkant"),
    (["KLOMPENBERG", "CONSULTANCY"], "pijl_op", "bord_wit", "bord_groen", "bord_wit", "rond"),
    (["DUINWATER", "ENERGIE"], "zon", "bord_wit", "bord_geel", "bord_wit", "rond"),
]
for _number, (_lines, _picto, _letter, _badge, _mark, _shape) in enumerate(OFFICE_NAMES, 1):
    register(f"details/tekst/naam_kantoor_{_number}",
             lambda lines=_lines, picto=_picto, letter=_letter, badge=_badge, mark=_mark, shape=_shape:
             name_sign(lines, picto, None, letter, badge, mark, shape, scale=2))


# ------------------------------------------------------------------ flags on the facade

def facade_flag(colors):
    """Flag on a slanted wall pole; ``colors`` are the stripes from top to bottom."""
    return pole_flag(colors)


for _k, _c in FLAGS.items():
    register(f"details/gevel/vlag_{_k}", lambda c=_c: facade_flag(c))


@tile("details/gevel/vlag_regenboog_hangend")
def flag_rainbow_hanging():
    """Rainbow banner hanging flat against the wall from a rod, stripes vertical."""
    m = att(12, 2, 20)
    cols = ["vlag_rood", "vlag_oranje", "vlag_geel", "vlag_groen", "vlag_blauw", "vlag_paars"]
    for x in range(12):
        m.set(x, wd(m, 1), 19, "metaal3")
        for z in range(0, 19):
            m.set(x, wd(m, 1), z, cols[x // 2])
    return m


# ------------------------------------------------------------------ entrance steps for classic houses

def entry_steps(steps, width=12, handrail=False, landing=False):
    """Stone entrance steps: ``steps`` treads 2 voxels deep, each 1 voxel high.

    landing=True adds a 4-deep landing against the wall and widens the canvas by 4.
    handrail=True adds railings on both sides, 6 voxels above the treads.
    """
    lead = 4 if landing else 0
    depth = steps * 2 + lead
    m = att(width + lead, depth, steps + 8)
    w = m.sx

    def height(d):
        return steps if d < lead else steps - (d - lead) // 2

    for d in range(depth):
        hd = height(d)
        for x in range(w):
            for z in range(hd):
                m.set(x, wd(m, d), z, "natuursteen1" if z == hd - 1 else "natuursteen2")
    if handrail:
        for x in (0, w - 1):
            for d in range(depth):
                hd = height(d)
                m.set(x, wd(m, d), hd + 6, "metaal_donker")
                if d % 3 == 0:
                    for z in range(hd, hd + 6):
                        m.set(x, wd(m, d), z, "metaal_donker")
    return m


register("details/deuren/opstap_2_treden", lambda: entry_steps(2))
register("details/deuren/opstap_3_treden", lambda: entry_steps(3))
register("details/deuren/opstap_4_treden_leuning", lambda: entry_steps(4, handrail=True))
register("details/deuren/bordes_klassiek", lambda: entry_steps(4, 12, True, True))


# ------------------------------------------------------------------ garage doors

def garage_door(kind, width=24):
    """Garage door of ``kind``: kanteldeur (wooden up-and-over), sectionaal (sectional with
    windows), roldeur (roller door) or anything else = classic green double door."""
    m = att(width, 1, 17)
    for z in range(17):
        for x in range(width):
            edge = x in (0, width - 1) or z == 16
            if edge:
                c = "antraciet1"
            elif kind == "kanteldeur":
                c = "hout2" if (x // 2) % 2 else "hout1"
            elif kind == "sectionaal":
                c = "stuc1" if (z // 4) % 2 else "stuc2"
            elif kind == "roldeur":
                c = "metaal1" if z % 2 else "metaal2"
            else:
                c = "kozijn_groen" if not ((x == width // 2) or z in (5, 11)) else "kozijn_wit"
            m.set(x, wd(m, 0), z, c)
    if kind == "sectionaal":
        for x in range(3, width - 3, 3):
            m.set(x, wd(m, 0), 13, "glas2")
    return m


for _k in ("kanteldeur", "sectionaal", "roldeur", "dubbel_klassiek"):
    register(f"details/deuren/garagedeur_{_k}", lambda k=_k: garage_door(k))
