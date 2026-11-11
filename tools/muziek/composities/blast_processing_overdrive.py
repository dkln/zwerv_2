"""Blast Processing Overdrive: de compositie van Gemini (blast_processing_overdrive.txt, letterlijk
overgenomen) maat voor maat in de notatie van tools/muziek/notation.py.

Waar de tekst een partij niet uitschrijft, staat erbij wat er gespeeld wordt en waarom
("afgeleid: ..."), altijd uit de beschrijving van dat instrument of die sectie in de tekst zelf:
- de FM-bas speelt "pompende 16e-noot octaafsprongen" (instrumentatie, kanaal 1): in de secties
  zonder uitgeschreven bas (opbouw, refrein, finale) dat figuur op de grondtoon van het akkoord;
- de PSG-arpeggiator speelt "onafgebroken 16e-noot akkoord-arpeggio's" (kanaal 4): in de maten
  zonder uitgeschreven arp grondtoon-terts-kwint-octaaf van het akkoord;
- de drums: maat 1 geeft het basisritme, de secties zeggen wat er verandert (open hi-hats op de
  off-beats in thema A, half-time met de snare op tel 3 in de breakdown, de fills).
"""
from notation import cycle, drum_run, drums, notes, run

TITEL = "Blast Processing Overdrive"
TEMPO = 136
TELLEN_PER_MAAT = 4
TOONSOORT = ("D", "mineur")

KLANKEN = {
    "bas": "fm_slapbas",            # kanaal 1: YM2612 FM slap bass
    "subbas": "fm_subbas",          # kanaal 1 in de breakdown: "de diepe FM-subbas"
    "pad": "synthwave_pad",         # kanaal 2: gedetunede zaagtand-pad, breed gepand
    "brass": "synth_brass",         # kanaal 2: synth-brass stabs
    "lead": "fm_lead_helder",       # kanaal 3: heldere FM-lead, vibrato 6 Hz, gepuncteerde-achtste delay
    "arp": "psg_arp",               # kanaal 4: SN76489 blokgolf-arpeggiator
    "gitaar": "overdrive_gitaar",   # kanaal 5: powerchords
    "solo": "overdrive_gitaar_solo",  # kanaal 5: losse noten, riffs en de shred-solo
}

# waar de intro-beelden wisselen (scripts/ui/intro.gd): het logo staat bij thema A, het verhaal
# rolt vanaf de octaafklim, drie alinea's vallen op het refrein, de breakdown en de finale, en
# de laatste zin komt tot rust op de eindklap (maat 32, tel 2)
MOMENTEN = {"logo": 5, "verhaal": 9, "hoogtepunt": 17, "duel": 25, "crash": 29, "rust": (32, 2.0)}

# bijstelling op verzoek van de gebruiker (11 nov 2026: "ietsje blijer, meer upbeat", in de
# geest van de stage 1-muziek van Streets of Rage 2: een house-groove): over de letterlijke maten
# heen gelegd bij het maken (score.tune); de maten hieronder blijven zoals Gemini ze schreef
BIJSTELLING = {
    "tempo": 144,                                   # was 136
    "octaaf": {"arp": 1},                           # de PSG-arpeggio's een octaaf hoger: glinsterender
    "kick_op_elke_tel": ("thema", "refrein", "finale"),      # four on the floor
    "open_hihat": ("intro", "thema", "opbouw", "refrein", "finale"),  # op de off-beats
    "handklap": ("thema", "refrein", "finale"),     # clap bij de snare op 2 en 4
    "stoten": {"secties": ("thema", "refrein"), "klank": "fm_piano"},  # house-pianostoten op de off-beats
    "majeur_slot": True,                            # slotakkoord en de landing van de deuntjes in D groot
}

BASIS_DRUMS = drums(kick="1 2.5 3", snare="2 4", hihat="16")
THEMA_DRUMS = drums(kick="1 2.5 3", snare="2 4", hihat="16-off", open="off")
OPBOUW_DRUMS = drums(kick="4", snare="2 4", hihat="8")
HALFTIME_DRUMS = drums(kick="1 2.75", snare="3", hihat="8")


def octave_groove(low: str, high: str, start: float = 1.0, end: float = 5.0) -> list:
    """De bas: per tel laag - laag - hoog - laag in zestienden."""
    return cycle(f"{low} {low} {high} {low}", 0.25, start, end)


def arp(figure: str, start: float = 1.0, end: float = 5.0) -> list:
    return cycle(figure, 0.25, start, end)


SECTIES = [
    {"naam": "Intro – YM2612 Boot-Up & Synthwave Pulse", "soort": "intro", "maten": (1, 4),
     "standaard": {"drums": BASIS_DRUMS}},
    {"naam": "Thema A – Neon Streets of Rage", "soort": "thema", "maten": (5, 12),
     "standaard": {"drums": THEMA_DRUMS}},
    {"naam": "Pre-Chorus / Lift – Turboboost", "soort": "opbouw", "maten": (13, 16),
     "standaard": {"drums": OPBOUW_DRUMS}},
    {"naam": "Chorus / Drop – Mega Drive Overdrive", "soort": "refrein", "maten": (17, 24),
     "standaard": {"drums": THEMA_DRUMS}},
    {"naam": "Breakdown / Bridge – 16-Bit Cyber Grid", "soort": "breakdown", "maten": (25, 28),
     "standaard": {"drums": HALFTIME_DRUMS}},
    {"naam": "Finale / Outro Climax – Final Boss Finish", "soort": "finale", "maten": (29, 32),
     "standaard": {"drums": THEMA_DRUMS}},
]

MATEN = {
    # ------------------------------------------------------------------ sectie 1: intro
    1: {"akkoord": "Dm",
        "pad": notes("1 D3+F3+A3+D4 4"),
        "bas": octave_groove("D2", "D3"),
        "arp": arp("D4 F4 A4 D5"),
        "drums": BASIS_DRUMS + drums(crash="1")},
    2: {"akkoord": "Bbmaj7",
        "pad": notes("1 Bb2+F3+A3+D4 4"),
        "bas": octave_groove("Bb1", "Bb2"),
        "arp": arp("Bb3 D4 F4 A4")},
    3: {"akkoord": "Gm7",
        "pad": notes("1 G2+D3+F3+Bb3 4"),
        "bas": octave_groove("G1", "G2"),
        "arp": arp("G3 Bb3 D4 F4"),
        "lead": notes("1.0 D5 1.5, 2.5 F5 0.5, 3.0 G5 1.5, 4.5 F5 0.5")},
    4: {"akkoord": "Asus4 A7",
        "pad": notes("1 A2+E3+A3 4, 1 D4 2, 3 C#4 2"),
        "bas": octave_groove("A1", "A2"),
        "arp": arp("A3 D4 E4 A4", 1, 3) + run("A3 C#4 E4 G4 A4 C#5 E5 A5", 0.25, start=3),
        "lead": notes("1.0 E5 2, 3.0 C#5 1, 4.0 A4 1"),
        "drums": drums(kick="1 2.5", snare="2", hihat="1 1.25 1.5 1.75 2 2.25 2.5 2.75")
        + drum_run("S HT HT MT MT LT S S", 0.25, start=3)},

    # ------------------------------------------------------------------ sectie 2: thema A
    5: {"akkoord": "Dm",
        "bas": octave_groove("D2", "D3"), "arp": arp("D4 A4 D5 A4"),
        "lead": notes("1.0 D5 0.75, 1.75 F5 0.75, 2.5 A5 1.0, 3.5 G5 0.5, 4.0 F5 0.5, 4.5 D5 0.5"),
        "drums": THEMA_DRUMS + drums(crash="1")},
    6: {"akkoord": "C",
        "bas": octave_groove("C2", "C3"), "arp": arp("C4 G4 C5 G4"),
        "lead": notes("1.0 E5 1.5, 2.5 G5 0.5, 3.0 C5 1.0, 4.0 D5 0.5, 4.5 E5 0.5")},
    7: {"akkoord": "Bb",
        "bas": octave_groove("Bb1", "Bb2"), "arp": arp("Bb3 F4 Bb4 F4"),
        "lead": notes("1.0 F5 0.75, 1.75 D5 0.75, 2.5 Bb4 1.0, 3.5 C5 0.5, 4.0 D5 0.5, 4.5 F5 0.5")},
    8: {"akkoord": "A7",
        "bas": octave_groove("A1", "A2"), "arp": arp("A3 E4 A4 C#5"),
        "lead": notes("1.0 E5 2.0, 3.0 Bb4 0.5, 3.5 C5 0.5, 4.0 C#5 1.0"),
        # eerste gitaar-accent: de turnaround op tel 3-4
        "gitaar": notes("3.0 Bb2+F3+Bb3 0.5, 3.5 C3+G3+C4 0.5, 4.0 A2+E3+A3 1.0"),
        "drums": drums(kick="1 2.5 3", snare="2", hihat="16-off", open="off")
        + drum_run("S S HT MT LT LT S S", 0.25, start=3)},
    9: {"akkoord": "Dm",
        "bas": octave_groove("D2", "D3"), "arp": arp("D4 F4 A4 D5"),
        "lead": notes("1.0 D5 0.75, 1.75 F5 0.75, 2.5 A5 1.0, 3.5 A5 0.5, 4.0 Bb5 0.5, 4.5 A5 0.5"),
        "drums": THEMA_DRUMS + drums(crash="1")},
    10: {"akkoord": "F",
         "bas": octave_groove("F2", "F3"), "arp": arp("F4 A4 C5 F5"),
         "lead": notes("1.0 C6 1.5, 2.5 A5 0.5, 3.0 F5 1.0, 4.0 G5 0.5, 4.5 A5 0.5")},
    11: {"akkoord": "Gm7",
         "bas": octave_groove("G1", "G2"), "arp": arp("G4 Bb4 D5 F5"),
         "lead": notes("1.0 Bb5 0.75, 1.75 G5 0.75, 2.5 D5 1.0, 3.5 E5 0.5, 4.0 F5 0.5, 4.5 G5 0.5")},
    12: {"akkoord": "Bb A7",
         "bas": octave_groove("Bb1", "Bb2", 1, 3) + octave_groove("A1", "A2", 3, 5),
         # afgeleid: de arp van maat 7 en 8 (dezelfde akkoorden)
         "arp": arp("Bb3 F4 Bb4 F4", 1, 3) + arp("A3 E4 A4 C#5", 3, 5),
         "lead": notes("1.0 A5 1.5, 2.5 G5 0.5, 3.0 E5 2"),
         # tweede gitaar-accent
         "gitaar": notes("3.0 G2+D3+G3 0.5, 3.5 Bb2+F3+Bb3 0.5, 4.0 A2+E3+A3 1.0"),
         "drums": drums(kick="1 2.5 3", snare="2", hihat="16-off", open="off")
         + drum_run("S S HT MT LT LT S S", 0.25, start=3)},

    # ------------------------------------------------------------------ sectie 3: opbouw
    # synth-brass stabs op 1.0, 1.75, 2.5 en 4.0; afgeleid: bas en arp zoals overal
    13: {"akkoord": "Bbmaj7",
         "brass": notes("1.0 Bb2+F3+A3+D4 0.5, 1.75 Bb2+F3+A3+D4 0.5, 2.5 Bb2+F3+A3+D4 0.5, 4.0 Bb2+F3+A3+D4 0.5"),
         "lead": notes("1.0 F5 0.75, 1.75 D5 0.75, 2.5 Bb4 1.5, 4.0 D5 0.5, 4.5 F5 0.5"),
         "bas": octave_groove("Bb1", "Bb2"), "arp": arp("Bb3 D4 F4 A4"),
         "drums": OPBOUW_DRUMS + drums(crash="1")},
    14: {"akkoord": "C6",
         "brass": notes("1.0 C3+E3+G3+A3 0.5, 1.75 C3+E3+G3+A3 0.5, 2.5 C3+E3+G3+A3 0.5, 4.0 C3+E3+G3+A3 0.5"),
         "lead": notes("1.0 G5 0.75, 1.75 E5 0.75, 2.5 C5 1.5, 4.0 E5 0.5, 4.5 G5 0.5"),
         "bas": octave_groove("C2", "C3"), "arp": arp("C4 E4 G4 A4")},
    15: {"akkoord": "Dm7",
         "brass": notes("1.0 D3+F3+A3+C4 0.5, 1.75 D3+F3+A3+C4 0.5, 2.5 D3+F3+A3+C4 0.5, 4.0 D3+F3+A3+C4 0.5"),
         "lead": notes("1.0 A5 0.75, 1.75 F5 0.75, 2.5 D5 1.0, 3.5 F5 0.5, 4.0 G5 0.5, 4.5 A5 0.5"),
         "bas": octave_groove("D2", "D3"), "arp": arp("D4 F4 A4 C5")},
    16: {"akkoord": "Ebmaj7 A7",
         "brass": notes("1.0 Eb3+G3+Bb3+D4 2, 3.0 A2+C#3+E3+G3 2"),
         "lead": notes("1.0 Bb5 1.5, 2.5 A5 0.5, 3.0 G5 1.0, 4.0 A5 1.0"),
         # de launch-riff: chromatisch stijgende powerchords
         "gitaar": notes("3.0 A2+E3+A3 0.5, 3.5 A2+E3+A3 0.5, 4.0 B2+F#3+B3 0.5, 4.5 C#3+G#3+C#4 0.5"),
         "bas": octave_groove("Eb2", "Eb3", 1, 3) + octave_groove("A1", "A2", 3, 5),
         "arp": arp("Eb4 G4 Bb4 D5", 1, 3) + arp("A3 C#4 E4 G4", 3, 5),
         "drums": drums(kick="1 2", snare="2", hihat="1 1.5 2 2.5")
         + drum_run("S S S S S S S S", 0.25, start=3)},

    # ------------------------------------------------------------------ sectie 4: refrein
    # afgeleid: bas en arp op de grondtonen van de powerchords (mineur zoals de tekst: Dm, Gm)
    17: {"akkoord": "D5",
         "lead": notes("1.0 D6 1.5, 2.5 C6 0.5, 3.0 A5 1.0, 4.0 G5 0.5, 4.5 F5 0.5"),
         "gitaar": notes("1.0 D3+A3+D4 0.75, 1.75 D3+A3+D4 0.75, 2.5 D3+A3+D4 1.0"),
         "solo": notes("3.5 A4 0.5, 4.0 G4 0.5, 4.5 F4 0.5"),
         "bas": octave_groove("D2", "D3"), "arp": arp("D4 F4 A4 D5"),
         "drums": THEMA_DRUMS + drums(crash="1")},
    18: {"akkoord": "Bb5",
         "lead": notes("1.0 Bb5 1.5, 2.5 A5 0.5, 3.0 F5 1.0, 4.0 G5 0.5, 4.5 A5 0.5"),
         "gitaar": notes("1.0 Bb2+F3+Bb3 0.75, 1.75 Bb2+F3+Bb3 0.75, 2.5 Bb2+F3+Bb3 1.0, "
                         "3.5 Bb2+F3+Bb3 0.75, 4.25 Bb2+F3+Bb3 0.75"),
         "bas": octave_groove("Bb1", "Bb2"), "arp": arp("Bb3 D4 F4 Bb4")},
    19: {"akkoord": "F5",
         "lead": notes("1.0 C6 1.5, 2.5 Bb5 0.5, 3.0 A5 1.0, 4.0 F5 0.5, 4.5 G5 0.5"),
         "gitaar": notes("1.0 F2+C3+F3 0.75, 1.75 F2+C3+F3 0.75, 2.5 F2+C3+F3 1.0"),
         "solo": notes("3.5 A4 0.5, 4.0 G4 0.5, 4.5 F4 0.5"),
         "bas": octave_groove("F2", "F3"), "arp": arp("F4 A4 C5 F5")},
    20: {"akkoord": "C5 A5",
         "lead": notes("1.0 G5 1.5, 2.5 F5 0.5, 3.0 E5 2"),
         "gitaar": notes("1.0 C3+G3+C4 1.5, 3.5 A2+E3+A3 0.75, 4.25 A2+E3+A3 0.75"),
         "bas": octave_groove("C2", "C3", 1, 3) + octave_groove("A1", "A2", 3, 5),
         "arp": arp("C4 E4 G4 C5", 1, 3) + arp("A3 C#4 E4 A4", 3, 5)},
    21: {"akkoord": "G5",
         "lead": notes("1.0 Bb5 0.75, 1.75 A5 0.75, 2.5 G5 1.0, 3.5 A5 0.5, 4.0 Bb5 0.5, 4.5 C6 0.5"),
         "gitaar": notes("1.0 G2+D3+G3 0.75, 1.75 G2+D3+G3 0.75, 2.5 G2+D3+G3 1.0"),
         "solo": notes("3.5 A4 0.5, 4.0 G4 0.5, 4.5 F4 0.5"),
         "bas": octave_groove("G1", "G2"), "arp": arp("G3 Bb3 D4 G4"),
         "drums": THEMA_DRUMS + drums(crash="1")},
    22: {"akkoord": "D5",
         "lead": notes("1.0 A5 1.5, 2.5 F5 0.5, 3.0 D5 1.5, 4.5 E5 0.5"),
         "gitaar": notes("1.0 D3+A3+D4 0.75, 1.75 D3+A3+D4 0.75, 2.5 D3+A3+D4 1.0, "
                         "3.5 D3+A3+D4 0.75, 4.25 D3+A3+D4 0.75"),
         "bas": octave_groove("D2", "D3"), "arp": arp("D4 F4 A4 D5")},
    23: {"akkoord": "Bb5 C5",
         "lead": notes("1.0 F5 0.75, 1.75 G5 0.75, 2.5 A5 0.5, 3.0 G5 0.75, 3.75 A5 0.75, 4.5 C6 0.5"),
         "gitaar": notes("1.0 Bb2+F3+Bb3 1.5, 2.5 Bb2+F3+Bb3 0.5, 3.0 C3+G3+C4 1.5, 4.5 C3+G3+C4 0.5"),
         "bas": octave_groove("Bb1", "Bb2", 1, 3) + octave_groove("C2", "C3", 3, 5),
         "arp": arp("Bb3 D4 F4 Bb4", 1, 3) + arp("C4 E4 G4 C5", 3, 5)},
    24: {"akkoord": "D5",
         "lead": notes("1.0 D6 4"),
         "gitaar": notes("1.0 D3+A3+D4 1.5"),
         # de blues/pentatonische lick in zestienden vanaf tel 2.5
         "solo": run("D4 F4 G4 G#4 A4 C5", 0.25, start=2.5) + notes("4.0 D5 1.0"),
         "bas": octave_groove("D2", "D3"), "arp": arp("D4 F4 A4 D5"),
         "drums": drums(kick="1 2.5 3", snare="2 4", hihat="16-off", open="off", crash="1")},

    # ------------------------------------------------------------------ sectie 5: breakdown
    25: {"akkoord": "Gm9",
         "pad": notes("1 G2+D3+F3+A3+Bb3 4"),
         "arp": arp("G4 Bb4 D5 A5"),
         "subbas": notes("1.0 G1 2.5, 3.5 G2 0.5, 4.0 G1 1.0"),
         "drums": HALFTIME_DRUMS + drums(crash="1")},
    26: {"akkoord": "Dm9",
         "pad": notes("1 D3+F3+A3+C4+E4 4"),
         "arp": arp("D4 F4 A4 E5"),
         # afgeleid: hetzelfde subbas-figuur als maat 25 en 27
         "subbas": notes("1.0 D2 2.5, 3.5 D3 0.5, 4.0 D2 1.0"),
         "lead": notes("3.0 A5 1 0.8, 4.0 F5 1 0.8")},
    27: {"akkoord": "Ebmaj7",
         "pad": notes("1 Eb3+G3+Bb3+D4 4"),
         "arp": arp("Eb4 G4 Bb4 D5"),
         "subbas": notes("1.0 Eb2 2.5, 3.5 Eb3 0.5, 4.0 Eb2 1.0")},
    28: {"akkoord": "A7sus4 A7",
         "pad": notes("1 A2+E3+G3 4, 1 D4 2, 3 C#4 2"),
         "arp": arp("A3 C#4 E4 G4"),
         "subbas": notes("1.0 A1 2.5, 3.5 A2 0.5, 4.0 A1 1.0"),
         "lead": notes("1.0 E5 1.5, 2.5 F5 0.5, 3.0 G5 1.0, 4.0 A5 1.0"),
         # het crescendo van snare en toms over tel 3 en 4
         "drums": drums(kick="1 2.75", hihat="8")
         + drum_run("S S S S HT HT MT MT", 0.25, start=3, velocity=0.85)
         + drum_run("S S LT LT", 0.125, start=4.5)},

    # ------------------------------------------------------------------ sectie 6: finale
    29: {"akkoord": "Dm",
         "lead": notes("1.0 D6 0.75, 1.75 A5 0.75, 2.5 F5 1.0, 3.5 G5 0.5, 4.0 A5 0.5, 4.5 Bb5 0.5"),
         "solo": notes("1.0 F5 0.5, 1.5 E5 0.5, 2.0 D5 0.5, 2.5 A4 0.5") + run("D5 E5 F5 G5", 0.25, start=3)
         + notes("4.0 A5 0.5, 4.5 G5 0.5"),
         "bas": octave_groove("D2", "D3"), "arp": arp("D4 F4 A4 D5"),
         "drums": THEMA_DRUMS + drums(crash="1")},
    30: {"akkoord": "Bb C",
         "lead": notes("1.0 Bb5 0.75, 1.75 A5 0.75, 2.5 F5 0.5, 3.0 C6 0.75, 3.75 Bb5 0.75, 4.5 A5 0.5"),
         "solo": notes("1.0 F5 0.75, 1.75 D5 0.75, 2.5 Bb4 0.5, 3.0 G5 0.75, 3.75 E5 0.75, 4.5 C5 0.5"),
         "bas": octave_groove("Bb1", "Bb2", 1, 3) + octave_groove("C2", "C3", 3, 5),
         "arp": arp("Bb3 D4 F4 Bb4", 1, 3) + arp("C4 E4 G4 C5", 3, 5)},
    31: {"akkoord": "Gm A7",
         "lead": run("G5 A5 Bb5 G5 A5 B5", 0.5, start=1) + notes("4.0 C#6 1"),
         "solo": run("Bb4 C5 D5 Eb5", 0.25, start=1) + notes("2.0 G5 0.5, 2.5 Bb5 0.5, 3.0 A5 0.5, 3.5 G5 0.5, 4.0 E5 1.0"),
         "bas": octave_groove("G1", "G2", 1, 3) + octave_groove("A1", "A2", 3, 5),
         "arp": arp("G3 Bb3 D4 G4", 1, 3) + arp("A3 C#4 E4 A4", 3, 5),
         "drums": drums(kick="1 2.5 3", snare="2", hihat="16-off", open="off")
         + drum_run("S S HT HT MT MT LT LT", 0.25, start=3)},
    32: {"akkoord": "D5",
         # alle instrumenten unisono: twee staccato klappen en de eindklap met dubbele crash
         "bas": notes("1.0 D2 0.25, 1.5 D2 0.25, 2.0 D2 3"),
         "pad": notes("1.0 D3+A3+D4 0.25, 1.5 D3+A3+D4 0.25, 2.0 D3+A3+D4 3"),
         "gitaar": notes("1.0 D3+A3+D4 0.25, 1.5 D3+A3+D4 0.25, 2.0 D3+A3+D4 3"),
         "arp": notes("1.0 D5 0.25, 1.5 D5 0.25, 2.0 D5 2"),
         "lead": notes("1.0 D6 0.25, 1.5 D6 0.25, 2.0 D6 3"),
         "drums": drums(kick="1 1.5 2", snare="1 1.5 2", crash="1 2") + drums(crash="2", velocity=0.8)},
}
