"""Nitro Overdrive '92 (Turbo Edition): de partituur van nitro_overdrive_92.json (de compositie in JSON van de componist,
letterlijk: elke maat en elk spoor zoals het JSON ze geeft (tools/muziek/json_bron.py). Elke rij hieronder is een rij
van de bron: zestien stappen (zestienden), '---' houdt de noot aan of is een rust, '===' stopt hem.

De intro van het spel is deze partituur, één keer gespeeld door de nagebouwde synth van de pagina (TRACKER
hieronder); de andere stukken worden uit deze maten afgeleid en klinken met dezelfde stemmen
(AFGELEIDE_KLANKEN).

Uit de pagina: de titel, het tempo (132 BPM), de toonsoort (E MIXOLYDIAN), de zes
kanalen, de secties (de soort bij de naam: intro, verse = thema, chorus = refrein, breakdown, final = finale),
de akkoordnamen (waar de pagina een maat geen akkoordnaam geeft, staat het akkoord dat zij daar speelt, met
haar naam als commentaar) en alle noten. Niet uit de pagina: de MOMENTEN van de intro-beelden.
"""
from notation import drum_steps, stabs, steps

TITEL = "Nitro Overdrive '92 (Turbo Edition)"
TEMPO = 132
TELLEN_PER_MAAT = 4
TOONSOORT = ("E", "mixolydisch")   # de pagina: E MIXOLYDIAN

# de pagina waar de intro uit gespeeld wordt (in deze map)
TRACKER = "nitro_overdrive_92.json"

# de zes kanalen van de pagina, elk in zijn eigen nagebouwde klank
KLANKEN = {
    "bas": "tracker_bas",           # kanaal 1
    "brass": "tracker_brass",       # kanaal 2
    "lead": "tracker_lead",         # kanaal 3
    "harmonie": "tracker_harmonie", # kanaal 4
    "arp": "tracker_arp",           # kanaal 5
    "drumstel": "tracker",          # kanaal 6
}

# de afgeleide stukken in de stemmen van de pagina: elke klank die ze gebruiken wordt een stem van de
# tracker, op de plek en het niveau van die klank; het drumstel dat van de tracker
AFGELEIDE_KLANKEN = {
    "fm_slapbas": "tracker_bas=fm_slapbas",
    "fm_housebas": "tracker_bas=fm_housebas",
    "fm_subbas": "tracker_bas=fm_subbas",
    "fm_lead_helder": "tracker_lead=fm_lead_helder",
    "fm_lead_snerpend": "tracker_lead=fm_lead_snerpend",
    "fm_lead_zuur": "tracker_lead=fm_lead_zuur",
    "fm_housebas_lead": "tracker_lead=fm_housebas_lead",
    "psg_lead_arp": "tracker_lead=psg_lead_arp",
    "psg_lead_fel": "tracker_lead=psg_lead_fel",
    "psg_lead": "tracker_lead=psg_lead",
    "overdrive_gitaar_solo": "tracker_lead=overdrive_gitaar_solo",
    "clean_gitaar_solo": "tracker_lead=clean_gitaar_solo",
    "psg_arp": "tracker_arp=psg_arp",
    "fm_klok": "tracker_harmonie=fm_klok",
    "fm_vibrafoon": "tracker_harmonie=fm_vibrafoon",
    "fm_fluit": "tracker_harmonie=fm_fluit",
    "synthwave_pad": "tracker_brass=synthwave_pad",
    "synth_brass": "tracker_brass=synth_brass",
    "fm_stoot_metaal": "tracker_brass=fm_stoot_metaal",
    "overdrive_gitaar": "tracker_brass=overdrive_gitaar",
    "clean_gitaar": "tracker_brass=clean_gitaar",
    "fm_piano": "tracker_brass=fm_piano",
    "fm_strijkers": "tracker_brass=fm_strijkers",
    "standaard": "tracker",
    "dmx": "tracker",
}

# waar de intro-beelden wisselen (scripts/ui/intro.gd): het logo op het thema, het verhaal een frase
# later, dan het refrein, de breakdown en de finale; de rust op de laatste maat
MOMENTEN = {"logo": 5, "verhaal": 9, "hoogtepunt": 13, "duel": 21, "crash": 25, "rust": (32, 1.0)}

BAS_A = steps("E1 E1 E2 E1 --- E1 E2 D2 E1 E1 G1 G#1 A1 B1 D2 B1")
ARP_A = steps("E4 B4 D5 E5 B4 D5 E4 B4 D5 E5 B4 D5 E4 B4 D5 B4")
DRUMS_A = drum_steps("KCK CHH OHH KCK SNR CHH OHH KCK CHH KCK OHH CHH SNR CHH KCK SNR")
BAS_B = steps("E1 E1 E2 E1 --- E1 F#2 E2 D1 D1 D2 D1 --- A1 B1 D2")
ARP_B = steps("D4 A4 E5 F#5 A4 E5 D4 A4 E5 F#5 A4 E5 D4 A4 F#5 A4")
DRUMS_B = drum_steps("KCK CHH OHH CHH SNR CHH OHH KCK KCK CHH OHH KCK SNR CHH OHH KCK")
BAS_C = steps("E1 E1 E2 E1 --- E1 C#2 B1 A1 A1 A2 A1 --- E1 F#1 G#1")
ARP_C = steps("C#4 E4 A4 C#5 E4 A4 C#4 E4 A4 C#5 E4 A4 C#4 E4 A4 E4")
DRUMS_C = drum_steps("KCK CHH OHH KCK SNR CHH OHH KCK CHH KCK OHH CHH SNR CHH OHH OHH")
BAS_D = steps("C1 C2 C1 C2 G1 C2 C1 C#1 D1 D2 D1 D2 A1 D2 B1 A1")
LEAD_A = steps("--- --- --- --- --- --- --- --- A4 --- B4 --- D5 --- E5 ---")
ARP_D = steps("C4 G4 B4 E5 G4 B4 C4 G4 D4 A4 B4 F#5 A4 B4 D4 A4")
DRUMS_D = drum_steps("KCK CHH KCK CHH SNR CHH KCK CHH KCK CHH SNR SNR TOM1 TOM2 TOM3 TOM4")
LEAD_B = steps("E4 --- G4 G#4 === --- B4 --- --- A4 --- G#4 --- --- E4 ---")
LEAD_C = steps("F#4 --- --- A4 --- --- F#4 --- E4 --- D4 --- --- --- E4 ---")
LEAD_D = steps("C#5 --- --- B4 --- --- A4 --- G#4 --- F#4 --- E4 --- F#4 ---")
LEAD_E = steps("G4 --- --- --- --- --- E4 --- A4 --- --- --- B4 --- D5 ---")
HARMONIE_A = steps("B3 --- D4 E4 === --- G#4 --- --- F#4 --- E4 --- --- B3 ---")
HARMONIE_B = steps("D4 --- --- F#4 --- --- D4 --- C#4 --- A3 --- --- --- C#4 ---")
HARMONIE_C = steps("A4 --- --- G#4 --- --- E4 --- E4 --- D4 --- C#4 --- D4 ---")
HARMONIE_D = steps("E4 --- --- --- --- --- C4 --- F#4 --- --- --- G4 --- B4 ---")
BAS_E = steps("A1 A2 A1 A2 E2 A1 A2 G#2 A1 A2 A1 A2 E1 F#1 G#1 A1")
LEAD_F = steps("C#5 --- --- E5 --- --- C#5 --- B4 --- A4 --- E4 --- A4 ---")
HARMONIE_E = steps("A4 --- --- C#5 --- --- A4 --- G#4 --- E4 --- C#4 --- E4 ---")
ARP_E = steps("A4 C#5 E5 B5 C#5 E5 A4 C#5 E5 B5 C#5 E5 A4 C#5 E5 C#5")
BAS_F = steps("B1 B2 B1 B2 F#2 B1 A1 B1 B1 B2 B1 B2 F#2 D#2 C#2 B1")
LEAD_G = steps("B4 --- --- C#5 --- --- D#5 --- F#5 --- --- E5 --- D#5 --- B4")
HARMONIE_F = steps("F#4 --- --- A4 --- --- B4 --- D#5 --- --- B4 --- B4 --- F#4")
ARP_F = steps("B4 E5 F#5 A5 E5 F#5 B4 E5 B4 D#5 F#5 A5 D#5 F#5 B4 D#5")
BAS_G = steps("E1 E2 E1 E2 B1 E2 D2 B1 C#1 C#2 C#1 C#2 G#1 C#2 B1 G#1")
LEAD_H = steps("G#5 --- --- E5 --- --- B4 --- E5 --- --- C#5 --- B4 --- A4")
HARMONIE_G = steps("E5 --- --- B4 --- --- G#4 --- C#5 --- --- G#4 --- G#4 --- E4")
ARP_G = steps("E4 B4 E5 G#5 B4 E5 E4 B4 C#4 G#4 B4 E5 G#4 B4 C#4 G#4")
LEAD_I = steps("G5 --- --- E5 --- C5 --- B4 A4 --- --- B4 --- D5 --- E5")
HARMONIE_H = steps("E5 --- --- C5 --- G4 --- G4 F#4 --- --- G4 --- A4 --- B4")
BAS_H = steps("E2 --- E2 --- G2 G#2 A2 --- B2 --- D3 --- E3 --- D3 B2")
LEAD_J = steps("E4 --- E4 --- G4 G#4 A4 --- B4 --- D5 --- E5 --- D5 B4")
HARMONIE_I = steps("B3 --- B3 --- D4 E4 E4 --- G#4 --- A4 --- B4 --- A4 G#4")
ARP_H = steps("E4 --- E4 --- G4 G#4 A4 --- B4 E5 D5 B4 E5 B4 G4 E4")
DRUMS_E = drum_steps("KCK --- KCK --- SNR --- OHH --- KCK --- KCK --- SNR --- OHH SNR")
BAS_I = steps("E2 --- E2 --- G2 G#2 A2 B2 C2 C2 C#2 C#2 D2 D2 D#2 D#2")
DRUMS_F = drum_steps("KCK KCK SNR KCK SNR SNR KCK SNR TOM1 TOM1 TOM2 TOM2 TOM3 TOM3 TOM4 SNR")
LEAD_K = steps("E5 --- G5 G#5 === --- B5 --- --- A5 --- G#5 --- --- E5 ---")
HARMONIE_J = steps("B4 --- D5 E5 === --- G#5 --- --- F#5 --- E5 --- --- B4 ---")
LEAD_L = steps("F#5 --- --- A5 --- --- F#5 --- E5 --- D5 --- --- --- E5 ---")
HARMONIE_K = steps("D5 --- --- F#5 --- --- D5 --- C#5 --- A4 --- --- --- C#5 ---")
LEAD_M = steps("C#5 --- E5 --- A5 --- G#5 --- F#5 --- E5 --- C#5 --- B4 ---")
HARMONIE_L = steps("A4 --- C#5 --- E5 --- E5 --- D5 --- C#5 --- A4 --- G#4 ---")
LEAD_N = steps("G5 --- --- E5 --- --- C5 --- A5 --- --- F#5 --- D5 --- B4")
HARMONIE_M = steps("E5 --- --- C5 --- --- G4 --- F#5 --- --- D5 --- A4 --- G4")
BAS_J = steps("C2 C3 C2 C3 C#2 C#3 C#2 C#3 D2 D3 D2 D3 D#2 D#3 D#2 D#3")
LEAD_O = steps("C5 --- C5 --- C#5 --- C#5 --- D5 --- D5 --- D#5 --- F#5 G#5")
HARMONIE_N = steps("G4 --- G4 --- G#4 --- G#4 --- A4 --- A4 --- A#4 --- D#5 E5")
ARP_I = steps("C4 G4 C5 G4 C#4 G#4 C#5 G#4 D4 A4 D5 A4 D#4 A#4 D#5 A#4")

SECTIES = [
    {"naam": "INTRO — IGNITION", "soort": "intro", "maten": (1, 4)},
    {"naam": "VERSE A — NIGHT HIGHWAY", "soort": "thema", "maten": (5, 12)},
    {"naam": "REDLINE CHORUS — BOOST", "soort": "refrein", "maten": (13, 20)},
    {"naam": "BREAKDOWN — ASPHALT RIFF", "soort": "breakdown", "maten": (21, 24)},
    {"naam": "FINAL OVERDRIVE — CLIMAX", "soort": "finale", "maten": (25, 32)},
]

MATEN = {
    # ------------------------------------------------------------------ 01: INTRO — IGNITION
    # E5 / E7sus4
    1: {"akkoord": "E7sus4",
        "bas": BAS_A,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+B3+D4+E4"),
        "arp": ARP_A,
        "drums": DRUMS_A},
    # Dadd9/E
    2: {"akkoord": "Dadd9/E",
        "bas": BAS_B,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+A3+D4+F#4"),
        "arp": ARP_B,
        "drums": DRUMS_B},
    # A/E
    3: {"akkoord": "A/E",
        "bas": BAS_C,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+A3+C#4+E4"),
        "arp": ARP_C,
        "drums": DRUMS_C},
    # Cmaj7 -> D6
    4: {"akkoord": "Cmaj7 D6",
        "bas": BAS_D,
        "brass": stabs("1 0 0 1 0 0 0 0 1 0 0 1 0 0 0 0", "C3+G3+B3+E4", "D3+A3+B3+F#4"),
        "lead": LEAD_A,
        "arp": ARP_D,
        "drums": DRUMS_D},
    # ------------------------------------------------------------------ 02: VERSE A — NIGHT HIGHWAY
    # E5 / E7sus4
    5: {"akkoord": "E7sus4",
        "bas": BAS_A,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+B3+D4+E4"),
        "lead": LEAD_B,
        "arp": ARP_A,
        "drums": DRUMS_A},
    # Dadd9/E
    6: {"akkoord": "Dadd9/E",
        "bas": BAS_B,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+A3+D4+F#4"),
        "lead": LEAD_C,
        "arp": ARP_B,
        "drums": DRUMS_B},
    # A/E
    7: {"akkoord": "A/E",
        "bas": BAS_C,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+A3+C#4+E4"),
        "lead": LEAD_D,
        "arp": ARP_C,
        "drums": DRUMS_C},
    # Cmaj7 -> D6
    8: {"akkoord": "Cmaj7 D6",
        "bas": BAS_D,
        "brass": stabs("1 0 0 1 0 0 0 0 1 0 0 1 0 0 0 0", "C3+G3+B3+E4", "D3+A3+B3+F#4"),
        "lead": LEAD_E,
        "arp": ARP_D,
        "drums": DRUMS_D},
    # E5 / E7sus4
    9: {"akkoord": "E7sus4",
        "bas": BAS_A,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+B3+D4+E4"),
        "lead": LEAD_B,
        "harmonie": HARMONIE_A,
        "arp": ARP_A,
        "drums": DRUMS_A},
    # Dadd9/E
    10: {"akkoord": "Dadd9/E",
         "bas": BAS_B,
         "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+A3+D4+F#4"),
         "lead": LEAD_C,
         "harmonie": HARMONIE_B,
         "arp": ARP_B,
         "drums": DRUMS_B},
    # A/E
    11: {"akkoord": "A/E",
         "bas": BAS_C,
         "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 1 0 0 1 0", "E3+A3+C#4+E4"),
         "lead": LEAD_D,
         "harmonie": HARMONIE_C,
         "arp": ARP_C,
         "drums": DRUMS_C},
    # Cmaj7 -> D6
    12: {"akkoord": "Cmaj7 D6",
         "bas": BAS_D,
         "brass": stabs("1 0 0 1 0 0 0 0 1 0 0 1 0 0 0 0", "C3+G3+B3+E4", "D3+A3+B3+F#4"),
         "lead": LEAD_E,
         "harmonie": HARMONIE_D,
         "arp": ARP_D,
         "drums": DRUMS_D},
    # ------------------------------------------------------------------ 03: REDLINE CHORUS — BOOST
    # Aadd9
    13: {"akkoord": "Aadd9",
         "bas": BAS_E,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "A3+C#4+E4+B4"),
         "lead": LEAD_F,
         "harmonie": HARMONIE_E,
         "arp": ARP_E,
         "drums": DRUMS_A},
    # B7sus4 -> B7
    14: {"akkoord": "B7sus4 B7",
         "bas": BAS_F,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "B3+E4+F#4+A4", "B3+D#4+F#4+A4"),
         "lead": LEAD_G,
         "harmonie": HARMONIE_F,
         "arp": ARP_F,
         "drums": DRUMS_B},
    # E5 -> C#m7
    15: {"akkoord": "E5 C#m7",
         "bas": BAS_G,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "E3+B3+E4+G#4", "C#3+G#3+B3+E4"),
         "lead": LEAD_H,
         "harmonie": HARMONIE_G,
         "arp": ARP_G,
         "drums": DRUMS_C},
    # Cmaj7 -> D6
    16: {"akkoord": "Cmaj7 D6",
         "bas": BAS_D,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "C3+G3+B3+E4", "D3+A3+B3+F#4"),
         "lead": LEAD_I,
         "harmonie": HARMONIE_H,
         "arp": ARP_D,
         "drums": DRUMS_D},
    # Aadd9
    17: {"akkoord": "Aadd9",
         "bas": BAS_E,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "A3+C#4+E4+B4"),
         "lead": LEAD_F,
         "harmonie": HARMONIE_E,
         "arp": ARP_E,
         "drums": DRUMS_A},
    # B7sus4 -> B7
    18: {"akkoord": "B7sus4 B7",
         "bas": BAS_F,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "B3+E4+F#4+A4", "B3+D#4+F#4+A4"),
         "lead": LEAD_G,
         "harmonie": HARMONIE_F,
         "arp": ARP_F,
         "drums": DRUMS_B},
    # E5 -> C#m7
    19: {"akkoord": "E5 C#m7",
         "bas": BAS_G,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "E3+B3+E4+G#4", "C#3+G#3+B3+E4"),
         "lead": LEAD_H,
         "harmonie": HARMONIE_G,
         "arp": ARP_G,
         "drums": DRUMS_C},
    # Cmaj7 -> D6
    20: {"akkoord": "Cmaj7 D6",
         "bas": BAS_D,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "C3+G3+B3+E4", "D3+A3+B3+F#4"),
         "lead": LEAD_I,
         "harmonie": HARMONIE_H,
         "arp": ARP_D,
         "drums": DRUMS_D},
    # ------------------------------------------------------------------ 04: BREAKDOWN — ASPHALT RIFF
    # E Mixo Blues Riff
    21: {"akkoord": "E7",
         "bas": BAS_H,
         "brass": stabs("1 0 1 0 1 1 1 0 1 0 1 0 1 0 0 0", "E3+G#3+B3+D4"),
         "lead": LEAD_J,
         "harmonie": HARMONIE_I,
         "arp": ARP_H,
         "drums": DRUMS_E},
    # E Mixo Blues Riff
    22: {"akkoord": "E7",
         "bas": BAS_H,
         "brass": stabs("1 0 1 0 1 1 1 0 1 0 1 0 1 0 0 0", "E3+G#3+B3+D4"),
         "lead": LEAD_J,
         "harmonie": HARMONIE_I,
         "arp": ARP_H,
         "drums": DRUMS_E},
    # E Mixo Blues Riff
    23: {"akkoord": "E7",
         "bas": BAS_H,
         "brass": stabs("1 0 1 0 1 1 1 0 1 0 1 0 1 0 0 0", "E3+G#3+B3+D4"),
         "lead": LEAD_J,
         "harmonie": HARMONIE_I,
         "arp": ARP_H,
         "drums": DRUMS_E},
    # E7#9 -> BUILD
    24: {"akkoord": "E7",
         "bas": BAS_I,
         "brass": stabs("1 0 1 0 1 1 1 0 1 0 1 0 1 0 0 0", "E3+G#3+B3+D4"),
         "lead": LEAD_J,
         "harmonie": HARMONIE_I,
         "arp": ARP_H,
         "drums": DRUMS_F},
    # ------------------------------------------------------------------ 05: FINAL OVERDRIVE — CLIMAX
    # E7sus4 (Overdrive)
    25: {"akkoord": "E7sus4",
         "bas": BAS_A,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 1 0 1", "E3+B3+D4+E4"),
         "lead": LEAD_K,
         "harmonie": HARMONIE_J,
         "arp": ARP_A,
         "drums": DRUMS_A},
    # Dadd9/E (Overdrive)
    26: {"akkoord": "Dadd9/E",
         "bas": BAS_B,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 1 0 1", "E3+A3+D4+F#4"),
         "lead": LEAD_L,
         "harmonie": HARMONIE_K,
         "arp": ARP_B,
         "drums": DRUMS_B},
    # A/E (Overdrive)
    27: {"akkoord": "A/E",
         "bas": BAS_C,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 1 0 1", "E3+A3+C#4+E4"),
         "lead": LEAD_M,
         "harmonie": HARMONIE_L,
         "arp": ARP_C,
         "drums": DRUMS_C},
    # Cmaj7 -> D6
    28: {"akkoord": "Cmaj7 D6",
         "bas": BAS_D,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 1 0 1", "C3+G3+B3+E4", "D3+A3+B3+F#4"),
         "lead": LEAD_N,
         "harmonie": HARMONIE_M,
         "arp": ARP_D,
         "drums": DRUMS_D},
    # E7sus4 (Overdrive)
    29: {"akkoord": "E7sus4",
         "bas": BAS_A,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 1 0 1", "E3+B3+D4+E4"),
         "lead": LEAD_K,
         "harmonie": HARMONIE_J,
         "arp": ARP_A,
         "drums": DRUMS_A},
    # Dadd9/E (Overdrive)
    30: {"akkoord": "Dadd9/E",
         "bas": BAS_B,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 1 0 1", "E3+A3+D4+F#4"),
         "lead": LEAD_L,
         "harmonie": HARMONIE_K,
         "arp": ARP_B,
         "drums": DRUMS_B},
    # A/E (Overdrive)
    31: {"akkoord": "A/E",
         "bas": BAS_C,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 1 0 1", "E3+A3+C#4+E4"),
         "lead": LEAD_M,
         "harmonie": HARMONIE_L,
         "arp": ARP_C,
         "drums": DRUMS_C},
    # C5 -> C#5 -> D5 -> D#5
    32: {"akkoord": "C5 C#5 D5 D#5",
         "bas": BAS_J,
         "brass": stabs("1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 1", "C3+G3+C4+E4", "C#3+G#3+C#4+F4", "D3+A3+D4+F#4", "D#3+A#3+D#4+G4"),
         "lead": LEAD_O,
         "harmonie": HARMONIE_N,
         "arp": ARP_I,
         "drums": DRUMS_F},
}
