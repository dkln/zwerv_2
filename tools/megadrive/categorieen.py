"""Where a sound of assets/audio/geluiden/ goes: a folder per category, by its name, the same
as scripts/audio/sound_files.gd (keep the two in step; tests/unit/audio/test_sound_files.gd
checks every file is where that says)."""
import os

CATEGORIES = [
    ("pijn_", "mensen"), ("lichaam_klap", "mensen"), ("klap", "mensen"), ("schop", "mensen"), ("springen", "mensen"),
    ("plons", "mensen"), ("overgeven", "mensen"),
    ("ov_", "ov"), ("poortje_", "ov"), ("conducteur_", "ov"), ("omroep_", "ov"),
    ("deur_", "binnen"), ("lift_", "binnen"), ("kassa_", "binnen"), ("winkel_", "binnen"),
    ("explosie", "effecten"), ("brand_loop", "effecten"),
    ("ambulance_", "voertuigen"), ("auto_", "voertuigen"), ("brommer_", "voertuigen"), ("bus_", "voertuigen"),
    ("fiets_", "voertuigen"), ("helikopter_", "voertuigen"), ("politie_", "voertuigen"), ("brandweer_", "voertuigen"),
    ("scootmobiel_", "voertuigen"), ("sirene_", "voertuigen"), ("tram_", "voertuigen"), ("trein_", "voertuigen"),
]
VOICES = ["oude_man", "rasperig", "vrouw", "man"]


def category_of(name: str) -> str:
    if name.startswith("brabbel_"):
        for voice in VOICES:
            if name.startswith("brabbel_" + voice + "_"):
                return os.path.join("brabbel", voice)
        return "brabbel"
    for prefix, folder in CATEGORIES:
        if name.startswith(prefix):
            return folder
    return "overig"


def folder_for(root: str, name: str) -> str:
    """The folder under `root` (assets/audio/geluiden) where the sound `name` belongs."""
    return os.path.join(root, category_of(name))
