"""Who may use each ground tile and which way, written as "traffic" into each tile's .tile.json
(vox.write_metadata) and read by Godot's road network (scripts/world/road_network.gd,
through the "traffic" metadata of the ground MeshLibrary, library_builder.gd).

    "traffic": {"lanes": ["N"], "road": "straat", "speed": 50, "rise": 1.0, "only": ["auto", "fiets"]}

lanes: the headings traffic may drive in, relative to the tile as it lies unturned
    (rotation "S", its front facing south): "N" = towards its back, "S" = towards its
    front, "E", "W". The road network turns them with the cell's rotation, so turning a
    tile in the editor turns its lanes. One heading on an axis: a one-way lane (a lane
    tile: traffic drives towards its back). Both headings of an axis: the tile has no
    direction of its own on that axis (a crossing, plain asphalt, a zebra crossing, a
    tunnel tile that both carriageways use): the direction comes from the lanes along
    the same line, or else from driving on the right.
    Left out: nobody drives lanes over it (a pavement, a square).
road: kind of road, sets the speed limit: "straat", "hoofdweg", "tunnel" or "snelweg";
    left out (markings, crossings, plain asphalt) = that of the road it is part of.
speed: speed limit in km/h, instead of the one of the kind of road.
rise: metres the road surface rises towards the back of the tile (a ramp).
only: who may come on the tile: "auto" (also vans, trucks and buses), "brommer", "fiets",
    "voetganger", or for a track just "bus" or "tram"; left out = all four. A tile without
    a rule has no "traffic": nobody (water, a wall). A placed tile can differ from all of
    this (Build dock in the editor, road_network.gd LANE_CHOICES).
"""
import os

ALL = ["N", "E", "S", "W"]
ALONG = ["N", "S"]      # both ways along the tile: decided by the road around it
ONE_WAY = ["N"]         # a lane: traffic drives towards the back of the tile
CORNER_LANES = {"rechts": ["E"], "links": ["W"]}   # a square corner: out to that side

# who may come on a tile ("only")
EVERYONE = ["auto", "brommer", "fiets", "voetganger"]
ROAD = ["auto", "brommer", "fiets"]
MOTORWAY = ["auto"]
CYCLE_PATH = ["fiets", "brommer"]
FOOT_AND_CYCLE = ["voetganger", "fiets"]
FOOT = ["voetganger"]

# (base names, traffic); the first rule whose base name matches wins. A name ending in
# "*" matches every base name that starts with it.
_RULES = {
    "grond/weg": [
        (["kruising_vlak", "kruising_haaientanden", "kruising_stop"], {"lanes": ALL, "only": EVERYONE}),
        (["weg_vlak"], {"lanes": ALL, "only": ROAD}),
        (["zebrapad"], {"lanes": ALONG, "only": EVERYONE}),
        (["fietsoversteek", "drempel_asfalt", "drempel_plateau", "drempel_punaise",
          "verkeersdrempel"], {"lanes": ALONG, "only": ROAD}),
        (["rijstrook_stopstreep", "rijstrook_stop_tekst", "rijstrook_haaientanden", "rijstrook_pijl_*",
          "kruis_markering", "pianostrepen", "weg_kolk", "weg_putdeksel"], {"lanes": ONE_WAY, "only": ROAD}),
        (["rijstrook_bus", "rijstrook_bus_leeg", "rijstrook_bus_leeg_zonder_streep", "busstrook_halte", "drempel_bus"],
         {"lanes": ONE_WAY, "road": "straat", "only": ["bus"]}),
        (["busbaan_vrij"], {"only": ["bus"]}),
        (["rijstrook_*", "fietsstraat", "fietsstrook", "parkeerstrook", "parkeervak_gehandicapt",
          "straat_eenrichting", "straat_klinkers*", "straat_keien*", "weg_vlak_oud"],
         {"lanes": ONE_WAY, "road": "straat", "only": ROAD}),
        (["uitritconstructie"], {"only": EVERYONE}),
        (["berm", "middenberm_*", "middengeleider*"], {"only": FOOT}),
    ],
    "grond/stoep": [
        (["stoep_oprit", "stoep_inrit_breed", "stoep_goot_oprit"], {"only": EVERYONE}),
        (["*"], {"only": FOOT}),
    ],
    "grond/fietspad": [(["*"], {"only": CYCLE_PATH})],
    "grond/plein": [(["*"], {"only": FOOT_AND_CYCLE})],
    "grond/parkeren": [(["*"], {"only": EVERYONE})],
    "grond/natuur": [
        (["grindpad", "keienpad", "pad_*", "zandpad"], {"only": FOOT_AND_CYCLE}),
        (["*"], {"only": FOOT}),
    ],
    "grond/waterkant": [
        (["boulevard"], {"only": FOOT_AND_CYCLE}),
        (["aanlegplaats", "kadetrap", "strand*"], {"only": FOOT}),
    ],
    "grond/terrein": [(["trap_1m_fietsgoot"], {"only": FOOT_AND_CYCLE}), (["trap_1m*"], {"only": FOOT})],
    "grond/brug": [
        (["brug_dek_fietspad_*"], {"only": CYCLE_PATH}),
        (["brug_dek_stoep_rand", "loopbrug_open", "loopbrug_overdekt", "loopbrug_trap", "voetbrug_*"], {"only": FOOT}),
        (["brug_dek_klinker_*", "brug_dek_rijstrook_*", "brug_dek_weg_*", "ophaalbrug_dek"], {"only": ROAD}),
        (["brug_dek_tram_rand"], {"only": ["tram"]}),
    ],
    "grond/bocht": [
        (["fietspad_*"], {"only": CYCLE_PATH}),
        (["*"], {"only": ROAD}),
    ],
    "grond/tram": [
        (["tram_recht", "tram_bocht", "tram_kruising", "tram_t"], {"lanes": ALL, "only": EVERYONE}),
        (["tram_rijstrook_*"], {"lanes": ONE_WAY, "road": "straat", "only": ROAD}),
        (["tram_halte_perron", "tramhalte_middenperron"], {"only": FOOT}),
        (["trambaan_vrij", "trambaan_vrij_gras", "tram_gras_recht", "tram_klinker_recht"],
         {"lanes": ALONG, "only": ["tram"]}),
    ],
    "grond/snelweg": [
        (["snelweg_rijstrook", "snelweg_rijstrook_links", "snelweg_rijstrook_zonder_streep",
          "snelweg_rijstrook_links_zonder_streep", "snelweg_blokmarkering"],
         {"lanes": ONE_WAY, "road": "snelweg", "only": MOTORWAY}),
        (["afrit_*", "toerit_*", "snelweg_aansluiting", "snelweg_puntstuk", "snelweg_vluchtstrook"], {"only": MOTORWAY}),
    ],
    "grond/tunnel": [
        (["tunnel_toerit_d*", "tunnel_toerit_wand_d*", "tunnel_toerit_wand_rechts_d*"],
         {"lanes": ALONG, "road": "tunnel", "rise": 1.0, "only": MOTORWAY}),
        (["tunnel_rijstrook*", "tunnelbak_rijstrook_*"], {"lanes": ALONG, "road": "tunnel", "only": MOTORWAY}),
        (["fietstunnel_*", "tunnel_fiets*", "tunnelbak_fietspad*"], {"only": CYCLE_PATH}),
        (["bocht_*"], {"only": MOTORWAY}),
    ],
}


def _matches(base, pattern):
    return base.startswith(pattern[:-1]) if pattern.endswith("*") else base == pattern


def _corner_traffic(folder, straight, turn):
    """The traffic of a square road corner (tiles/ground_corners.py): that of its straight
    tile, with one lane: out at the side it turns to. Coming in at the front is what
    leads to it, so it needs no lane of its own."""
    traffic = tile_traffic(f"{folder}/{straight}")
    if traffic and "lanes" in traffic:
        traffic["lanes"] = list(CORNER_LANES[turn])
    return traffic


def tile_traffic(name):
    """The "traffic" metadata of tile path ``name`` (e.g. 'grond/weg/zebrapad'), or None."""
    folder, base = os.path.dirname(name), os.path.basename(name)
    straight, corner, turn = base.rpartition("_hoek_")
    if corner and turn in CORNER_LANES:
        return _corner_traffic(folder, straight, turn)
    for patterns, traffic in _RULES.get(folder, []):
        if any(_matches(base, pattern) for pattern in patterns):
            return dict(traffic)
    return None
