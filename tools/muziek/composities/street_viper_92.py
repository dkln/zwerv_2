"""Street Viper '92: de partituur van street_viper_92.json (de compositie in JSON van de componist,
letterlijk: elke maat en elk spoor zoals het JSON ze geeft (tools/muziek/json_bron.py). Elke rij hieronder is een rij
van de bron: zestien stappen (zestienden), '---' houdt de noot aan of is een rust, '===' stopt hem.

De intro van het spel is deze partituur, één keer gespeeld door de nagebouwde synth van de pagina (TRACKER
hieronder); de andere stukken worden uit deze maten afgeleid en klinken met dezelfde stemmen
(AFGELEIDE_KLANKEN).

Uit de pagina: de titel, het tempo (128 BPM), de toonsoort (E MIXOLYDIAN), de zes
kanalen, de secties (de soort bij de naam: intro, verse = thema, chorus = refrein, breakdown, final = finale),
de akkoordnamen (waar de pagina een maat geen akkoordnaam geeft, staat het akkoord dat zij daar speelt, met
haar naam als commentaar) en alle noten. Niet uit de pagina: de MOMENTEN van de intro-beelden.
"""
from notation import drum_steps, stabs, steps

TITEL = "Street Viper '92"
TEMPO = 128
TELLEN_PER_MAAT = 4
TOONSOORT = ("E", "mixolydisch")   # de pagina: E MIXOLYDIAN

# de pagina waar de intro uit gespeeld wordt (in deze map)
TRACKER = "street_viper_92.json"

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
MOMENTEN = {"logo": 5, "verhaal": 7, "hoogtepunt": 9, "duel": 12, "crash": 14, "rust": (16, 1.0)}

BAS_A = steps("E2 === E2 E3 === E2 D2 === E2 === G2 G#2 A2 === B2 D3")
ARP_A = steps("E5 === B4 === E5 === G#4 === A4 === B4 === D5 === B4 ===")
DRUMS_A = drum_steps("KCK+CHH CHH CHH CHH SNR+CHH CHH CHH KCK KCK+CHH CHH OHH CHH SNR+CHH CHH KCK CHH")
BAS_B = steps("E2 === E2 E3 === E2 D2 === A1 === A1 A2 === G2 F#2 D2")
LEAD_A = steps("--- --- --- --- --- --- --- --- --- --- --- --- B4 === D5 ===")
ARP_B = steps("D5 === A4 === D5 === F#4 === A4 === E4 === A4 === C#5 ===")
DRUMS_B = drum_steps("KCK+CHH CHH CHH KCK SNR+CHH CHH OHH CHH KCK+CHH KCK CHH CHH SNR+CHH CHH SNR SNR")
LEAD_B = steps("E5 --- --- === --- --- --- --- --- --- --- --- --- --- --- ---")
ARP_C = steps("E5 === B4 === E5 === G#4 === A4 === B4 === D5 === E5 ===")
BAS_C = steps("G2 === G2 === A2 === A2 === B2 === D3 === D3 A2 G2 F#2")
LEAD_C = steps("G4 --- A4 --- B4 --- === --- D5 --- E5 --- F#5 --- D5 ===")
ARP_D = steps("G4 B4 D5 G5 A4 C#5 E5 A5 D5 A4 F#5 D5 A5 F#5 D5 A4")
DRUMS_C = drum_steps("KCK+OHH CHH KCK CHH SNR+OHH CHH KCK CHH KCK+CHH SNR TOM2 TOM2 SNR SNR TOM2 TOM2")
BAS_D = steps("E2 === E2 E3 === E2 G2 G#2 A2 === A2 B2 === E2 D2 B1")
LEAD_D = steps("E5 --- --- B4 D5 --- E5 --- === G4 G#4 --- A4 === B4 ===")
ARP_E = steps("E5 B4 G#4 B4 E5 B4 G#4 B4 D5 B4 G#4 B4 E5 B4 G#4 B4")
DRUMS_D = drum_steps("KCK+OHH CHH CHH KCK SNR+CHH CHH CHH KCK KCK+CHH CHH OHH CHH SNR+CHH CHH KCK CHH")
BAS_E = steps("D2 === D2 D3 === D2 A2 === D2 === D2 E2 F#2 === G2 G#2")
LEAD_E = steps("D5 --- --- A4 B4 --- D5 --- === E5 --- D5 B4 --- A4 ===")
ARP_F = steps("D5 A4 F#4 A4 D5 A4 F#4 A4 E5 A4 F#4 A4 D5 A4 F#4 A4")
DRUMS_E = drum_steps("KCK+CHH CHH CHH KCK SNR+CHH CHH OHH CHH KCK+CHH KCK CHH CHH SNR+CHH CHH KCK SNR")
BAS_F = steps("C#2 === C#2 C#3 === C#2 A2 === C#2 === C#2 B1 A1 === B1 ===")
LEAD_F = steps("C#5 --- --- A4 E5 --- --- === --- F#5 --- E5 D5 === C#5 ===")
ARP_G = steps("C#5 A4 E4 A4 C#5 A4 E4 A4 E5 C#5 A4 E4 C#5 A4 E4 A4")
BAS_G = steps("C2 === C2 C3 === C2 G2 === D2 === D2 D3 === A2 D2 D#2")
LEAD_G = steps("B4 --- G4 --- E5 --- D5 --- B4 --- A4 --- B4 === D5 ===")
ARP_H = steps("C5 G4 E4 G4 B4 G4 E4 G4 D5 A4 F#4 A4 B4 A4 F#4 D5")
DRUMS_F = drum_steps("KCK+OHH CHH KCK CHH SNR+CHH CHH KCK CHH KCK+OHH CHH KCK CHH SNR SNR TOM2 TOM2")
BAS_H = steps("C2 C2 C3 C2 C2 C2 G2 C2 C2 C2 C3 C2 G2 E2 C2 G1")
LEAD_H = steps("G5 --- --- F#5 E5 --- B4 --- --- === --- --- --- --- C5 B4")
ARP_I = steps("B4 G4 E4 C4 B4 G4 E4 C4 B4 G4 E4 C4 E5 B4 G4 E4")
DRUMS_G = drum_steps("KCK+OHH CHH CHH CHH SNR+CHH CHH CHH KCK KCK+CHH CHH CHH CHH SNR+CHH CHH OHH CHH")
BAS_I = steps("D2 D2 D3 D2 D2 D2 A2 D2 D2 D2 D3 D2 A2 F#2 D2 A1")
LEAD_I = steps("A4 --- --- B4 D5 --- F#5 --- E5 --- D5 --- === --- --- ---")
ARP_J = steps("B4 A4 F#4 D4 B4 A4 F#4 D4 B4 A4 F#4 D4 F#5 D5 A4 F#4")
DRUMS_H = drum_steps("KCK+CHH CHH CHH KCK SNR+CHH CHH CHH KCK KCK+CHH CHH OHH CHH SNR+CHH CHH KCK SNR")
BAS_J = steps("B1 B1 B2 B1 B1 B1 F#2 B1 B1 B1 B2 B1 F#2 D2 B1 D2")
LEAD_J = steps("F#5 --- --- E5 D5 --- B4 --- A4 --- F#4 --- A4 === B4 D5")
ARP_K = steps("A4 F#4 D4 B3 A4 F#4 D4 B3 A4 F#4 D4 B3 D5 B4 F#4 D4")
BAS_K = steps("E2 === E2 === E2 === B2 === E2 === E2 === E3 D3 B2 G#2")
LEAD_K = steps("E5 --- --- --- === --- D5 E5 G#5 --- --- === B5 --- A5 G#5")
ARP_L = steps("E5 B4 A4 E4 E5 B4 A4 E4 E5 B4 G#4 E4 G#5 E5 B4 G#4")
DRUMS_I = drum_steps("KCK+CHH CHH KCK CHH SNR+CHH CHH KCK CHH KCK+OHH SNR KCK SNR SNR SNR TOM2 TOM2")
BAS_L = steps("A1 === A1 A2 === A1 E2 === B1 === B1 B2 === B1 F#2 ===")
LEAD_L = steps("A5 === G#5 === E5 === C#5 === B4 === C#5 D5 E5 === F#5 ===")
ARP_M = steps("A5 E5 C#5 A4 A5 E5 C#5 A4 B5 F#5 D#5 B4 B5 F#5 D#5 B4")
DRUMS_J = drum_steps("KCK+OHH CHH CHH KCK SNR+CHH CHH CHH KCK KCK+OHH CHH CHH KCK SNR+CHH CHH KCK CHH")
BAS_M = steps("C2 === C2 C3 === C2 G2 === D2 === D2 D3 === D2 A2 D2")
LEAD_M = steps("G5 --- F#5 E5 === D5 C5 B4 D5 === E5 F#5 A5 --- F#5 D5")
ARP_N = steps("G5 E5 C5 G4 G5 E5 C5 G4 A5 F#5 D5 A4 A5 F#5 D5 A4")
DRUMS_K = drum_steps("KCK+OHH CHH CHH KCK SNR+CHH CHH OHH CHH KCK+OHH CHH KCK CHH SNR+CHH SNR KCK SNR")
BAS_N = steps("E2 === E2 E3 === E2 G2 === A2 === A2 === B2 === D3 ===")
LEAD_N = steps("E5 === B4 D5 E5 === G5 === G#5 --- A5 --- B5 --- G#5 E5")
ARP_O = steps("E5 B4 G#4 E4 E5 B4 G5 D5 A5 E5 C#5 A4 B5 G#5 E5 B4")
DRUMS_L = drum_steps("KCK+OHH CHH CHH KCK SNR+CHH CHH KCK CHH KCK+OHH CHH KCK CHH SNR+OHH CHH KCK CHH")
BAS_O = steps("C2 === C2 G2 D2 === D2 A2 E2 === B2 D3 E3 === E2 ===")
LEAD_O = steps("G5 === E5 C5 A5 === F#5 D5 B5 --- --- --- E5 === --- ---")
ARP_P = steps("C5 E5 G5 C6 D5 F#5 A5 D6 E5 G#5 B5 E6 E6 === --- ---")
DRUMS_M = drum_steps("KCK+OHH CHH SNR KCK KCK+OHH CHH SNR KCK SNR SNR TOM2 TOM2 KCK+OHH --- SNR KCK")

SECTIES = [
    {"naam": "A - Intro: Igniter", "soort": "intro", "maten": (1, 4)},
    {"naam": "B - Main Groove: Full Throttle", "soort": "thema", "maten": (5, 8)},
    {"naam": "C - Bridge: Night Highway", "soort": "opbouw", "maten": (9, 12)},
    {"naam": "D - Climax: Overdrive Solo", "soort": "finale", "maten": (13, 16)},
]

MATEN = {
    # ------------------------------------------------------------------ A - Intro: Igniter
    # E5
    1: {"akkoord": "E5@1 D5@2.5 E@4",
        "bas": BAS_A,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0", "E4+B4", "D4+A4", "E4+G#4+B4"),
        "arp": ARP_A,
        "drums": DRUMS_A},
    # D/E -> A/E
    2: {"akkoord": "D/E A/E",
        "bas": BAS_B,
        "brass": stabs("1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0", "D4+F#4+A4", "C#4+E4+A4"),
        "lead": LEAD_A,
        "arp": ARP_B,
        "drums": DRUMS_B},
    # E5
    3: {"akkoord": "E@1 D5@2.5 E@4",
        "bas": BAS_A,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0", "E4+G#4+B4", "D4+A4", "E4+G#4+B4"),
        "lead": LEAD_B,
        "arp": ARP_C,
        "drums": DRUMS_A},
    # G5 -> A5 -> D5
    4: {"akkoord": "G5@1 A5@2 D5@3.5",
        "bas": BAS_C,
        "brass": stabs("1 0 0 0 1 0 0 0 0 0 1 0 0 0 1 0", "G4+B4+D5", "A4+C#5+E5", "D4+F#4+A4"),
        "lead": LEAD_C,
        "arp": ARP_D,
        "drums": DRUMS_C},
    # ------------------------------------------------------------------ B - Main Groove: Full Throttle
    # E7
    5: {"akkoord": "E7@1 D@4",
        "bas": BAS_D,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0", "E4+G#4+B4+D5", "E4+G#4+B4", "D4+F#4+A4"),
        "lead": LEAD_D,
        "arp": ARP_E,
        "drums": DRUMS_D},
    # Dadd9
    6: {"akkoord": "Dadd9@1 A@3.5",
        "bas": BAS_E,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 1 0 0 0 0 0", "D4+F#4+A4+E5", "D4+F#4+A4", "C#4+E4+A4"),
        "lead": LEAD_E,
        "arp": ARP_F,
        "drums": DRUMS_E},
    # A/C#
    7: {"akkoord": "A/C#",
        "bas": BAS_F,
        "brass": stabs("1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0", "C#4+E4+A4"),
        "lead": LEAD_F,
        "arp": ARP_G,
        "drums": DRUMS_A},
    # Cmaj7 -> D6
    8: {"akkoord": "Cmaj7 D6",
        "bas": BAS_G,
        "brass": stabs("1 0 0 0 0 0 1 0 1 0 0 0 0 0 1 0", "C4+E4+G4+B4", "C4+E4+G4", "D4+F#4+A4+B4", "D4+F#4+A4"),
        "lead": LEAD_G,
        "arp": ARP_H,
        "drums": DRUMS_F},
    # ------------------------------------------------------------------ C - Bridge: Night Highway
    # Cmaj7
    9: {"akkoord": "Cmaj7",
        "bas": BAS_H,
        "brass": stabs("1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0", "C4+E4+G4+B4", "C4+E4+G4"),
        "lead": LEAD_H,
        "arp": ARP_I,
        "drums": DRUMS_G},
    # D6
    10: {"akkoord": "D6",
         "bas": BAS_I,
         "brass": stabs("1 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0", "D4+F#4+A4+B4", "D4+F#4+A4"),
         "lead": LEAD_I,
         "arp": ARP_J,
         "drums": DRUMS_H},
    # Bm7
    11: {"akkoord": "Bm7",
         "bas": BAS_J,
         "brass": stabs("1 0 0 0 0 0 1 0 0 0 1 0 0 0 0 0", "B3+D4+F#4+A4", "B3+D4+F#4"),
         "lead": LEAD_J,
         "arp": ARP_K,
         "drums": DRUMS_G},
    # E7sus4 -> E7
    12: {"akkoord": "E7sus4 E7",
         "bas": BAS_K,
         "brass": stabs("1 0 0 1 0 0 1 0 1 0 0 1 0 0 1 0", "E4+A4+B4+D5", "E4+A4+B4", "E4+G#4+B4+D5", "E4+G#4+B4"),
         "lead": LEAD_K,
         "arp": ARP_L,
         "drums": DRUMS_I},
    # ------------------------------------------------------------------ D - Climax: Overdrive Solo
    # A5 -> B5
    13: {"akkoord": "A5 B5",
         "bas": BAS_L,
         "brass": stabs("1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0", "A4+C#5+E5", "E4+A4+C#5", "B4+D#5+F#5", "F#4+B4+D#5"),
         "lead": LEAD_L,
         "arp": ARP_M,
         "drums": DRUMS_J},
    # Cmaj7 -> D5
    14: {"akkoord": "Cmaj7 D5",
         "bas": BAS_M,
         "brass": stabs("1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0", "C4+E4+G4+B4", "C4+E4+G4", "D4+F#4+A4"),
         "lead": LEAD_M,
         "arp": ARP_N,
         "drums": DRUMS_K},
    # E5 -> G5 -> A5
    15: {"akkoord": "E@1 G@2.5 A@3.5 Bm@4.5",
         "bas": BAS_N,
         "brass": stabs("1 0 0 0 0 0 1 0 0 0 1 0 0 0 1 0", "E4+G#4+B4", "G4+B4+D5", "A4+C#5+E5", "B4+D5+F#5"),
         "lead": LEAD_N,
         "arp": ARP_O,
         "drums": DRUMS_L},
    # C5 -> D5 -> E5
    16: {"akkoord": "C5@1 D5@2 E5@3",
         "bas": BAS_O,
         "brass": stabs("1 0 0 0 1 0 0 0 1 0 0 0 1 0 0 0", "C4+E4+G4", "D4+F#4+A4", "E4+G#4+B4", "E4+G#4+B4+E5"),
         "lead": LEAD_O,
         "arp": ARP_P,
         "drums": DRUMS_M},
}
