"""Style profile 'synthwave_rpg': a 16-bit synthwave action-RPG soundtrack on the Mega Drive.

From the brief (a Gemini/Suno description, November 2026): a heroic, upbeat, triumphant
16-bit battle theme in the manner of early-90s Japanese action-RPG music on the Sega Genesis:
a punchy metallic YM2612 "solid" bass in sixteenths with octave jumps, fast PSG arpeggios
(D5 F5 A5 D6), a square-wave chiptune lead with a fast driver vibrato, melodic "electric
guitar" leads (an FM voice with high feedback driven into overdrive, bends, vibrato, a second
guitar in thirds), power chords (one FM channel with operators on the fifth and the octave),
FM brass stabs on 2 and 4, warm two-voice FM pads, dry tight PCM kicks and the 80s gated
snare through the DAC, PSG-noise hats and crashes, a tape stop at the very end.
120 BPM, D minor, the heart of the harmony i - VI - III - VII (Dm Bb F C).

Within the chip: five FM voices (the sixth channel is the DAC playing the drums), three PSG
squares and the PSG noise. A chord is two FM voices (a dyad) or one power-chord voice; the
lush "wall of sound" is the pad and the brass taking turns, not all at once.

Chords are Roman numerals in KEY/MODE ("i", "VI", "III", "VII", "iv", "V7", "VImaj7",
"VIIsus", "bII", ...; upper case major, lower case minor), so another key is one line here.
Melodies in the pieces use chord degrees (R 3 5 7 8 9), the motif (M ...) and scale degrees
(^1 .. ^7, ' an octave up, , down: see style.py), so they follow the key of the profile.
"""
from megadrive import FmPatch, Operator

NAME = "synthwave_rpg"
DESCRIPTION = "16-bit synthwave action-RPG (Mega Drive): heroisch, 120 BPM, D mineur, i-VI-III-VII"

KEY = "D"
MODE = "minor"           # style.SCALES: minor, major, dorian, harmonic_minor, phrygian

## The motif: four notes in two beats (sixteenths per note), on the chord of its bar: the
## root, the fifth above, the octave, then the step of the scale below that octave (over Dm:
## D5 A5 D6 C6; over Bb: Bb4 F5 Bb5 A5). Heroic: a leap up and a turn. Variants:
## "^" rising (ends on the ninth above the octave), "!" tough (root, third, fifth, root below).
MOTIF_RHYTHM = (2, 1, 1, 4)
MOTIF_ARTICULATION = (0.7, 0.8, 0.8, 0.85)
MOTIF_VARIANTS = {
    "": ("R", "5", "8", "7"),
    "^": ("R", "5", "8", "9'"),
    "!": ("R", "3", "5", "R,"),
}

TEMPOS = {"stad": 120, "gevecht": 120, "menu": 120, "intro": 120, "handelaar": 120, "laden": 100,
          "karakterkeuze": 96, "deuntjes": 120}

## The drum kit through the DAC: "tight" or "fat" kick, "gated" or "plain" snare, and how
## long the gate holds the snare's room open (s).
DRUMS = {"kick": "tight", "snare": "gated", "gate_seconds": 0.17, "fm_snare": True}

# ----------------------------------------------------------------------------- the patches

# punchy, metallic FM bass: a short bright attack (operator 3 at x3), feedback for the growl
SOLID_BASS = FmPatch("solid bass", algorithm=4, feedback=1.05, operators=(
    Operator(ratio=1.0, level=2.6, attack=0.001, decay=0.07, sustain=0.35, release=0.03, velocity_to_level=0.8),
    Operator(ratio=1.0, level=0.95, attack=0.001, decay=0.35, sustain=0.65, release=0.03),
    Operator(ratio=3.0, level=1.6, attack=0.001, decay=0.025, sustain=0.05, release=0.02, velocity_to_level=0.9),
    Operator(ratio=0.5, level=0.45, attack=0.001, decay=0.3, sustain=0.6, release=0.03),
))
SLAP_BASS = FmPatch("slap bass", algorithm=4, feedback=0.9, operators=(
    Operator(ratio=1.0, level=3.0, attack=0.001, decay=0.06, sustain=0.25, release=0.03, velocity_to_level=0.8),
    Operator(ratio=1.0, level=0.9, attack=0.001, decay=0.5, sustain=0.6, release=0.03),
    Operator(ratio=3.0, level=1.8, attack=0.001, decay=0.02, sustain=0.0, release=0.02, velocity_to_level=0.9),
    Operator(ratio=1.0, detune_cents=4, level=0.5, attack=0.001, decay=0.25, sustain=0.4, release=0.03),
))
# the singing synth lead (the "soaring polyphonic lead", one voice here), delayed vibrato
SYNTH_LEAD = FmPatch("synth lead", algorithm=4, feedback=1.2, vibrato_depth=0.25, vibrato_rate=5.8, vibrato_delay=0.2,
                     operators=(
    Operator(ratio=1.0, level=1.5, attack=0.004, decay=0.3, sustain=0.7, release=0.08),
    Operator(ratio=1.0, level=0.55, attack=0.004, decay=0.8, sustain=0.75, release=0.08),
    Operator(ratio=2.0, detune_cents=6, level=0.9, attack=0.008, decay=0.25, sustain=0.55, release=0.08),
    Operator(ratio=1.0, detune_cents=-6, level=0.42, attack=0.004, decay=0.8, sustain=0.75, release=0.08),
))
# the electric guitar: a saw-like voice from high feedback, a little bite at x3, overdriven
GUITAR = FmPatch("lead guitar", algorithm=4, feedback=1.5, vibrato_depth=0.35, vibrato_rate=6.2, vibrato_delay=0.16,
                 drive=3.2, operators=(
    Operator(ratio=1.0, level=1.6, attack=0.003, decay=0.4, sustain=0.75, release=0.09),
    Operator(ratio=1.0, level=0.6, attack=0.003, decay=1.2, sustain=0.85, release=0.09),
    Operator(ratio=3.0, detune_cents=4, level=0.7, attack=0.003, decay=0.2, sustain=0.4, release=0.09),
    Operator(ratio=1.0, detune_cents=-5, level=0.35, attack=0.003, decay=1.0, sustain=0.8, release=0.09),
))
# power chords on ONE channel: all four operators carriers, on the root, the fifth (x1.5) and
# the octave, the first with feedback, driven hard
POWER_CHORD = FmPatch("power chord", algorithm=7, feedback=1.3, drive=3.6, operators=(
    Operator(ratio=1.0, level=0.55, attack=0.002, decay=0.5, sustain=0.7, release=0.06),
    Operator(ratio=1.5, level=0.4, attack=0.002, decay=0.5, sustain=0.7, release=0.06),
    Operator(ratio=2.0, level=0.32, attack=0.002, decay=0.5, sustain=0.65, release=0.06),
    Operator(ratio=1.0, detune_cents=9, level=0.3, attack=0.002, decay=0.5, sustain=0.7, release=0.06),
))
BRASS_STAB = FmPatch("brass stab", algorithm=4, feedback=0.8, operators=(
    Operator(ratio=1.0, level=2.3, attack=0.008, decay=0.12, sustain=0.4, release=0.05),
    Operator(ratio=1.0, level=0.55, attack=0.004, decay=0.2, sustain=0.5, release=0.05),
    Operator(ratio=2.0, detune_cents=6, level=1.0, attack=0.01, decay=0.1, sustain=0.3, release=0.05),
    Operator(ratio=1.0, detune_cents=-6, level=0.45, attack=0.004, decay=0.2, sustain=0.5, release=0.05),
))
BRASS = FmPatch("brass", algorithm=4, feedback=0.6, vibrato_depth=0.08, vibrato_delay=0.3, operators=(
    Operator(ratio=1.0, level=1.9, attack=0.045, decay=0.4, sustain=0.65, release=0.08),
    Operator(ratio=1.0, level=0.5, attack=0.015, decay=0.6, sustain=0.8, release=0.08),
    Operator(ratio=1.0, detune_cents=8, level=1.3, attack=0.06, decay=0.5, sustain=0.6, release=0.08),
    Operator(ratio=1.0, detune_cents=-7, level=0.45, attack=0.02, decay=0.6, sustain=0.8, release=0.08),
))
# the warm "analog" pad: two detuned carriers fed by a soft modulator, slow attack
PAD = FmPatch("pad", algorithm=5, feedback=0.7, vibrato_depth=0.06, vibrato_rate=4.5, vibrato_delay=0.5, operators=(
    Operator(ratio=1.0, level=0.8, attack=0.4, decay=1.2, sustain=0.85, release=0.5),
    Operator(ratio=1.0, detune_cents=-11, level=0.32, attack=0.35, decay=1.0, sustain=0.9, release=0.5),
    Operator(ratio=1.0, detune_cents=11, level=0.32, attack=0.35, decay=1.0, sustain=0.9, release=0.5),
    Operator(ratio=2.0, detune_cents=4, level=0.12, attack=0.45, decay=1.0, sustain=0.9, release=0.5),
))
BELL = FmPatch("bell", algorithm=4, feedback=0.0, operators=(
    Operator(ratio=3.5, level=2.0, attack=0.001, decay=0.3, sustain=0.0, release=0.3),
    Operator(ratio=1.0, level=0.6, attack=0.001, decay=0.9, sustain=0.0, release=0.4),
    Operator(ratio=7.0, level=1.0, attack=0.001, decay=0.15, sustain=0.0, release=0.2),
    Operator(ratio=2.0, level=0.3, attack=0.001, decay=0.5, sustain=0.0, release=0.3),
))
# the nostalgic lead chime of the outros: a softer bell that rings long
CHIME = FmPatch("chime", algorithm=4, feedback=0.2, operators=(
    Operator(ratio=2.0, level=1.2, attack=0.001, decay=0.6, sustain=0.0, release=0.6),
    Operator(ratio=1.0, level=0.6, attack=0.002, decay=1.6, sustain=0.0, release=0.8),
    Operator(ratio=4.0, level=0.5, attack=0.001, decay=0.3, sustain=0.0, release=0.4),
    Operator(ratio=1.0, detune_cents=5, level=0.3, attack=0.002, decay=1.4, sustain=0.0, release=0.8),
))
# a plucked FM voice (harpsichord, folk guitar, market lute)
PLUCK = FmPatch("pluck", algorithm=4, feedback=0.9, operators=(
    Operator(ratio=3.0, level=1.6, attack=0.001, decay=0.08, sustain=0.0, release=0.05),
    Operator(ratio=1.0, level=0.7, attack=0.001, decay=0.35, sustain=0.0, release=0.12),
    Operator(ratio=5.0, level=0.9, attack=0.001, decay=0.05, sustain=0.0, release=0.05),
    Operator(ratio=1.0, detune_cents=4, level=0.3, attack=0.001, decay=0.3, sustain=0.0, release=0.12),
))
# the metallic FM snare layer of the intro (on an FM channel, over the DAC snare)
FM_SNARE = FmPatch("fm snare", algorithm=0, feedback=1.6, operators=(
    Operator(ratio=7.31, level=3.5, attack=0.001, decay=0.05, sustain=0.0, release=0.04),
    Operator(ratio=3.13, level=2.5, attack=0.001, decay=0.06, sustain=0.0, release=0.04),
    Operator(ratio=1.71, level=2.0, attack=0.001, decay=0.07, sustain=0.0, release=0.04),
    Operator(ratio=1.0, level=0.9, attack=0.001, decay=0.09, sustain=0.0, release=0.05),
))
# metal clangs for the industry loop
METAL = FmPatch("metal", algorithm=4, feedback=0.5, operators=(
    Operator(ratio=1.41, level=3.2, attack=0.001, decay=0.15, sustain=0.0, release=0.1),
    Operator(ratio=1.0, level=0.6, attack=0.001, decay=0.45, sustain=0.0, release=0.2),
    Operator(ratio=3.73, level=2.2, attack=0.001, decay=0.08, sustain=0.0, release=0.05),
    Operator(ratio=0.5, level=0.45, attack=0.001, decay=0.3, sustain=0.0, release=0.1),
))

PATCHES = {"solid_bass": SOLID_BASS, "slap_bass": SLAP_BASS, "lead": SYNTH_LEAD, "guitar": GUITAR,
           "power": POWER_CHORD, "brass_stab": BRASS_STAB, "brass": BRASS, "pad": PAD, "bell": BELL,
           "chime": CHIME, "pluck": PLUCK, "fm_snare": FM_SNARE, "metal": METAL}
## The voice of the motif (it is always played on this one).
SIGNATURE = "lead"

# ----------------------------------------------------------------------------- the plans

## The city loops: one plan for all of them (the HUD crossfades between them at the same
## playback position: same tempo, same length, the same chord in every bar). 48 bars = 96 s.
CITY_SECTIONS = [
    ("A", ["i", "VI", "III", "VII", "i", "VI", "III", "VII"]),
    ("A2", ["i", "VI", "III", "VII", "iv", "VI", "VIIsus", "VII"]),
    ("B", ["VI", "VII", "i", "i", "VI", "VII", "V", "V7"]),
    ("break", ["VImaj7", "VImaj7", "iv", "V"]),
    ("C", ["i", "VI", "III", "VII", "i", "VI", "VII", "V"]),
    ("D", ["iv", "i", "VI", "III", "iv", "i", "V", "V7"]),
    ("tag", ["i", "VI", "VII", "V"]),
]
## The battle loop (gevecht): 32 bars = 64 s.
BATTLE_SECTIONS = [
    ("A", ["i", "VI", "III", "VII", "i", "VI", "VII", "VII"]),
    ("B", ["i", "VI", "III", "VII", "i", "VI", "III", "VII"]),
    ("solo", ["iv", "i", "VI", "VII", "iv", "i", "V", "V7"]),
    ("climax", ["i", "VI", "III", "VII", "VI", "VII", "V", "V7"]),
]
## The main menu loop: 32 bars = 64 s.
MENU_SECTIONS = [
    ("A", ["i", "VI", "III", "VII", "i", "VI", "III", "VII"]),
    ("B", ["VI", "VII", "i", "i", "VI", "VII", "V", "V"]),
    ("C", ["i", "VI", "III", "VII", "iv", "VI", "VII", "V7"]),
    ("D", ["VI", "VII", "III", "VI", "iv", "i", "V", "V7"]),
]
## The intro (scripts/ui/intro.gd runs on it): 60 bars = 120 s at 120 BPM (a bar is 2 s).
INTRO_SECTIONS = [
    ("intro", ["i", "i", "VI", "VII", "i", "VI", "VII", "V"]),                       # 0 - 16 s
    ("A", ["i", "VI", "III", "VII", "i", "VI", "III", "VII"] * 2),                    # 16 - 48 s
    ("B", ["i", "VI", "III", "VII", "i", "VI", "III", "VII", "VI", "VII", "i", "i", "VI", "VII", "V", "V7"]),  # 48 - 80 s
    ("duel", ["iv", "i", "VI", "VII", "iv", "i", "VI", "VII", "iv", "VI", "V", "V7"]),  # 80 - 104 s
    ("outro", ["i", "VI", "III", "VII", "i", "VI", "VII", "i"]),                       # 104 - 120 s
]
## Shorter loops.
MERCHANT_CHORDS = ["i", "VI", "III", "VII", "iv", "VI", "VII", "V7"] * 2              # 16 bars
LOADING_CHORDS = ["i", "VImaj7", "III", "VIIsus", "iv", "VImaj7", "VII", "Vsus"] * 2  # 16 bars
CHARACTER_CHORDS = ["i", "VImaj7", "III", "VII", "iv", "VImaj7", "VIIsus", "V"] * 2   # 16 bars

## Per piece: what sets it apart within the style (the pieces read these; see each file).
PIECES = {
    # the city: one family, each neighbourhood its own colour
    "stad_centrum": {"swing": 0.08, "bass": "solid", "energy": 0.85, "guitar": True},
    "stad_torens": {"swing": 0.0, "bass": "offbeat", "energy": 0.75, "guitar": False},
    "stad_groen": {"swing": 0.0, "bass": "hold", "energy": 0.35, "guitar": False},
    "stad_woonwijk": {"swing": 0.16, "bass": "slap", "energy": 0.8, "guitar": True},
    "stad_industrie": {"swing": 0.0, "bass": "drive", "energy": 0.95, "guitar": True},
    "stad_hofstad": {"swing": 0.0, "bass": "whole", "energy": 0.4, "guitar": False},
    "stad_markt": {"swing": 0.1, "bass": "lyrical", "energy": 0.6, "guitar": False},
    "stad_bos": {"swing": 0.0, "bass": "whole", "energy": 0.2, "guitar": False},
    "stad_dorp": {"swing": 0.06, "bass": "walking", "energy": 0.45, "guitar": False},
    "gevecht": {"swing": 0.0},
    "nachtstad_menu": {"swing": 0.0},
    "zwervr_intro": {"swing": 0.0},
    "handelaar": {"swing": 0.12},
    "laden": {"swing": 0.1},
    "karakterkeuze": {"swing": 0.0},
}
## The background mix of the city loops (gain per track), their top and density.
CITY_BACKGROUND_GAINS = {"pcm drums": 0.42, "psg noise": 0.14, "lead": 0.42, "guitar": 0.3, "harmony": 0.24,
                         "brass": 0.28, "bass": 0.52, "psg 1": 0.15, "psg 2": 0.14, "psg 3": 0.12, "fm drums": 0.12}
CITY_LOW_PASS_HZ = 8000.0
CITY_TARGET_RMS_DB = -17.0
