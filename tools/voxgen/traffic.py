"""Which ground tiles vehicles drive on, written as "traffic" into each tile's .tile.json
(vox.write_metadata) and read by Godot's road network (scripts/world/road_network.gd,
through the "traffic" metadata of the ground MeshLibrary, library_builder.gd).

    "traffic": {"lanes": ["N"], "road": "straat", "rise": 1.0, "only": ["bus"]}

lanes: the headings traffic may drive in, relative to the tile as it lies unturned
    (rotation "S", its front facing south): "N" = towards its back, "S" = towards its
    front, "E", "W". The road network turns them with the cell's rotation, so turning a
    tile in the editor turns its lanes. One heading on an axis: a one-way lane (a lane
    tile: traffic drives towards its back). Both headings of an axis: the tile has no
    direction of its own on that axis (a crossing, plain asphalt, a zebra crossing, a
    tunnel tile that both carriageways use): the direction comes from the lanes along
    the same line, or else from driving on the right.
road: kind of road, sets the speed limit: "straat", "hoofdweg", "tunnel" or "snelweg";
    left out (markings, crossings, plain asphalt) = that of the road it is part of.
rise: metres the road surface rises towards the back of the tile (a ramp).
only: vehicle kinds that may use the lanes (a bus lane, tram track); left out = all.
"""
import os

ALL = ["N", "E", "S", "W"]
ALONG = ["N", "S"]      # both ways along the tile: decided by the road around it
ONE_WAY = ["N"]         # a lane: traffic drives towards the back of the tile

# (base names, traffic); the first rule whose base name matches wins. A name ending in
# "*" matches every base name that starts with it.
_RULES = {
    "grond/weg": [
        (["kruising_vlak", "kruising_haaientanden", "kruising_stop", "weg_vlak"], {"lanes": ALL}),
        (["zebrapad", "fietsoversteek", "drempel_asfalt", "drempel_plateau", "drempel_punaise",
          "verkeersdrempel"], {"lanes": ALONG}),
        (["rijstrook_stopstreep", "rijstrook_stop_tekst", "rijstrook_haaientanden", "rijstrook_pijl_*",
          "kruis_markering", "pianostrepen", "weg_kolk", "weg_putdeksel"], {"lanes": ONE_WAY}),
        (["rijstrook_bus", "rijstrook_bus_leeg", "busstrook_halte", "drempel_bus"],
         {"lanes": ONE_WAY, "road": "straat", "only": ["bus"]}),
        (["rijstrook_*", "fietsstraat", "fietsstrook", "parkeerstrook", "parkeervak_gehandicapt",
          "straat_eenrichting", "straat_klinkers*", "straat_keien*", "weg_vlak_oud"],
         {"lanes": ONE_WAY, "road": "straat"}),
    ],
    "grond/tram": [
        (["tram_recht", "tram_bocht", "tram_kruising", "tram_t"], {"lanes": ALL}),
        (["tram_rijstrook_*"], {"lanes": ONE_WAY, "road": "straat"}),
        (["trambaan_vrij", "trambaan_vrij_gras", "tram_gras_recht", "tram_klinker_recht"],
         {"lanes": ALONG, "only": ["tram"]}),
    ],
    "grond/snelweg": [
        (["snelweg_rijstrook", "snelweg_rijstrook_links", "snelweg_blokmarkering"],
         {"lanes": ONE_WAY, "road": "snelweg"}),
    ],
    "grond/tunnel": [
        (["tunnel_toerit_d*", "tunnel_toerit_wand_d*", "tunnel_toerit_wand_rechts_d*"],
         {"lanes": ALONG, "road": "tunnel", "rise": 1.0}),
        (["tunnel_rijstrook*", "tunnelbak_rijstrook_*"], {"lanes": ALONG, "road": "tunnel"}),
    ],
}


def _matches(base, pattern):
    return base.startswith(pattern[:-1]) if pattern.endswith("*") else base == pattern


def tile_traffic(name):
    """The "traffic" metadata of tile path ``name`` (e.g. 'grond/weg/zebrapad'), or None."""
    folder, base = os.path.dirname(name), os.path.basename(name)
    for patterns, traffic in _RULES.get(folder, []):
        if any(_matches(base, pattern) for pattern in patterns):
            return dict(traffic)
    return None
