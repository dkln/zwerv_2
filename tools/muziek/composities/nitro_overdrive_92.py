"""Nitro Overdrive: omgezet uit het VGM-bestand nitro_overdrive_92.vgm (het registerlog van de Mega
Drive-geluidschips: YM2612 (7670454 Hz) en SN76489 (3579545 Hz)) door tools/muziek/vgm.py, maat voor
maat in de notatie van tools/muziek/notation.py. De intro van het spel is het VGM zelf, door de
nabootsing van de chips gespeeld (tools/muziek/chip.py; VGM hieronder): exacte frequenties, de
patches en de volumes uit het registerlog. De maten hieronder zijn dezelfde noten op het raster
(toonhoogte uit F-number en blok naar de dichtstbijzijnde noot, begin en lengte uit key-on en
key-off): daar worden de andere stukken van afgeleid, in de stemmen van het VGM (AFGELEIDE_KLANKEN).

Bron: 58.18 s (2565632 samples van 1/44100 s), geen luspunt.
Raster: een stap is 5011.0 samples, 4 stappen per tel: 132 BPM, 4 tellen per maat, 32 maten (de
noten liggen gemiddeld 0.000 stap van het raster).
De 92 in de bestandsnaam is niet het tempo: geen telverdeling van het raster komt daarop uit.

Partijen (kanaal -> partij; de partij klinkt met de patch van dat kanaal, op de plek in de mix van
de klank die bij de patch past):
- bas: fm1: algoritme 0, feedback 6, MUL 1/1/1/1, TL 22/22/22/0, AR 31/31/31/31: hoge feedback, hard
  gestuurde modulatoren (een rauwe bas) -> de plek van fm_housebas
- lead: fm3: algoritme 4, feedback 7, MUL 1/1/1/1, TL 22/22/22/0, AR 31/31/31/31: feedback bijna op
  zijn hoogst (een rauwe lead) -> de plek van fm_lead_zuur
- drums: hihat (PSG-ruis, 225x), snare (PSG-ruis, 86x)

Afgeleid uit de noten (het VGM zegt ze niet): de toonsoort, het akkoord van elke maat, de secties
met hun soort en de MOMENTEN van de intro.

Let op: fm1: 301 van de 467 noten hebben het hoogste F-number (2047); de schrijver van het VGM heeft
de toonhoogte daar waarschijnlijk afgekapt (de noot is overgenomen zoals de chip hem speelt; hij
telt niet mee voor de toonsoort en licht voor de akkoorden).
"""
from notation import drums, notes

TITEL = "Nitro Overdrive"
TEMPO = 132
TELLEN_PER_MAAT = 4
TOONSOORT = ("E", "majeur")

# het VGM waar de intro letterlijk uit gespeeld wordt (in deze map)
VGM = "nitro_overdrive_92.vgm"

# elke partij met de patch van haar eigen kanaal ("vgm:<bestand>:<kanaal>=<klank>": even hard en op
# dezelfde plek in de mix als die klank)
KLANKEN = {
    "bas": "vgm:nitro_overdrive_92.vgm:fm1=fm_housebas",   # fm1
    "lead": "vgm:nitro_overdrive_92.vgm:fm3=fm_lead_zuur",   # fm3
}

# de afgeleide stukken in de stemmen van het VGM: elke klank die ze gebruiken wordt de patch van een
# kanaal van het VGM (op de plek en het niveau van die klank), het drumstel dat van het VGM (snare en
# hi-hat de PSG-ruis van het VGM; kick, toms, clap, open hi-hat en crash daarvan afgeleid)
# - lead: fm3 (het kanaal van de melodie)
# - bas: fm1 (het kanaal van de bas)
# - akkoord: fm2 (een patch die het VGM zet maar niet speelt (de meeste dragers))
# - zacht: fm4 (een patch die het VGM zet maar niet speelt (de minste feedback))
AFGELEIDE_KLANKEN = {
    "fm_lead_helder": "vgm:nitro_overdrive_92.vgm:fm3=fm_lead_helder",
    "fm_lead_snerpend": "vgm:nitro_overdrive_92.vgm:fm3=fm_lead_snerpend",
    "fm_lead_zuur": "vgm:nitro_overdrive_92.vgm:fm3=fm_lead_zuur",
    "fm_housebas_lead": "vgm:nitro_overdrive_92.vgm:fm3=fm_housebas_lead",
    "psg_lead_arp": "vgm:nitro_overdrive_92.vgm:fm3=psg_lead_arp",
    "psg_lead_fel": "vgm:nitro_overdrive_92.vgm:fm3=psg_lead_fel",
    "psg_lead": "vgm:nitro_overdrive_92.vgm:fm3=psg_lead",
    "overdrive_gitaar_solo": "vgm:nitro_overdrive_92.vgm:fm3=overdrive_gitaar_solo",
    "clean_gitaar_solo": "vgm:nitro_overdrive_92.vgm:fm3=clean_gitaar_solo",
    "fm_slapbas": "vgm:nitro_overdrive_92.vgm:fm1=fm_slapbas",
    "fm_housebas": "vgm:nitro_overdrive_92.vgm:fm1=fm_housebas",
    "fm_subbas": "vgm:nitro_overdrive_92.vgm:fm1=fm_subbas",
    "synthwave_pad": "vgm:nitro_overdrive_92.vgm:fm2=synthwave_pad",
    "synth_brass": "vgm:nitro_overdrive_92.vgm:fm2=synth_brass",
    "fm_stoot_metaal": "vgm:nitro_overdrive_92.vgm:fm2=fm_stoot_metaal",
    "overdrive_gitaar": "vgm:nitro_overdrive_92.vgm:fm2=overdrive_gitaar",
    "clean_gitaar": "vgm:nitro_overdrive_92.vgm:fm2=clean_gitaar",
    "fm_piano": "vgm:nitro_overdrive_92.vgm:fm2=fm_piano",
    "fm_strijkers": "vgm:nitro_overdrive_92.vgm:fm2=fm_strijkers",
    "psg_arp": "vgm:nitro_overdrive_92.vgm:fm4=psg_arp",
    "fm_klok": "vgm:nitro_overdrive_92.vgm:fm4=fm_klok",
    "fm_vibrafoon": "vgm:nitro_overdrive_92.vgm:fm4=fm_vibrafoon",
    "fm_fluit": "vgm:nitro_overdrive_92.vgm:fm4=fm_fluit",
    "standaard": "vgm:nitro_overdrive_92.vgm",
    "dmx": "vgm:nitro_overdrive_92.vgm",
}

# waar de intro-beelden wisselen (scripts/ui/intro.gd): het logo op het thema, het verhaal een
# frase later, dan het refrein, de breakdown en de finale; de rust op de laatste maat
MOMENTEN = {"logo": 5, "verhaal": 9, "hoogtepunt": 13, "duel": 21, "crash": 25, "rust": (32, 1.0)}

# de maten hieronder staan in het octaaf van het VGM, en zo klinkt de intro; alleen in de afgeleide
# stukken liggen deze partijen zoveel octaven hoger (+) of lager (-), in het register waar die
# stukken op rekenen (de melodie rond octaaf 5, de bas rond octaaf 2)
AFGELEID_OCTAAF = {"lead": 2}

BAS_A = notes("1 G#2 0.25, 1.25 G#2 0.25, 1.5 E3 0.25, 1.75 G#2 0.5, 2.25 G#2 0.25, 2.5 E3 0.25, "
              "2.75 D3 0.25, 3 G#2 0.25, 3.25 G#2 0.25, 3.5 G#2 0.25, 3.75 G#2 0.25, 4 G#2 0.25, "
              "4.25 G#2 0.25, 4.5 D3 0.25, 4.75 G#2 0.25")   # maat 1, 5, 9, 25, 29
DRUMS_A = drums(hihat="1.25 1.5 2.25 2.5 3 3.5 3.75 4.25", snare="2 4 4.75")   # maat 1, 5, 9, 13, 17, 25, 29
BAS_B = notes("1 G#2 0.25, 1.25 G#2 0.25, 1.5 E3 0.25, 1.75 G#2 0.5, 2.25 G#2 0.25, 2.5 F#3 0.25, "
              "2.75 E3 0.25, 3 G#2 0.25, 3.25 G#2 0.25, 3.5 D3 0.25, 3.75 G#2 0.5, 4.25 G#2 0.25, "
              "4.5 G#2 0.25, 4.75 D3 0.25")   # maat 2, 6, 10, 26, 30
DRUMS_B = drums(hihat="1.25 1.5 1.75 2.25 2.5 3.25 3.5 4.25 4.5", snare="2 4")   # maat 2, 6, 10, 14, 18, 26, 30
BAS_C = notes("1 G#2 0.25, 1.25 G#2 0.25, 1.5 E3 0.25, 1.75 G#2 0.5, 2.25 G#2 0.25, 2.5 C#3 0.25, "
              "2.75 G#2 0.25, 3 G#2 0.25, 3.25 G#2 0.25, 3.5 G#3 0.25, 3.75 G#2 0.5, 4.25 G#2 0.25, "
              "4.5 G#2 0.25, 4.75 G#2 0.25")   # maat 3, 7, 11, 27, 31
DRUMS_C = drums(hihat="1.25 1.5 2.25 2.5 3 3.5 3.75 4.25 4.5 4.75", snare="2 4")   # maat 3, 7, 11, 15, 19, 27, 31
BAS_D = notes("1 G#2 0.25, 1.25 C3 0.25, 1.5 G#2 0.25, 1.75 C3 0.25, 2 G#2 0.25, 2.25 C3 0.25, 2.5 G#2 0.25, "
              "2.75 G#2 0.25, 3 G#2 0.25, 3.25 D3 0.25, 3.5 G#2 0.25, 3.75 D3 0.25, 4 G#2 0.25, 4.25 D3 0.25, "
              "4.5 G#2 0.25, 4.75 G#2 0.25")   # maat 4, 8, 12, 16, 20, 28
DRUMS_D = drums(hihat="1.25 1.75 2.25 2.75 3.25", snare="2 3.5 3.75")   # maat 4, 8, 12, 16, 20, 28
LEAD_A = notes("1 E3 0.5, 1.5 G3 0.25, 1.75 G#3 0.25, 2.5 B3 0.75, 3.25 A3 0.5, 3.75 G#3 0.75, 4.5 E3 0.5")   # maat 5, 9, 25, 29
LEAD_B = notes("1 F#3 0.75, 1.75 A3 0.75, 2.5 F#3 0.5, 3 E3 0.5, 3.5 D3 1, 4.5 E3 0.5")   # maat 6, 10, 26, 30
LEAD_C = notes("1 C#3 0.75, 1.75 B3 0.75, 2.5 A3 0.5, 3 G#3 0.5, 3.5 F#3 0.5, 4 E3 0.5, 4.5 F#3 0.5")   # maat 7, 11
LEAD_D = notes("1 G3 1.5, 2.5 E3 0.5, 3 A3 1, 4 B3 0.5, 4.5 D3 0.5")   # maat 8, 12
BAS_E = notes("1 G#2 0.25, 1.25 G#3 0.25, 1.5 G#2 0.25, 1.75 G#3 0.25, 2 E3 0.25, 2.25 G#2 0.25, "
              "2.5 G#3 0.25, 2.75 G#3 0.25, 3 G#2 0.25, 3.25 G#3 0.25, 3.5 G#2 0.25, 3.75 G#3 0.25, "
              "4 G#2 0.25, 4.25 G#2 0.25, 4.5 G#2 0.25, 4.75 G#2 0.25")   # maat 13, 17
LEAD_E = notes("1 C#3 0.75, 1.75 E3 0.75, 2.5 C#3 0.5, 3 B3 0.5, 3.5 A3 0.5, 4 E3 0.5, 4.5 A3 0.5")   # maat 13, 17
BAS_F = notes("1 G#2 0.25, 1.25 G#3 0.25, 1.5 G#2 0.25, 1.75 G#3 0.25, 2 F#3 0.25, 2.25 G#2 0.25, "
              "2.5 G#2 0.25, 2.75 G#2 0.25, 3 G#2 0.25, 3.25 G#3 0.25, 3.5 G#2 0.25, 3.75 G#3 0.25, "
              "4 F#3 0.25, 4.25 D#3 0.25, 4.5 C#3 0.25, 4.75 G#2 0.25")   # maat 14, 18
LEAD_F = notes("1 B3 0.75, 1.75 C#3 0.75, 2.5 D#3 0.5, 3 F#3 0.75, 3.75 E3 0.5, 4.25 D#3 0.5, 4.75 B3 0.25")   # maat 14, 18
BAS_G = notes("1 G#2 0.25, 1.25 E3 0.25, 1.5 G#2 0.25, 1.75 E3 0.25, 2 G#2 0.25, 2.25 E3 0.25, 2.5 D3 0.25, "
              "2.75 G#2 0.25, 3 G#2 0.25, 3.25 C#3 0.25, 3.5 G#2 0.25, 3.75 C#3 0.25, 4 G#2 0.25, "
              "4.25 C#3 0.25, 4.5 G#2 0.25, 4.75 G#2 0.25")   # maat 15, 19
LEAD_G = notes("1 G#3 0.75, 1.75 E3 0.75, 2.5 B3 0.5, 3 E3 0.75, 3.75 C#3 0.5, 4.25 B3 0.5, 4.75 A3 0.25")   # maat 15, 19
LEAD_H = notes("1 G3 0.75, 1.75 E3 0.5, 2.25 C3 0.5, 2.75 B3 0.25, 3 A3 0.75, 3.75 B3 0.5, 4.25 D3 0.5, "
               "4.75 E3 0.25")   # maat 16, 20
BAS_H = notes("1 E3 0.5, 1.5 E3 0.5, 2 G3 0.25, 2.25 G#3 0.25, 2.5 G#3 0.5, 3 G#3 0.5, 3.5 D3 0.5, 4 E3 0.5, "
              "4.5 D3 0.25, 4.75 G#3 0.25")   # maat 21, 22, 23
LEAD_I = notes("1 E3 0.5, 1.5 E3 0.5, 2 G3 0.25, 2.25 G#3 0.25, 2.5 A3 0.5, 3 B3 0.5, 3.5 D3 0.5, 4 E3 0.5, "
               "4.5 D3 0.25, 4.75 B3 0.25")   # maat 21, 22, 23, 24
DRUMS_E = drums(hihat="2.5 4.5", snare="2 4 4.75")   # maat 21, 22, 23
DRUMS_F = drums(snare="1.5 2 2.25 2.75 4.75")   # maat 24, 32
LEAD_J = notes("1 C#3 0.5, 1.5 E3 0.5, 2 A3 0.5, 2.5 G#3 0.5, 3 F#3 0.5, 3.5 E3 0.5, 4 C#3 0.5, 4.5 B3 0.5")   # maat 27, 31

SECTIES = [
    {"naam": "Intro", "soort": "intro", "maten": (1, 4)},
    {"naam": "Thema", "soort": "thema", "maten": (5, 12), "standaard": {"drums": DRUMS_A}},
    {"naam": "Refrein", "soort": "refrein", "maten": (13, 20), "standaard": {"drums": DRUMS_A}},
    {"naam": "Breakdown", "soort": "breakdown", "maten": (21, 24), "standaard": {"drums": DRUMS_E}},
    {"naam": "Finale", "soort": "finale", "maten": (25, 32), "standaard": {"drums": DRUMS_A}},
]

MATEN = {
    # ------------------------------------------------------------------ Intro (intro)
    1: {"akkoord": "E7",
        "bas": BAS_A,
        "drums": DRUMS_A},
    2: {"akkoord": "E7",
        "bas": BAS_B,
        "drums": DRUMS_B},
    3: {"akkoord": "C#m",
        "bas": BAS_C,
        "drums": DRUMS_C},
    4: {"akkoord": "G# E7",
        "bas": BAS_D,
        "lead": notes("3 A3 0.5, 3.5 B3 0.5, 4 D3 0.5, 4.5 E3 0.5"),
        "drums": DRUMS_D},
    # ------------------------------------------------------------------ Thema (thema)
    5: {"akkoord": "E7",
        "bas": BAS_A,
        "lead": LEAD_A},
    6: {"akkoord": "E7",
        "bas": BAS_B,
        "lead": LEAD_B,
        "drums": DRUMS_B},
    7: {"akkoord": "E",
        "bas": BAS_C,
        "lead": LEAD_C,
        "drums": DRUMS_C},
    8: {"akkoord": "C D5",
        "bas": BAS_D,
        "lead": LEAD_D,
        "drums": DRUMS_D},
    9: {"akkoord": "E7",
        "bas": BAS_A,
        "lead": LEAD_A},
    10: {"akkoord": "E7",
         "bas": BAS_B,
         "lead": LEAD_B,
         "drums": DRUMS_B},
    11: {"akkoord": "E",
         "bas": BAS_C,
         "lead": LEAD_C,
         "drums": DRUMS_C},
    12: {"akkoord": "C D5",
         "bas": BAS_D,
         "lead": LEAD_D,
         "drums": DRUMS_D},
    # ------------------------------------------------------------------ Refrein (refrein)
    13: {"akkoord": "Amaj7",
         "bas": BAS_E,
         "lead": LEAD_E},
    14: {"akkoord": "G#m7",
         "bas": BAS_F,
         "lead": LEAD_F,
         "drums": DRUMS_B},
    15: {"akkoord": "E7 C#m7",
         "bas": BAS_G,
         "lead": LEAD_G,
         "drums": DRUMS_C},
    16: {"akkoord": "Cmaj7 D5",
         "bas": BAS_D,
         "lead": LEAD_H,
         "drums": DRUMS_D},
    17: {"akkoord": "Amaj7",
         "bas": BAS_E,
         "lead": LEAD_E},
    18: {"akkoord": "G#m7",
         "bas": BAS_F,
         "lead": LEAD_F,
         "drums": DRUMS_B},
    19: {"akkoord": "E7 C#m7",
         "bas": BAS_G,
         "lead": LEAD_G,
         "drums": DRUMS_C},
    20: {"akkoord": "Cmaj7 D5",
         "bas": BAS_D,
         "lead": LEAD_H,
         "drums": DRUMS_D},
    # ------------------------------------------------------------------ Breakdown (breakdown)
    21: {"akkoord": "E7",
         "bas": BAS_H,
         "lead": LEAD_I},
    22: {"akkoord": "E7",
         "bas": BAS_H,
         "lead": LEAD_I},
    23: {"akkoord": "E7",
         "bas": BAS_H,
         "lead": LEAD_I},
    24: {"akkoord": "E7",
         "bas": notes("1 E3 0.5, 1.5 E3 0.5, 2 G3 0.25, 2.25 G#3 0.25, 2.5 G#3 0.25, 2.75 G#3 0.25, 3 C3 0.25, "
                     "3.25 C3 0.25, 3.5 C#3 0.25, 3.75 C#3 0.25, 4 D3 0.25, 4.25 D3 0.25, 4.5 D#3 0.25, "
                     "4.75 D#3 0.25"),
         "lead": LEAD_I,
         "drums": DRUMS_F},
    # ------------------------------------------------------------------ Finale (finale)
    25: {"akkoord": "E7",
         "bas": BAS_A,
         "lead": LEAD_A},
    26: {"akkoord": "E7",
         "bas": BAS_B,
         "lead": LEAD_B,
         "drums": DRUMS_B},
    27: {"akkoord": "E",
         "bas": BAS_C,
         "lead": LEAD_J,
         "drums": DRUMS_C},
    28: {"akkoord": "C D",
         "bas": BAS_D,
         "lead": notes("1 G3 0.75, 1.75 E3 0.75, 2.5 C3 0.5, 3 A3 0.75, 3.75 F#3 0.5, 4.25 D3 0.5, 4.75 B3 0.25"),
         "drums": DRUMS_D},
    29: {"akkoord": "E7",
         "bas": BAS_A,
         "lead": LEAD_A},
    30: {"akkoord": "E7",
         "bas": BAS_B,
         "lead": LEAD_B,
         "drums": DRUMS_B},
    31: {"akkoord": "E",
         "bas": BAS_C,
         "lead": LEAD_J,
         "drums": DRUMS_C},
    32: {"akkoord": "C#maj7 D#maj7",
         "bas": notes("1 C3 0.25, 1.25 C3 0.25, 1.5 C3 0.25, 1.75 C3 0.25, 2 C#3 0.25, 2.25 C#3 0.25, "
                     "2.5 C#3 0.25, 2.75 C#3 0.25, 3 D3 0.25, 3.25 D3 0.25, 3.5 D3 0.25, 3.75 D3 0.25, "
                     "4 D#3 0.25, 4.25 D#3 0.25, 4.5 D#3 0.25, 4.75 D#3 0.25"),
         "lead": notes("1 C3 0.5, 1.5 C3 0.5, 2 C#3 0.5, 2.5 C#3 0.5, 3 D3 0.5, 3.5 D3 0.5, 4 D#3 0.5, "
                      "4.5 F#3 0.25, 4.75 G#3 0.25"),
         "drums": DRUMS_F},
}
