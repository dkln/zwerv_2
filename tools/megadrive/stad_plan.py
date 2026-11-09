"""The shared plan of the city loops (stad_centrum, stad_torens, stad_groen, stad_woonwijk,
stad_industrie, stad_hofstad, stad_markt, stad_bos, stad_dorp): one tempo, one length and one
chord per bar for all of them, and one background mix (finish).

The HUD crossfades between the loops when you walk into another neighbourhood and starts the
new loop at the playback position of the old one (scripts/ui/hud.gd, CITY_MUSIC_BY_AREA).
Because every loop is 40 bars at 104 BPM (92 s) on this same harmony, the crossfade lands in the
same bar, on the same chord, in the same section: only the arrangement changes.

    bars  1-8   A      Fm7 Gbmaj7 Bbm7 Fm7 Fm7 Gbmaj7 Ab6 C7
    bars  9-16  A'     the same
    bars 17-24  B      Bbm9 Bbm9 Gbmaj7 Gbmaj7 Abmaj7 Eb6 Csus C7
    bars 25-28  break  Gbmaj7 Gbmaj7 Bbm7 C7
    bars 29-36  C      Gbmaj7 Ab6 Fm7 Fm7 Gbmaj7 Ab6 Gm7b5 C7
    bars 37-40  tag    Fm7 Gbmaj7 Bbm7 C7  (leads back to bar 1)

They are background music for walking round: unhurried (104 BPM) and mixed back (finish):
the drums, the lead, the hats and the brass lower than in the other pieces, the top rounded
off, a little softer overall.

House style: style.py and docs/MUZIEK.md.
"""
from style import chords

BPM = 104
## The background mix of the city loops: the gain of each track (the house mix in style.Song is
## for music you listen to), the top rounded off at LOW_PASS_HZ, the loudness.
BACKGROUND_GAINS = {"pcm drums": 0.42, "psg noise": 0.14, "lead": 0.42, "brass": 0.3, "bass": 0.52,
                    "psg 1": 0.16, "psg 2": 0.16}
LOW_PASS_HZ = 7500.0
TARGET_RMS_DB = -17.0
BARS = 40

A_CHORDS = chords(["F m7", "Gb maj7", "Bb m7", "F m7", "F m7", "Gb maj7", "Ab 6", "C 7"])
B_CHORDS = chords(["Bb m9", "Bb m9", "Gb maj7", "Gb maj7", "Ab maj7", "Eb 6", "C sus", "C 7"])
BREAK_CHORDS = chords(["Gb maj7", "Gb maj7", "Bb m7", "C 7"])
C_CHORDS = chords(["Gb maj7", "Ab 6", "F m7", "F m7", "Gb maj7", "Ab 6", "G m7b5", "C 7"])
TAG_CHORDS = chords(["F m7", "Gb maj7", "Bb m7", "C 7"])

# (name, first bar, chords)
SECTIONS = [
    ("A", 0, A_CHORDS),
    ("A2", 8, A_CHORDS),
    ("B", 16, B_CHORDS),
    ("break", 24, BREAK_CHORDS),
    ("C", 28, C_CHORDS),
    ("tag", 36, TAG_CHORDS),
]


def finish(song, target_rms_db: float = TARGET_RMS_DB) -> None:
    """Mixes a city loop back for the background (BACKGROUND_GAINS, LOW_PASS_HZ) and renders it."""
    for track in song.tracks:
        if track.name in BACKGROUND_GAINS:
            track.gain = BACKGROUND_GAINS[track.name]
    song.render(target_rms_db=target_rms_db, low_pass_hz=LOW_PASS_HZ)


def theme(*bars: str) -> str:
    """A lead phrase from one text per bar (each 16 sixteenths: see style.phrase)."""
    return " ".join(bars)


def bars_of(first_bar: int, section_chords):
    """(bar, offset in the section, chord, is the last bar of the section) for every bar."""
    for offset, chord in enumerate(section_chords):
        yield first_bar + offset, offset, chord, offset == len(section_chords) - 1
