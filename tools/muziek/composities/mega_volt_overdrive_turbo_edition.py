"""Mega-Volt Overdrive: Turbo Edition: de compositie van Gemini (mega_volt_overdrive_turbo_edition.txt,
letterlijk overgenomen) maat voor maat in de notatie van tools/muziek/notation.py.

Bronnen in de tekst: de uitgeschreven noten per sectie (hoofdstuk 4), de ABC-notatie (hoofdstuk
5: de bas van intro, couplet, refrein en solo, het precieze ritme van de gitaar en de outro) en
het MIDI-script (hoofdstuk 6: het drumpatroon en het galop-figuur van de bas). Spreken ze elkaar
tegen, dan wint de uitgeschreven tekst (hoofdstuk 4) met de ABC: de solo in de toonhoogtes van de
tekst en de ABC (E6/G6), niet de octaaf lagere van het MIDI-voorbeeld; het ritme van de gitaar in
maat 4 zoals de ABC het schrijft (drie zestienden akkoord, één zestiende gedempt).
De gitaar klinkt zoals de tabulatuur hem grijpt (een octaaf onder de ABC, gitaarnotatie).

Waar de tekst een partij niet uitschrijft, staat erbij wat er gespeeld wordt en waarom
("afgeleid: ..."), altijd uit de beschrijving van dat instrument of die sectie in de tekst zelf:
- de FM-bas: het galop-figuur (hoofdstuk 6, add_gallop_bass: grondtoon laag-laag-hoog-laag,
  kwint, ..., zesde en kwint aan het eind) op het akkoord van de maat, waar de ABC hem niet geeft;
- de PSG-arpeggio: "razendsnelle 1/16-noot blokgolf-arpeggio's voor constante voorwaartse
  energie" (kanaal 3): de akkoordvoicings van het couplet als figuur in zestienden;
- de synth-brass: "strakke, ritmische poly-brass akkoord-stabs op de syncopen en off-beats"
  (kanaal 4): stoten op de 'en' van elke tel, met de voicings van het couplet (powerchords waar
  het akkoord een powerchord is);
- de drums: het patroon van het MIDI-script in elke maat (dubbele kick, snare op 2 en 4, gesloten
  hi-hat in zestienden met open hi-hat op elke off-beat), met de fills en breaks van de tekst.
"""
from notation import cycle, drum_run, drums, notes, run

TITEL = "Mega-Volt Overdrive: Turbo Edition"
TEMPO = 156                      # "Standaard Turbo" (de Nitro-modus van 165 BPM is een variant)
TELLEN_PER_MAAT = 4
TOONSOORT = ("E", "mineur")

KLANKEN = {
    "bas": "fm_slapbas",            # kanaal 1: YM2612 Aggressive FM Bass, 1/16 slapbas
    "lead": "fm_lead_helder",       # kanaal 2: Mega Drive Clean Saw/FM Lead, helder, licht gedetuned
    "arp": "psg_arp",               # kanaal 3: SN76489 Turbo Pulse Arp
    "brass": "synth_brass",         # kanaal 4: Nitro Synth-Brass Stabs
    "gitaar": "clean_gitaar",       # kanaal 5: Clean 16-Bit Power-Guitar (powerchords, chugs)
    "solo": "clean_gitaar_solo",    # kanaal 5: de gitaarloopjes van de twin-solo
}

# waar de intro-beelden wisselen (scripts/ui/intro.gd): het logo bij het couplet (de eerste grote
# inzet na de intro, 6,2 s), het verhaal rolt vanaf maat 9, drie alinea's vallen op het refrein,
# de breakdown en de finale, en de laatste zin komt tot rust op de eindklap (maat 32, tel 1)
MOMENTEN = {"logo": 5, "verhaal": 9, "hoogtepunt": 13, "duel": 21, "crash": 29, "rust": (32, 1.0)}

# bijstelling op verzoek van de gebruiker (11 nov 2026: "voor de hoge tonen die de muziek bepalen
# meer chiptune-achtig geluidje"): de melodie (de lead) op de PSG-blokgolf in plaats van de
# FM-lead; dezelfde noten (score.tune)
# en daarna (11 nov 2026: "de lead mag die niet wat zwaarder, dus meer gitaar-achtig"): dezelfde
# melodie ook op de overstuurde gitaar eronder, zodat hij het gewicht van een gitaar krijgt en
# het chiptune-karakter houdt
# en daarna (11 nov 2026: "in Streets of Rage 2, stage 1, Go Straight, is de lead een ander soort
# geluidje, kun je dat instrument gebruiken?"): de melodie op een snerpende, nasale FM-lead met die
# kenmerken (felle aanslag, vibrato na de inzet, echo); alleen de klankkleur, geen noten van dat nummer
# en (11 nov 2026, de gebruiker over de klank van die muziek: een "gritty" house/techno-FM-bas,
# metalige percussieve stabs met korte decay, DMX-achtige drums met de rauwe Mega Drive-kick):
# de bas, de brass-stoten en het drumstel in die klankkleuren; dezelfde noten en slagen
# en ("ik mis de techno vibe ... ik doel op de lead, die is niet chemisch genoeg, die mag rauwer"):
# de melodie op een rauwe acid-achtige FM-lead in plaats van de snerpende; en daarna ("bij de
# nachtstad-menulus heb je dat best aardig gedaan in de eerste maat": daar speelt de
# PSG-arpeggio): de melodie in de klank van die arpeggio; en daarna ("je hoort dat instrument als
# bas volgens mij, die zou ik graag willen"): de melodie in de klank van de housebas
BIJSTELLING = {
    "klank": {"lead": "fm_housebas_lead", "bas": "fm_housebas", "brass": "fm_stoot_metaal"},
    "drumstel": "dmx",
    "verdubbel": {"lead": "overdrive_gitaar_solo"},
}

# het drumpatroon van het MIDI-script (hoofdstuk 6), in elke maat
KICKS = "1 1.5 1.75 2.5 2.75 3 3.5 3.75 4.5 4.75"
BASIS_DRUMS = drums(kick=KICKS, snare="2 4", hihat="16-off", open="off")


def basis_tot(beat: float) -> list:
    """Het basispatroon tot (niet met) `beat`: de plek voor een fill daarna."""
    return [hit for hit in BASIS_DRUMS if hit.position < beat - 1e-6]


GALOP = "{lo} {lo} {hi} {lo} {kwint} {lo} {hi} {lo} {lo} {lo} {hi} {lo} {zes} {kwint} {lo} {hi}"


def galop(lo: str, hi: str, kwint: str, zes: str) -> list:
    """De FM-bas: het galop-figuur in zestienden over de hele maat."""
    return run(GALOP.format(lo=lo, hi=hi, kwint=kwint, zes=zes), 0.25)


def arp(figuur: str, start: float = 1.0, end: float = 5.0) -> list:
    return cycle(figuur, 0.25, start, end)


def offbeats(akkoord: str, start: float = 1.0, end: float = 5.0) -> list:
    """De brass: een stoot op de 'en' van elke tel (stap 3, 7, 11, 15)."""
    return [note for note in notes(", ".join(f"{beat + 0.5} {akkoord} 0.25" for beat in (1, 2, 3, 4)))
            if start <= note.position < end]


def chugs(vol: str, gedempt: str, start: float = 1.0, end: float = 5.0) -> list:
    """De gitaar in het refrein (ABC maat 13): powerchords (grondtoon, kwint, octaaf) op de
    accenten, gedempte tweeklanken (grondtoon, kwint) op de zestienden ertussen."""
    figuur = [(0.0, vol, 0.5), (0.5, gedempt, 0.25), (0.75, gedempt, 0.25), (1.0, gedempt, 0.25),
              (1.25, gedempt, 0.25), (1.5, vol, 0.5), (2.0, vol, 0.5), (2.5, gedempt, 0.25),
              (2.75, gedempt, 0.25), (3.0, vol, 0.5), (3.5, vol, 0.5)]
    if end - start <= 2.0:
        # een halve maat (ABC maat 16): akkoord, vier gedempte, akkoord
        figuur = figuur[:6]
    velocity = {vol: 1.0, gedempt: 0.75}
    return notes(", ".join(f"{start + offset} {chord} {length} {velocity[chord]}" for offset, chord, length in figuur
                           if start + offset < end - 1e-6))


def klim(akkoorden: list, partij: str) -> list:
    """De chromatische klim (maat 23-24): per tel een powerchord, de gitaar in vier gedempte
    zestienden, de rest als kwartnoot."""
    result = []
    for tel, akkoord in enumerate(akkoorden):
        if partij == "gitaar":
            result += cycle(akkoord, 0.25, 1.0 + tel, 2.0 + tel)
        else:
            result += notes(f"{1.0 + tel} {akkoord} 1")
    return result


# akkoordvoicings van het couplet (brass | arp)
EM = ("E3+G3+B3+E4", "E5 G5 B5 E6")
C = ("C3+E3+G3+C4", "C5 E5 G5 C6")
D = ("D3+F#3+A3+D4", "D5 F#5 A5 D6")
B7 = ("B2+D#3+F#3+A3", "B4 D#5 F#5 B5")
F5 = ("F3+A3+C4+F4", "F5 A5 C6 F6")
# powerchords in de ligging van de brass (grondtoon, kwint, octaaf)
E5_BRASS, C5_BRASS, D5_BRASS = "E3+B3+E4", "C3+G3+C4", "D3+A3+D4"
G5_BRASS, B5_BRASS, F5_BRASS = "G3+D4+G4", "B2+F#3+B3", "F3+C4+F4"
# de gitaar: powerchord en gedempte tweeklank zoals de tabulatuur ze grijpt
GIT = {"E": ("E2+B2+E3", "E2+B2"), "C": ("C3+G3+C4", "C3+G3"), "D": ("D3+A3+D4", "D3+A3"),
       "G": ("G2+D3+G3", "G2+D3"), "B": ("B2+F#3+B3", "B2+F#3"), "F": ("F2+C3+F3", "F2+C3")}

SECTIES = [
    {"naam": "Intro – Turbo Ignition", "soort": "intro", "maten": (1, 4), "standaard": {"drums": BASIS_DRUMS}},
    {"naam": "Couplet – Cyber Highway", "soort": "thema", "maten": (5, 12), "standaard": {"drums": BASIS_DRUMS}},
    {"naam": "Refrein – Maximum Overdrive", "soort": "refrein", "maten": (13, 20), "standaard": {"drums": BASIS_DRUMS}},
    {"naam": "Breakdown & Chromatic Launchpad", "soort": "breakdown", "maten": (21, 24),
     "standaard": {"drums": BASIS_DRUMS}},
    # het hoogtepunt van het nummer ("het muzikale hoogtepunt van de track"): een tweede refrein
    {"naam": "Twin-Turbo Dual Solo", "soort": "refrein", "maten": (25, 28), "standaard": {"drums": BASIS_DRUMS}},
    {"naam": "Outro – Final Boss KO", "soort": "finale", "maten": (29, 32), "standaard": {"drums": BASIS_DRUMS}},
]

E_GALOP = galop("E2", "E3", "B2", "C3")
C_GALOP = galop("C2", "C3", "G2", "A2")
D_GALOP = galop("D2", "D3", "A2", "B2")
B_GALOP = galop("B1", "B2", "F#2", "G2")

MATEN = {
    # ------------------------------------------------------------------ sectie 1: intro
    # brass-stoten op stap 1, 4, 7, 9, 13 en 15 (tel 1.0, 1.75, 2.5, 3.0, 4.0, 4.5);
    # afgeleid: hun akkoord als powerchord van de maat (de tekst geeft geen voicing in de intro)
    1: {"akkoord": "E5",
        "bas": E_GALOP,
        "arp": arp("E5 G5 B5 E6 B5 G5 E6 E5"),
        "lead": notes("1.0 E5 0.5, 1.5 G5 0.5, 2.0 B5 0.5, 2.5 A5 0.5, 3.0 G5 0.5, 3.5 F#5 0.5, 4.0 G5 0.5, 4.5 E5 0.5"),
        "brass": notes(f"1.0 {E5_BRASS} 0.25, 1.75 {E5_BRASS} 0.25, 2.5 {E5_BRASS} 0.25, 3.0 {E5_BRASS} 0.25, "
                       f"4.0 {E5_BRASS} 0.25, 4.5 {E5_BRASS} 0.25"),
        "gitaar": notes("1.0 E2+B2+E3 1.5")},
    2: {"akkoord": "C5 D5",
        "bas": cycle("C2 C3", 0.25, 1, 3) + cycle("D2 D3", 0.25, 3, 5),
        "arp": arp("C5 E5 G5 C6 G5 E5 C6 C5"),
        "lead": notes("1.0 C6 0.5, 1.5 B5 0.5, 2.0 A5 0.5, 2.5 G5 0.5, 3.0 A5 0.5, 3.5 B5 0.5, 4.0 C6 0.5, 4.5 D6 0.5"),
        "brass": notes(f"1.0 {C5_BRASS} 0.25, 1.75 {C5_BRASS} 0.25, 2.5 {C5_BRASS} 0.25, 3.0 {D5_BRASS} 0.25, "
                       f"4.0 {D5_BRASS} 0.25, 4.5 {D5_BRASS} 0.25")},
    3: {"akkoord": "E5",
        "bas": E_GALOP,
        "arp": arp("E5 G5 B5 E6 B5 G5 E6 E5"),
        "lead": notes("1.0 E6 1.5, 2.5 D6 0.5, 3.0 B5 1, 4.0 G5 1"),
        "brass": notes(f"1.0 {E5_BRASS} 0.25, 1.75 {E5_BRASS} 0.25, 2.5 {E5_BRASS} 0.25, 3.0 {E5_BRASS} 0.25, "
                       f"4.0 {E5_BRASS} 0.25, 4.5 {E5_BRASS} 0.25"),
        "gitaar": notes("1.0 E2+B2+E3 1.5")},
    4: {"akkoord": "F5 F#5 G5 B5",
        # de chromatische Boss Stomp: gitaar, brass en lead klimmen mee
        "bas": run("F2 F3 F#2 F#3 G2 G3 B2 B3", 0.5),
        "arp": arp("F5 F#5 G5 B5 G5 F#5 B5 F5"),
        "lead": notes("1.0 F5 1, 2.0 F#5 1, 3.0 G5 1, 4.0 B5 1"),
        "brass": notes("1.0 F3+C4+F4 0.75, 2.0 F#3+C#4+F#4 0.75, 3.0 G3+D4+G4 0.75, 4.0 B2+F#3+B3 0.75"),
        "gitaar": notes("1.0 F2+C3+F3 0.75, 1.75 F2+C3 0.25 0.75, 2.0 F#2+C#3+F#3 0.75, 2.75 F#2+C#3 0.25 0.75, "
                        "3.0 G2+D3+G3 0.75, 3.75 G2+D3 0.25 0.75, 4.0 B2+F#3+B3 0.75, 4.75 B2+F#3 0.25 0.75")},

    # ------------------------------------------------------------------ sectie 2: couplet (gitaar stil)
    5: {"akkoord": "Em", "bas": E_GALOP, "arp": arp(EM[1]), "brass": offbeats(EM[0]),
        "lead": notes("1.0 E5 0.5, 1.5 G5 0.25, 1.75 A5 0.25, 2.0 B5 0.5, 2.5 E6 0.5, 3.0 D6 0.5, 3.5 B5 0.5, "
                      "4.0 A5 0.5, 4.5 G5 0.5")},
    6: {"akkoord": "C", "bas": C_GALOP, "arp": arp(C[1]), "brass": offbeats(C[0]),
        "lead": notes("1.0 A5 0.75, 1.75 G5 0.25, 2.0 E5 1, 3.0 G5 0.5, 3.5 A5 0.5, 4.0 B5 0.5, 4.5 C6 0.5")},
    7: {"akkoord": "D", "bas": D_GALOP, "arp": arp(D[1]), "brass": offbeats(D[0]),
        "lead": run("D6 C6 A5 F#5 D5 F#5 A5 D6", 0.5)},
    8: {"akkoord": "B7", "bas": B_GALOP, "arp": arp(B7[1]), "brass": offbeats(B7[0]),
        "lead": notes("1.0 D#6 1, 2.0 B5 1, 3.0 F#5 0.5, 3.5 G5 0.5, 4.0 A5 0.5, 4.5 B5 0.5"),
        # "+ 16-bit tom-fill"; afgeleid: op tel 4, in zestienden van hoog naar laag
        "drums": basis_tot(4.0) + drum_run("HT HT MT LT", 0.25, start=4)},
    # afgeleid (maat 9-12): de bas, die de ABC alleen voor maat 5-8 geeft, als galop op het akkoord
    9: {"akkoord": "Em", "bas": E_GALOP, "arp": arp(EM[1]), "brass": offbeats(EM[0]),
        "lead": notes("1.0 E6 0.5, 1.5 B5 0.5, 2.0 G6 1, 3.0 F#6 0.5, 3.5 E6 0.5, 4.0 D6 0.5, 4.5 B5 0.5")},
    10: {"akkoord": "C", "bas": C_GALOP, "arp": arp(C[1]), "brass": offbeats(C[0]),
         "lead": notes("1.0 C6 0.75, 1.75 D6 0.25, 2.0 E6 1, 3.0 D6 0.5, 3.5 C6 0.5, 4.0 B5 0.5, 4.5 A5 0.5")},
    11: {"akkoord": "F5", "bas": galop("F2", "F3", "C3", "D3"), "arp": arp(F5[1]), "brass": offbeats(F5[0]),
         # de Frygische afdaling
         "lead": run("F6 E6 D6 C6 B5 A5 G5 F5", 0.5)},
    12: {"akkoord": "B7", "bas": B_GALOP, "arp": arp(B7[1]), "brass": offbeats(B7[0]),
         # opbouw naar de refrein-drop
         "lead": notes("1.0 F#5 1, 2.0 B5 1, 3.0 D#6 1, 4.0 F#6 1")},

    # ------------------------------------------------------------------ sectie 3: refrein (gitaar vol gas)
    # afgeleid: de arp met de voicings van het couplet, de brass als off-beat-stoten in powerchords
    13: {"akkoord": "E5", "bas": E_GALOP, "arp": arp(EM[1]), "brass": offbeats(E5_BRASS),
         "gitaar": chugs(*GIT["E"]),
         "lead": notes("1.0 B5 1, 2.0 E6 0.5, 2.5 D6 0.5, 3.0 B5 0.5, 3.5 A5 0.5, 4.0 G5 0.5, 4.5 A5 0.5"),
         "drums": BASIS_DRUMS + drums(crash="1")},
    14: {"akkoord": "C5", "bas": C_GALOP, "arp": arp(C[1]), "brass": offbeats(C5_BRASS),
         "gitaar": chugs(*GIT["C"]),
         "lead": notes("1.0 G5 1, 2.0 C6 0.5, 2.5 B5 0.5, 3.0 A5 0.5, 3.5 G5 0.5, 4.0 E5 0.5, 4.5 G5 0.5")},
    15: {"akkoord": "D5", "bas": D_GALOP, "arp": arp(D[1]), "brass": offbeats(D5_BRASS),
         "gitaar": chugs(*GIT["D"]),
         "lead": notes("1.0 A5 1, 2.0 D6 0.5, 2.5 C6 0.5, 3.0 B5 0.5, 3.5 A5 0.5, 4.0 F#5 0.5, 4.5 A5 0.5")},
    16: {"akkoord": "G5 B5",
         "bas": run("G2 G2 G3 G2 B2 G2 G3 G2 B1 B1 B2 B1 F#2 B1 B2 B1", 0.25),
         "arp": arp("G5 B5 D6 G6", 1, 3) + arp(B7[1], 3, 5),
         "brass": offbeats(G5_BRASS, 1, 3) + offbeats(B5_BRASS, 3, 5),
         "gitaar": chugs(*GIT["G"], 1, 3) + chugs(*GIT["B"], 3, 5),
         "lead": notes("1.0 G6 1, 2.0 F#6 1, 3.0 D#6 1, 4.0 B5 1")},
    # maat 17-20: de gitaar herhaalt maat 13-16, met F5 en B5 in maat 19-20; afgeleid: de bas
    # als galop op die akkoorden
    17: {"akkoord": "E5", "bas": E_GALOP, "arp": arp(EM[1]), "brass": offbeats(E5_BRASS),
         "gitaar": chugs(*GIT["E"]),
         "lead": notes("1.0 B5 1, 2.0 E6 0.5, 2.5 F#6 0.5, 3.0 G6 1, 4.0 E6 1")},
    18: {"akkoord": "C5", "bas": C_GALOP, "arp": arp(C[1]), "brass": offbeats(C5_BRASS),
         "gitaar": chugs(*GIT["C"]),
         "lead": notes("1.0 E6 1, 2.0 D6 0.5, 2.5 C6 0.5, 3.0 B5 1, 4.0 A5 1")},
    19: {"akkoord": "F5", "bas": galop("F2", "F3", "C3", "D3"), "arp": arp(F5[1]), "brass": offbeats(F5_BRASS),
         "gitaar": chugs(*GIT["F"]),
         "lead": notes("1.0 C6 1, 2.0 F6 1, 3.0 E6 1, 4.0 C6 1")},
    20: {"akkoord": "B5", "bas": B_GALOP, "arp": arp(B7[1]), "brass": offbeats(B5_BRASS),
         "gitaar": chugs(*GIT["B"]),
         "lead": notes("1.0 D#6 1.5, 2.5 E6 0.5, 3.0 F#6 1, 4.0 B5 1")},

    # ------------------------------------------------------------------ sectie 4: breakdown en launchpad
    # maat 21-22: geen gitaar, "een strakke cyberpunk-groove"; afgeleid: de bas als galop op het
    # akkoord (A met F# als zesde, zoals E mineur hem heeft)
    21: {"akkoord": "Am7", "bas": galop("A1", "A2", "E2", "F#2"), "arp": arp("A4 C5 E5 A5"),
         "lead": notes("1.0 A5 1.5, 2.5 E5 1.5")},
    22: {"akkoord": "Em", "bas": E_GALOP, "arp": arp("G4 B4 E5 G5"),
         "lead": notes("1.0 G5 1.5, 2.5 E5 1.5")},
    # maat 23-24: de hele band klimt per kwartnoot chromatisch (gitaar, bas, brass, lead) met een
    # 1/16 snare/tom-roll; afgeleid: de bas in zestienden op de grondtoon (zoals de gitaar), de lead
    # en de brass per tel de grondtoon van het powerchord, de arp grondtoon-kwint-octaaf per tel,
    # de roll in maat 23 op de snare en in maat 24 over de toms omhoog
    23: {"akkoord": "E5 F5 F#5 G5",
         "gitaar": klim(["E2+B2+E3", "F2+C3+F3", "F#2+C#3+F#3", "G2+D3+G3"], "gitaar"),
         "bas": cycle("E2", 0.25, 1, 2) + cycle("F2", 0.25, 2, 3) + cycle("F#2", 0.25, 3, 4) + cycle("G2", 0.25, 4, 5),
         "brass": klim(["E3+B3+E4", "F3+C4+F4", "F#3+C#4+F#4", "G3+D4+G4"], "brass"),
         "lead": notes("1.0 E5 1, 2.0 F5 1, 3.0 F#5 1, 4.0 G5 1"),
         "arp": run("E5 B5 E6 B5 F5 C6 F6 C6 F#5 C#6 F#6 C#6 G5 D6 G6 D6", 0.25),
         "drums": drums(kick="4") + drum_run("S S S S S S S S S S S S S S S S", 0.25, velocity=0.85)},
    24: {"akkoord": "G#5 A5 A#5 B5",
         "gitaar": klim(["G#2+D#3+G#3", "A2+E3+A3", "A#2+F3+A#3", "B2+F#3+B3"], "gitaar"),
         "bas": cycle("G#2", 0.25, 1, 2) + cycle("A2", 0.25, 2, 3) + cycle("A#2", 0.25, 3, 4) + cycle("B2", 0.25, 4, 5),
         "brass": klim(["G#3+D#4+G#4", "A3+E4+A4", "A#3+F4+A#4", "B3+F#4+B4"], "brass"),
         "lead": notes("1.0 G#5 1, 2.0 A5 1, 3.0 A#5 1, 4.0 B5 1"),
         "arp": run("G#5 D#6 G#6 D#6 A5 E6 A6 E6 A#5 F6 A#6 F6 B5 F#6 B6 F#6", 0.25),
         "drums": drums(kick="4") + drum_run("LT LT LT LT MT MT MT MT HT HT HT HT S S S S", 0.25, velocity=0.9)},

    # ------------------------------------------------------------------ sectie 5: twin-turbo dual solo
    # gitaar en lead in parallelle tertsen; afgeleid: arp en brass met de voicings van het couplet
    25: {"akkoord": "Em", "bas": E_GALOP, "arp": arp(EM[1]), "brass": offbeats(EM[0]),
         "solo": run("E6 D6 C6 B5 C6 D6 E6 D6 C6 B5 A5 B5 C6 B5 A5 G5", 0.25),
         "lead": run("G6 F#6 E6 D6 E6 F#6 G6 F#6 E6 D6 C6 D6 E6 D6 C6 B5", 0.25),
         "drums": BASIS_DRUMS + drums(crash="1")},
    26: {"akkoord": "C", "bas": C_GALOP, "arp": arp(C[1]), "brass": offbeats(C[0]),
         "solo": run("B5 C6 D6 E6 D6 C6 D6 E6 F#6 E6 D6 C6 D6 E6 F#6 G6", 0.25),
         "lead": run("D6 E6 F#6 G6 F#6 E6 F#6 G6 A6 G6 F#6 E6 F#6 G6 A6 B6", 0.25)},
    27: {"akkoord": "D", "bas": D_GALOP, "arp": arp(D[1]), "brass": offbeats(D[0]),
         "solo": run("F#6 E6 D6 E6 D6 C6 B5 C6 B5 A5 G5 A5 B5 C6 D6 E6", 0.25),
         "lead": run("A6 G6 F#6 G6 F#6 E6 D6 E6 D6 C6 B5 C6 D6 E6 F#6 G6", 0.25)},
    28: {"akkoord": "B7", "bas": galop("B1", "B2", "F#2", "A2"), "arp": arp(B7[1]), "brass": offbeats(B7[0]),
         # de B7-climax in harmonisch mineur, achtsten
         "solo": run("D#6 B5 F#5 B5 D#6 F#6 D#6 F#6", 0.5),
         "lead": run("F#6 D#6 B5 D#6 F#6 B6 F#6 B6", 0.5)},

    # ------------------------------------------------------------------ sectie 6: outro, final boss KO
    # afgeleid: de bas als galop, de arp en de brass zoals in het refrein
    29: {"akkoord": "E5", "bas": E_GALOP, "arp": arp(EM[1]), "brass": offbeats(E5_BRASS),
         "gitaar": chugs(*GIT["E"]),
         "lead": notes("1.0 E6 1, 2.0 G6 1, 3.0 F#6 1, 4.0 E6 1"),
         "drums": BASIS_DRUMS + drums(crash="1")},
    30: {"akkoord": "C5 D5",
         # gitaar en bas schakelen halverwege van C5 naar D5; afgeleid: de bas zoals in maat 2
         # (dezelfde wissel), de gitaar met de halve-maat-chugs van maat 16, de arp het figuur van
         # maat 2 op C en daarna op D
         "bas": cycle("C2 C3", 0.25, 1, 3) + cycle("D2 D3", 0.25, 3, 5),
         "gitaar": chugs(*GIT["C"], 1, 3) + chugs(*GIT["D"], 3, 5),
         "arp": arp("C5 E5 G5 C6 G5 E5 C6 C5", 1, 3) + arp("D5 F#5 A5 D6 A5 F#5 D6 D5", 3, 5),
         "brass": offbeats(C5_BRASS, 1, 3) + offbeats(D5_BRASS, 3, 5),
         "lead": notes("1.0 D6 1, 2.0 C6 1, 3.0 D6 1, 4.0 F#6 1")},
    31: {"akkoord": "E5 G5 A5 Bb5 B5 D5",
         # de unisono blues-metal break: gitaar, bas, brass, lead en kick+snare exact hetzelfde
         # ritme (3/16, 3/16, 1/8, 1/8, 1/8, 1/4); de lead en de bas zoals de ABC ze schrijft, de
         # gitaar zoals de tabulatuur; afgeleid: de brass in powerchords, de arp zwijgt (niet genoemd)
         "gitaar": notes("1.0 E2+B2+E3 0.75, 1.75 G2+D3+G3 0.75, 2.5 A2+E3+A3 0.5, 3.0 Bb2+F3+Bb3 0.5, "
                         "3.5 B2+F#3+B3 0.5, 4.0 D3+A3+D4 1"),
         "bas": notes("1.0 E2 0.75, 1.75 G2 0.75, 2.5 A2 0.5, 3.0 Bb2 0.5, 3.5 B2 0.5, 4.0 D3 1"),
         "brass": notes("1.0 E3+B3+E4 0.75, 1.75 G3+D4+G4 0.75, 2.5 A3+E4+A4 0.5, 3.0 Bb3+F4+Bb4 0.5, "
                        "3.5 B3+F#4+B4 0.5, 4.0 D4+A4+D5 1"),
         "lead": notes("1.0 E5 0.75, 1.75 G5 0.75, 2.5 A5 0.5, 3.0 Bb5 0.5, 3.5 B5 0.5, 4.0 D6 1"),
         "drums": drums(kick="1 1.75 2.5 3 3.5 4", snare="1 1.75 2.5 3 3.5 4")},
    32: {"akkoord": "E5",
         # de eindklap op tel 1, 14 zestienden lang; de PSG speelt de Sega Power-Down Cascade
         # (afgeleid: in zestienden, het tempo van de arp)
         "gitaar": notes("1.0 E2+B2+E3+B3+E4 3.5"),
         "bas": notes("1.0 E1 3.5"),
         "brass": notes("1.0 E3+G3+B3+E4+G4 3.5"),
         "lead": notes("1.0 E6 3.5"),
         "arp": run("E6 B5 G5 E5 B4 G4 E4 B3 E3", 0.25),
         "drums": drums(kick="1", snare="1", crash="1")},
}
