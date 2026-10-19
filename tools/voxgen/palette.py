"""Shared colour palette and material tags for all tiles.

All tiles draw from one global palette, so the same colours (by name) show up in
every tile in MagicaVoxel. Each entry is ``(name, (r, g, b))`` or
``(name, (r, g, b), material)``. Colour names are data: tile code refers to them
via ``P["name"]`` and they must not be renamed.

Exports (used by vox.py and the tile modules):
  P           colour name -> global colour id (1-based, unbounded)
  PALETTE     global id -> (r, g, b)
  MATERIALS   global id -> material tag
  ORDER       all global ids in palette order
  WATER_START / FLAG_START  fixed per-file palette slots for water / flag colours

Material tags:
  metal  -> metallic             glass -> transparent glass
  emit   -> light emitting       paneel -> glossy metal (solar panels)
  water  -> water (per-file palette slots WATER_START..FLAG_START-1, i.e. 225..232)
  flag   -> waving flag cloth (per-file slots from FLAG_START = 233)
  asphalt / stone -> Godot-only surface materials, assigned by name group below
The MagicaVoxel tags are written as MATL chunks by vox.write_vox; all tags end up
in the tile metadata via vox.write_metadata, which the Godot importer reads.
"""
import re

_ENTRIES = [
    # --- road surface
    ("asfalt1", (58, 58, 62)), ("asfalt2", (66, 66, 70)), ("asfalt3", (74, 73, 77)),
    ("asfalt4", (50, 50, 54)), ("asfalt_reparatie", (42, 42, 46)),
    ("markering", (232, 232, 226)), ("markering2", (214, 214, 208)), ("markering_geel", (232, 190, 40)),
    ("fietsasfalt1", (150, 62, 52)), ("fietsasfalt2", (140, 56, 48)), ("fietsasfalt3", (160, 70, 58)),
    ("busbaan1", (120, 44, 44)), ("busbaan2", (110, 40, 40)),
    # --- sidewalk / paving
    ("tegel1", (142, 140, 134)), ("tegel2", (132, 130, 125)), ("tegel3", (150, 148, 142)),
    ("tegel4", (124, 122, 117)), ("tegel_voeg", (100, 98, 94)),
    ("ribbel", (196, 196, 188)),
    ("band1", (172, 170, 164)), ("band2", (162, 160, 154)),
    ("goot1", (140, 138, 134)), ("goot2", (128, 126, 122)),
    ("klinker1", (142, 94, 72)), ("klinker2", (128, 84, 64)), ("klinker3", (154, 106, 80)),
    ("klinker4", (116, 76, 60)), ("klinker5", (104, 86, 76)),
    ("kei1", (110, 106, 100)), ("kei2", (96, 92, 88)), ("kei3", (124, 116, 104)),
    ("kei4", (88, 80, 72)), ("kei_voeg", (60, 58, 54)),
    ("plein1", (168, 158, 140)), ("plein2", (156, 146, 130)), ("plein3", (178, 170, 152)),
    ("plein_donker", (110, 104, 96)), ("plein_rood", (150, 104, 84)),
    # --- nature
    ("gras1", (86, 136, 52)), ("gras2", (98, 150, 58)), ("gras3", (76, 124, 46)),
    ("gras4", (110, 160, 66)), ("gras5", (70, 112, 44)), ("gras_droog", (140, 150, 80)),
    ("bloem_wit", (240, 240, 232)), ("bloem_geel", (240, 210, 60)), ("bloem_paars", (150, 90, 190)),
    ("bloem_rood", (210, 50, 50)), ("bloem_roze", (230, 130, 170)), ("bloem_oranje", (240, 140, 40)),
    ("aarde1", (110, 82, 58)), ("aarde2", (96, 70, 50)), ("aarde3", (124, 94, 66)), ("aarde_donker", (72, 54, 40)),
    ("zand1", (214, 196, 150)), ("zand2", (200, 182, 138)),
    ("modder", (70, 60, 46)), ("waterbodem", (52, 58, 48)), ("waterbodem2", (44, 50, 42)),
    ("alg1", (70, 90, 50)), ("alg2", (56, 74, 42)),
    ("riet1", (150, 150, 80)), ("riet2", (120, 130, 60)), ("riet_pluim", (130, 100, 70)),
    # --- rail
    ("grind1", (132, 128, 120)), ("grind2", (112, 108, 102)), ("grind3", (150, 146, 138)), ("grind_roest", (120, 100, 84)),
    ("biels_beton", (170, 168, 160)), ("biels_hout", (92, 70, 52)),
    ("rail", (120, 118, 116), "metal"), ("rail_glim", (176, 176, 178), "metal"), ("railgroef", (36, 36, 38)),
    # --- facades
    ("baksteen1", (150, 64, 48)), ("baksteen2", (136, 58, 44)), ("baksteen3", (162, 74, 54)),
    ("baksteen4", (124, 52, 40)), ("baksteen5", (170, 86, 64)), ("voeg", (176, 170, 160)),
    ("donkersteen1", (84, 46, 40)), ("donkersteen2", (72, 40, 36)), ("donkersteen3", (96, 54, 46)),
    ("geelsteen1", (204, 170, 110)), ("geelsteen2", (190, 156, 98)), ("geelsteen3", (214, 184, 124)),
    ("natuursteen1", (222, 216, 200)), ("natuursteen2", (206, 200, 184)), ("natuursteen3", (190, 184, 170)),
    ("stuc1", (236, 234, 226)), ("stuc2", (226, 224, 216)), ("stuc3", (214, 212, 204)),
    ("paneel1", (140, 144, 148)), ("paneel2", (120, 124, 128)), ("paneel3", (160, 164, 168)),
    ("hout1", (160, 110, 70)), ("hout2", (140, 94, 58)), ("hout3", (176, 126, 84)),
    ("hout_donker1", (96, 64, 42)), ("hout_donker2", (80, 52, 34)),
    ("antraciet1", (52, 54, 58)), ("antraciet2", (64, 66, 70)), ("antraciet3", (42, 44, 48)),
    ("beton1", (170, 170, 166)), ("beton2", (156, 156, 152)), ("beton3", (184, 184, 180)), ("beton_donker", (120, 120, 116)),
    ("kozijn_wit", (240, 240, 236)), ("kozijn_groen", (36, 70, 52)), ("kozijn_zwart", (30, 30, 32)), ("kozijn_creme", (230, 222, 196)),
    ("glas1", (120, 160, 190), "glass"), ("glas2", (90, 130, 165), "glass"),
    ("glas_kantoor", (100, 150, 160), "glass"), ("glas_helder", (170, 200, 215), "glass"),
    ("interieur1", (40, 36, 34)), ("interieur2", (56, 48, 42)), ("interieur3", (30, 30, 34)),
    ("gordijn1", (200, 190, 170)), ("gordijn2", (150, 60, 50)), ("gordijn3", (80, 90, 120)),
    ("licht_warm", (255, 210, 140), "emit"), ("licht_wit", (240, 244, 255), "emit"),
    # --- roofs
    ("pan_rood1", (160, 62, 40)), ("pan_rood2", (146, 54, 36)), ("pan_rood3", (172, 72, 48)),
    ("pan_zwart1", (44, 44, 48)), ("pan_zwart2", (54, 54, 60)), ("pan_zwart3", (36, 36, 40)),
    ("leisteen1", (70, 76, 86)), ("leisteen2", (60, 66, 76)),
    ("dakgrind1", (150, 146, 138)), ("dakgrind2", (130, 126, 120)),
    ("bitumen1", (46, 46, 48)), ("bitumen2", (56, 56, 58)),
    ("zink1", (150, 156, 160), "metal"), ("zink2", (130, 136, 140), "metal"),
    ("zonnepaneel", (30, 40, 70), "paneel"),
    # --- doors / details
    ("deur_groen", (28, 72, 50)), ("deur_rood", (130, 30, 30)), ("deur_blauw", (30, 50, 100)),
    ("deur_zwart", (24, 24, 26)), ("deur_wit", (230, 230, 226)),
    ("messing", (200, 170, 80), "metal"),
    # --- metal / street furniture
    ("metaal1", (140, 142, 146), "metal"), ("metaal2", (110, 112, 116), "metal"), ("metaal3", (170, 172, 176), "metal"),
    ("metaal_donker", (60, 62, 66), "metal"), ("rvs", (196, 198, 200), "metal"), ("gegalvaniseerd", (160, 166, 168), "metal"),
    ("rooster", (40, 40, 42), "metal"),
    ("amsterdamgroen", (34, 58, 44)), ("paal_bruin", (100, 46, 32)),
    ("hout_bank1", (176, 124, 74)), ("hout_bank2", (160, 110, 64)), ("hout_bank3", (190, 138, 86)),
    ("rubber", (28, 28, 30)), ("oranje", (240, 110, 20)),
    # --- trees / plants
    ("schors1", (86, 66, 50)), ("schors2", (72, 56, 42)), ("schors3", (100, 78, 58)),
    ("berkenschors", (226, 222, 212)), ("berkenschors_zwart", (50, 48, 46)), ("plataanschors", (170, 160, 120)),
    ("blad1", (64, 118, 44)), ("blad2", (76, 134, 50)), ("blad3", (52, 100, 38)),
    ("blad4", (92, 150, 60)), ("blad5", (44, 86, 34)), ("blad_licht", (120, 170, 70)),
    ("naald1", (40, 80, 50)), ("naald2", (30, 66, 42)), ("naald3", (52, 94, 58)),
    ("herfst1", (200, 120, 40)), ("herfst2", (180, 80, 30)), ("herfst3", (220, 170, 60)),
    ("bloesem1", (240, 190, 210)), ("bloesem2", (250, 220, 230)),
    ("haag1", (46, 96, 40)), ("haag2", (38, 84, 34)),
    ("terracotta1", (176, 96, 62)), ("terracotta2", (156, 82, 52)),
    # --- signs
    ("bord_rood", (200, 30, 36)), ("bord_rood2", (170, 24, 30)), ("bord_blauw", (20, 70, 160)), ("bord_blauw2", (16, 56, 130)),
    ("bord_wit", (245, 245, 245)), ("bord_zwart", (20, 20, 22)), ("bord_geel", (250, 200, 30)), ("bord_oranje", (240, 120, 20)),
    ("bord_groen", (20, 110, 60)), ("bord_groen2", (14, 90, 50)),
    # --- lighting
    ("lamp_wit", (255, 250, 235), "emit"), ("lamp_warm", (255, 200, 120), "emit"),
    ("stoplicht_rood", (255, 40, 30), "emit"), ("stoplicht_oranje", (255, 160, 20), "emit"), ("stoplicht_groen", (40, 255, 120), "emit"),
    ("stoplicht_rood_uit", (70, 20, 18)), ("stoplicht_oranje_uit", (80, 56, 14)), ("stoplicht_groen_uit", (16, 60, 30)),
    ("reclame1", (240, 240, 220), "emit"), ("reclame2", (120, 190, 240), "emit"), ("reclame3", (250, 120, 90), "emit"),
    ("matrix", (220, 40, 30), "emit"),
    # --- textiles / awnings / vehicles
    ("luifel_rood", (180, 40, 40)), ("luifel_groen", (40, 110, 70)), ("luifel_blauw", (40, 70, 140)),
    ("luifel_geel", (230, 180, 50)), ("luifel_wit", (236, 232, 220)), ("luifel_oranje", (220, 110, 40)),
    ("fiets_rood", (150, 30, 30)), ("fiets_blauw", (40, 60, 120)), ("fiets_zwart", (30, 30, 32)),
    ("boot_wit", (236, 236, 232)), ("boot_blauw", (40, 70, 120)), ("boot_rood", (150, 40, 30)), ("boot_groen", (40, 90, 60)),
    # --- extension: 1930s / 60s / 80s / 2000s styles, churches, sheds, hospitality
    ("baksteen30_1", (112, 52, 42)), ("baksteen30_2", (98, 46, 38)), ("baksteen30_3", (126, 62, 48)),
    ("geelsteen60_1", (196, 180, 140)), ("geelsteen60_2", (184, 168, 128)), ("beton60", (176, 172, 160)),
    ("paneel_blauw", (60, 110, 170)), ("paneel_geel", (230, 190, 60)), ("paneel_rood", (190, 70, 50)), ("paneel_groen", (80, 140, 100)),
    ("bruin80_1", (92, 66, 50)), ("bruin80_2", (110, 80, 60)), ("alu", (184, 188, 194), "metal"),
    ("glas_lood_geel", (220, 190, 90), "glass"), ("glas_lood_rood", (180, 60, 50), "glass"), ("glas_lood_blauw", (60, 90, 170), "glass"),
    ("glas_brons", (120, 96, 70), "glass"), ("glas_blauw", (60, 120, 170), "glass"), ("glas_groen", (90, 150, 140), "glass"),
    ("riet_dak1", (150, 128, 84)), ("riet_dak2", (132, 112, 72)),
    ("schuur_zwart", (40, 38, 36)), ("schuur_rood", (120, 40, 32)),
    ("koper", (90, 150, 130), "metal"), ("goud", (210, 170, 60), "metal"),
    ("neon_roze", (255, 80, 180), "emit"), ("neon_blauw", (80, 160, 255), "emit"),
    ("tegel_wit", (220, 224, 226)), ("stof1", (60, 80, 140)), ("stof2", (170, 60, 70)), ("stof3", (230, 220, 200)),
    ("tafelkleed", (245, 245, 240)), ("scherm", (40, 120, 220), "emit"),
    ("pan_oranje1", (196, 98, 52)), ("pan_oranje2", (182, 88, 46)), ("pan_antraciet1", (66, 68, 72)), ("pan_antraciet2", (76, 78, 84)),
    ("golfplaat1", (150, 156, 150), "metal"), ("golfplaat2", (120, 126, 120), "metal"), ("pan_groen", (40, 70, 52)),
    ("signaal_rood", (255, 30, 20), "emit"),
    ("sedum1", (112, 142, 62)), ("sedum2", (146, 112, 72)), ("sedum3", (92, 128, 70)), ("sedum4", (160, 150, 70)),
    ("brons", (120, 92, 58), "metal"), ("brons_patina", (86, 128, 108), "metal"), ("marmer", (232, 230, 224)),
]

# Flag cloth colours: material "flag", stored from FLAG_START in every .vox (max 16).
_FLAG = [
    ("vlag_rood", (200, 30, 40)), ("vlag_wit", (245, 245, 245)), ("vlag_blauw", (30, 70, 160)), ("vlag_oranje", (240, 120, 20)),
    ("vlag_geel", (250, 205, 30)), ("vlag_groen", (30, 140, 70)), ("vlag_paars", (130, 60, 170)), ("vlag_zwart", (25, 25, 28)),
    ("vlag_lichtblauw", (110, 200, 240)), ("vlag_roze", (240, 160, 190)), ("vlag_donkerblauw", (20, 40, 110)), ("vlag_bruin", (110, 70, 40)),
]
FLAG_START = 233  # first per-file palette slot for flag colours

# Water colours: material "water", stored from WATER_START in every .vox (max 8).
_WATER = [
    ("water1", (40, 96, 118)), ("water2", (34, 86, 108)), ("water3", (48, 106, 126)), ("water_gracht", (44, 80, 70)),
    ("water_zwembad", (70, 170, 205)),
]
WATER_START = 225  # first per-file palette slot for water colours (normal colours use 1..224)

# Colour variation within numbered groups (asfalt1..4, gras1..5, baksteen1..5, ...):
# every member is pulled towards the group average. 1.0 = original colours,
# 0.0 = all members become the average colour.
VARIATION = 0.65
# Groups that are left untouched: their numbered members are deliberately different
# colours, or (paving) the pattern relies on the contrast between them.
_FIXED_GROUPS = {"gordijn", "stof", "reclame", "sedum", "glas",
                  # paving: the pattern is in the colour differences
                  "tegel", "klinker", "kei", "plein", "band", "goot", "grind",
                  "asfalt", "fietsasfalt", "busbaan"}


def _damp_variation(entries):
    """Return a copy of ``entries`` with numbered colour groups damped by VARIATION.

    A group is every entry named ``<base><n>`` or ``<base>_<n>`` with the same base
    (e.g. "baksteen1".."baksteen5", "baksteen30_1".."baksteen30_3"). For groups with
    at least two members whose base is not in _FIXED_GROUPS, each channel becomes
    ``round(avg + (c - avg) * VARIATION)``. Names, order and material tags are kept.
    """
    groups = {}
    for i, e in enumerate(entries):
        m = re.match(r"^(.*?)_?(\d+)$", e[0])
        if m and m.group(1) not in _FIXED_GROUPS:
            groups.setdefault(m.group(1), []).append(i)
    out = list(entries)
    for members in groups.values():
        if len(members) < 2:
            continue
        avg = [sum(entries[i][1][k] for i in members) / len(members) for k in range(3)]
        for i in members:
            e = entries[i]
            color = tuple(int(round(avg[k] + (e[1][k] - avg[k]) * VARIATION)) for k in range(3))
            out[i] = (e[0], color) + tuple(e[2:])
    return out


_ENTRIES = _damp_variation(_ENTRIES)

# Global colour ids (unlimited count): normal entries first, then water, then flags,
# numbered from 1. On write every .vox file gets its own 255-colour palette holding
# the colours it uses (max 224 normal + 8 water + 16 flag), see vox.write_vox.
PALETTE = {}
MATERIALS = {}
P = {}
ORDER = []

for _entries, _forced in ((_ENTRIES, None), (_WATER, "water"), (_FLAG, "flag")):
    for e in _entries:
        _gid = len(ORDER) + 1
        PALETTE[_gid] = e[1]
        P[e[0]] = _gid
        ORDER.append(_gid)
        if len(e) > 2:
            MATERIALS[_gid] = e[2]
        if _forced:
            MATERIALS[_gid] = _forced


# Surface materials that only exist in Godot (MagicaVoxel shows them as diffuse).
# They end up in the tile metadata (<tile>.tile.json, see vox.write_metadata).
# A colour belongs to a group when its name without the trailing number (and optional
# "_") is listed, e.g. "asfalt3" -> "asfalt", "beton_donker" stays "beton_donker".
# Colours that already have a material tag keep it.
_SURFACE_GROUPS = {
    "asphalt": ("asfalt", "asfalt_reparatie", "fietsasfalt", "busbaan", "bitumen"),
    "stone": ("ribbel", "band", "goot", "klinker", "plein", "plein_donker",
              "plein_rood", "natuursteen", "marmer", "donkersteen", "leisteen", "beton", "beton_donker"),
    "brick": ("baksteen", "baksteen30", "geelsteen", "geelsteen60"),
    "gravel": ("grind", "grind_roest", "dakgrind"),
    "paving": ("tegel", "tegel_wit"),
    "cobble": ("kei",),
    "plaster": ("stuc",),
    # painted metal: lamp posts, bollards, road signs
    "painted": ("amsterdamgroen", "bord_blauw", "bord_geel", "bord_groen", "bord_oranje", "bord_rood",
                "bord_wit", "bord_zwart"),
}


def _surface_group(name):
    """Colour name without its trailing number: "klinker2" -> "klinker"."""
    return re.sub(r"_?\d+$", "", name)


for _name, _gid in P.items():
    for _mat, _groups in _SURFACE_GROUPS.items():
        if _gid not in MATERIALS and _surface_group(_name) in _groups:
            MATERIALS[_gid] = _mat
