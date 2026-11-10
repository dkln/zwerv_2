"""The shared plan of the city loops (stad_centrum, stad_torens, stad_groen, stad_woonwijk,
stad_industrie, stad_hofstad, stad_markt, stad_bos, stad_dorp): one tempo, one length and one
chord per bar for all of them, and one background mix (finish). The plan itself is in the
active style profile (CITY_SECTIONS, TEMPOS["stad"], CITY_BACKGROUND_GAINS ...).

The HUD crossfades between the loops when you walk into another neighbourhood and starts the
new loop at the playback position of the old one (scripts/ui/hud.gd, CITY_MUSIC_BY_AREA).
Because every loop has the same tempo, length and harmony, the crossfade lands in the same
bar, on the same chord, in the same section: only the arrangement changes.

In synthwave_rpg (120 BPM, D minor, 48 bars = 96 s):
    bars  1-8   A      i VI III VII  i VI III VII           (Dm Bb F C ...)
    bars  9-16  A2     i VI III VII  iv VI VIIsus VII
    bars 17-24  B      VI VII i i  VI VII V V7              (the lift to the dominant)
    bars 25-28  break  VImaj7 VImaj7 iv V
    bars 29-36  C      i VI III VII  i VI VII V             (the peak)
    bars 37-44  D      iv i VI III  iv i V V7
    bars 45-48  tag    i VI VII V  (leads back to bar 1)

They are background music for walking round, mixed back (finish): the drums, the lead, the
hats and the brass lower than in the other pieces, the top rounded off.

House style: style.py and docs/MUZIEK.md.
"""
import style

PROFILE = style.PROFILE
BPM = style.tempo("stad")
BARS = style.plan_bars(PROFILE.CITY_SECTIONS)
## (name, first bar, chords) per section
SECTIONS = style.plan(PROFILE.CITY_SECTIONS)
SECTION_CHORDS = {name: section_chords for name, _, section_chords in SECTIONS}
SECTION_START = {name: first_bar for name, first_bar, _ in SECTIONS}


def finish(song, target_rms_db: float = None) -> None:
    """Mixes a city loop back for the background and renders it."""
    for track in song.tracks:
        if track.name in PROFILE.CITY_BACKGROUND_GAINS:
            track.gain = PROFILE.CITY_BACKGROUND_GAINS[track.name]
    song.render(target_rms_db=PROFILE.CITY_TARGET_RMS_DB if target_rms_db is None else target_rms_db,
                low_pass_hz=PROFILE.CITY_LOW_PASS_HZ)


def theme(*bars: str) -> str:
    """A lead phrase from one text per bar (each 16 sixteenths: see style.phrase)."""
    return " ".join(bars)


def bars_of(first_bar: int, section_chords):
    """(bar, offset in the section, chord, is the last bar of the section) for every bar."""
    for offset, bar_chord in enumerate(section_chords):
        yield first_bar + offset, offset, bar_chord, offset == len(section_chords) - 1


def new_song(file_name: str, piece_name: str):
    """A city loop on the plan, with the swing of its piece in the profile."""
    return style.Song(file_name, bpm=BPM, bars=BARS, swing=style.piece(piece_name)["swing"])


# ----------------------------------------------------------------------------- the city themes
# One family of melodies for every neighbourhood (in scale and chord degrees, so they follow
# the key of the profile); each loop plays them on its own voices, octaves and grooves, and
# may add its own. Written for the sections of synthwave_rpg's CITY_SECTIONS.

THEME_A2 = theme(
    "M -:2 ^5:2 ^7:4",
    "^6:6 ^5:2 ^4:4 ^3:4",
    "M ^2':4 ^1':4",
    "^7:12 -:4",
    "M ^1':4 ^6:4",
    "^6:4 ^1':4 ^3':4 ^1':4",
    "^7:6 ^4:2 ^5:4 ^7:4",
    "^7:8 -:8",
)
THEME_B = theme(
    "^6:4 ^1':4 ^4':4 ^3':4",
    "^2':6 ^1':2 ^7:4 ^2':4",
    "^3':8 ^5:4 ^1':4",
    "^1':12 -:4",
    "^6:4 ^1':4 ^4':4 ^3':4",
    "^5':6 ^4':2 ^3':4 ^2':4",
    "3':4 8:4 5:4 3:4",
    "M 3':4 5':4",
)
THEME_C = theme(
    "^1':4 ^7:2 ^1':2 ^2':4 ^3':4",
    "^4':6 ^3':2 ^1':4 ^6:4",
    "^5:4 ^1':4 ^3':6 ^2':2",
    "^2':8 ^7:4 ^5:4",
    "M ^3':4 ^1':4",
    "^6:4 ^1':4 ^4':4 ^3':4",
    "^2':6 ^1':2 ^7:8",
    "M 5:4 3:4",
)
THEME_D = theme(
    "^4:8 ^6:4 ^1':4",
    "^1':6 ^7:2 ^5:8",
    "^6:4 ^5:4 ^4:4 ^6:4",
    "^5:12 -:4",
    "^4:8 ^6:4 ^1':4",
    "^3':6 ^2':2 ^1':8",
    "8:6 5:2 3:8",
    "M -:8",
)
## The motif softly in the break, and once in the tag.
THEME_BREAK = "M -:8 -:16 M -:8 -:16"
THEME_TAG = "M -:8 -:16 -:16 -:16"
THEMES = {"A2": THEME_A2, "B": THEME_B, "C": THEME_C, "D": THEME_D, "break": THEME_BREAK, "tag": THEME_TAG}


def section(name: str):
    """(first bar, chords) of a section of the plan."""
    return SECTION_START[name], SECTION_CHORDS[name]
