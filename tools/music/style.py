"""The house sound shared by every piece, so all music is recognisably the same game.

Everything a song needs comes from here: the motif (fitted to any chord), a theme generator built
on the motif, the track set with fixed instruments and mix settings (StyleTracks), the drum kit and
grooves, rolling bass, supersaw pads, ping-pong motif arp, brass, e-piano, the synth lead with its
3/16 echo, the darksynth guitars, and the big effects (tape stop, stutter, filter build, impacts).

Ingredients of the style (modelled on the reference track voorbeeld.mp3, see analyze.py):
  - key F minor (written in E minor, see theory.KEY_TRANSPOSE), heart of the harmony i - bII - iv:
    Em F Am (+ G, Bm); the bII (F) gives the dark, tough Phrygian colour
  - the motif: four short, hard notes in two beats (root, third, step, fifth below) on every chord
  - energetic, not triumphant: drive from drums, rolling 16th bass, chugs and arps
  - bright: supersaw pad + chorus, ping-pong pluck arp in the motif rhythm, polysynth brass,
    DX7 e-piano, chorused saw lead; 8-bit square lead as signature voice
  - drum machine kit up front (style.KIT): 909-style kick, open warm snare, 808 clap and metallic hats,
    ghost notes, off-beat open hats, tom fills; own samples in tools/music/drums/ replace them
  - effects at section changes: reverse crash + closing filter into drops, impacts, tape stops,
    beat-repeat stutters
  - now and then a music filter (filter_dip, filter_open_up): the music goes dull and opens up again
    while the drums keep hitting
"""
import pathlib

import instruments as inst
from patterns import play_melody, play_steps
from synth import MUSIC_FILTER_OPEN, SAMPLE_RATE, chorus, lowpass, master_filter_sweep, stutter, tape_stop
from theory import CHORDS, PITCH_CLASSES, REST, midi, third_above

# ---------------------------------------------------------------------------------------------
# The motif and themes
# ---------------------------------------------------------------------------------------------

MOTIF_RHYTHM = [0.5, 0.25, 0.25, 1.0]  # short and punchy: 8th, two 16ths, quarter = 2 beats
MELODY_LOWEST = midi("D5")             # roots of melody phrases sit between D5 and C#6
MAIN_PROGRESSION = ["Em", "F", "Am", "Em"]


def chord_root_in_register(chord_name):
    root_class = PITCH_CLASSES[CHORDS[chord_name]["tones"][0]]
    return next(pitch for pitch in range(MELODY_LOWEST, MELODY_LOWEST + 12) if pitch % 12 == root_class)


def chord_third_interval(chord_name):
    tones = [PITCH_CLASSES[tone] for tone in CHORDS[chord_name]["tones"]]
    return (tones[1] - tones[0]) % 12


def is_minor(chord_name):
    return chord_third_interval(chord_name) == 3


def motif_notes(chord_name, tough=False):
    """The motif on a chord: root, third, the step above the root, then the fifth below.
    `tough` ends on the flat seventh instead (minor chords only). Over Em: E5 G5 F#5 B4."""
    root = chord_root_in_register(chord_name)
    ending = root - 2 if tough and is_minor(chord_name) else root - 5
    return [root, root + chord_third_interval(chord_name), root + 2, ending]


def motif_shape(notes, rest_beats=2.0):
    """The motif rhythm on four notes, followed by a rest (one bar in total by default)."""
    shape = list(zip(notes, MOTIF_RHYTHM))
    return shape + [(REST, rest_beats)] if rest_beats else shape


def motif_for(chord_name, tough=False, rest_beats=2.0):
    return motif_shape(motif_notes(chord_name, tough), rest_beats)


MOTIF_NOTES = ["E5", "G5", "F#5", "B4"]
MOTIF = motif_for("Em")                       # one bar: E G F# B + rest
MOTIF_TOUGH = motif_for("Em", tough=True)     # E G F# D: the harder second hit
MOTIF_ANSWER = motif_for("B7")                # over B7, leads home to E
MOTIF_MAJOR = motif_for("E")                  # over E major (wins, level up)


def motif_calls(chords):
    """One motif phrase per bar, fitted to each chord."""
    return [motif_for(chord_name) for chord_name in chords]


def theme_from_chords(chords):
    """A lead melody that states the motif in every bar and answers it in a 4-bar cycle:
    answer down, tough hit, held third, little run home."""
    melody = []
    for index, chord_name in enumerate(chords):
        root = chord_root_in_register(chord_name)
        third = root + chord_third_interval(chord_name)
        fifth = root + 7 if root + 7 <= midi("C#6") else root - 5
        bar_kind = index % 4
        if bar_kind == 0:
            melody += motif_for(chord_name, rest_beats=0) + [(fifth, 0.5), (third, 0.5), (root, 1)]
        elif bar_kind == 1:
            melody += motif_for(chord_name, tough=True)
        elif bar_kind == 2:
            melody += motif_for(chord_name, rest_beats=0) + [(third, 1.5), (REST, 0.5)]
        else:
            melody += motif_for(chord_name, rest_beats=0) + [(fifth, 0.5), (third, 0.5), (root + 2, 0.5), (root, 0.5)]
    return melody


def harmony_line(melody, chords, beats_per_bar=4):
    """The melody a third higher, chord-aware per bar (`chords` = chord name per bar)."""
    harmonized = []
    position = 0.0
    for note, length in melody:
        bar_index = min(int(position // beats_per_bar), len(chords) - 1)
        harmonized.append((note if note == REST else third_above(note, chords[bar_index]), length))
        position += length
    return harmonized


# ---------------------------------------------------------------------------------------------
# Tracks
# ---------------------------------------------------------------------------------------------

def pad_tone(buffer):
    return chorus(lowpass(buffer, 5500))


class StyleTracks:
    """All tracks of the house sound. `levels` scales volumes per track name (e.g. a softer lead)."""

    def __init__(self, song, levels=None):
        levels = levels or {}

        unfiltered = {"kick", "snare", "ghost_snare", "clap", "hats", "open_hats", "toms", "cymbals",
                      "noise_riser", "impacts", "fx"}

        drum_kit = {"kick", "snare", "ghost_snare", "clap", "hats", "open_hats", "toms"}

        def make(name, volume, **settings):
            return song.track(name, volume=volume * levels.get(name, 1.0), music_filter=name not in unfiltered,
                              drum_bus=name in drum_kit, **settings)

        self.pad = make("pad", 0.28, reverb_send=0.4, sidechain=0.55).process(pad_tone)
        self.intro_pad = make("intro_pad", 0.4, reverb_send=0.4)
        self.epiano = make("epiano", 0.36, pan=-0.25, reverb_send=0.35, sidechain=0.3)
        self.brass = make("brass", 0.2, pan=0.2, reverb_send=0.35, sidechain=0.3).process(chorus)
        self.arp_left = make("arp_left", 0.3, pan=-0.75, reverb_send=0.3, sidechain=0.3).process(chorus)
        self.arp_right = make("arp_right", 0.3, pan=0.75, reverb_send=0.3, sidechain=0.3).process(chorus)
        self.lead = make("synth_lead", 0.5, pan=0.05, reverb_send=0.3).process(chorus)
        self.lead_echo = make("synth_echo", 0.16, pan=0.5, reverb_send=0.3)
        self.harmony = make("synth_harmony", 0.2, pan=-0.35, reverb_send=0.3).process(chorus)
        self.chip = make("chip_lead", 0.24, pan=0.1, reverb_send=0.25)
        self.chip_echo = make("chip_echo", 0.15, pan=-0.45, reverb_send=0.2)
        self.chip_arp = make("chip_arp", 0.25, pan=-0.2, reverb_send=0.25)
        self.bass = make("bass", 0.6, sidechain=0.7)
        self.sub = make("sub", 0.35)
        self.guitar_left = make("guitar_left", 0.3, pan=-0.9, sidechain=0.25).process(inst.guitar_cabinet)
        self.guitar_right = make("guitar_right", 0.3, pan=0.9, sidechain=0.25).process(inst.guitar_cabinet)
        self.lead_guitar = make("lead_guitar", 0.26, pan=-0.25, reverb_send=0.22).process(inst.guitar_cabinet)
        self.harmony_guitar = make("harmony_guitar", 0.17, pan=0.3, reverb_send=0.22).process(inst.guitar_cabinet)
        self.kick = make("kick", 0.9)
        self.snare = make("snare", 0.75, reverb_send=0.18)
        self.toms = make("toms", 0.6, pan=0.0, reverb_send=0.12)
        self.ghost_snare = make("ghost_snare", 0.2, pan=-0.1)
        self.clap = make("clap", 0.35, pan=0.1, reverb_send=0.15)
        self.hats = make("hats", 0.3, pan=0.35)
        self.open_hats = make("open_hats", 0.2, pan=-0.35, reverb_send=0.05)
        self.cymbals = make("cymbals", 0.26, pan=-0.15, reverb_send=0.12)
        self.noise = make("noise_riser", 0.12, reverb_send=0.3)
        self.impacts = make("impacts", 0.7, reverb_send=0.25)
        self.fx = make("fx", 0.35, reverb_send=0.1)


# ---------------------------------------------------------------------------------------------
# Drums
# ---------------------------------------------------------------------------------------------

class DrumKit:
    """The drum sounds of the house style; every drum hit goes through style.KIT."""

    def __init__(self, kick, snare, clap, hat, tom):
        self.kick = kick    # kick()
        self.snare = snare  # snare(gate_seconds=...)
        self.clap = clap    # clap()
        self.hat = hat      # hat(open_hat=False)
        self.tom = tom      # tom(pitch)

    def ghost(self):
        return self.snare() * 0.5

    def open_hat(self):
        return self.hat(True)


def sample_kit(folder):
    """A kit from your own one-shot samples: kick, snare, clap, hat, open_hat and tom (.wav/.ogg/.flac).
    Missing sounds fall back to the classic kit. Returns None when the folder has no samples."""
    import pathlib

    import numpy as np
    import soundfile

    folder = pathlib.Path(folder)
    loaded = {}
    for name in ("kick", "snare", "clap", "hat", "open_hat", "tom"):
        for extension in (".wav", ".ogg", ".flac", ".aif", ".aiff"):
            path = folder / (name + extension)
            if path.exists():
                audio, rate = soundfile.read(str(path), always_2d=True)
                mono = audio.mean(axis=1)
                if rate != SAMPLE_RATE:
                    positions = np.arange(0, len(mono), rate / SAMPLE_RATE)
                    mono = np.interp(positions, np.arange(len(mono)), mono)
                loaded[name] = mono / max(np.max(np.abs(mono)), 1e-9) * 0.9
                break
    if not loaded:
        return None
    fallback = CLASSIC_KIT

    def pick(name, fallback_sound):
        return (lambda *arguments: loaded[name]) if name in loaded else fallback_sound

    def pitched_tom(pitch=110.0):
        """The tom sample played at another pitch (110 Hz = as recorded), for the tom fills."""
        recorded = loaded["tom"]
        positions = np.arange(0, len(recorded), pitch / 110.0)
        return np.interp(positions, np.arange(len(recorded)), recorded)

    kit = DrumKit(pick("kick", fallback.kick), pick("snare", fallback.snare), pick("clap", fallback.clap),
                  pick("hat", fallback.hat), pitched_tom if "tom" in loaded else fallback.tom)
    if "snare" in loaded:  # the synthwave snare: the sample through a gated room (see inst.gated_room)
        gated = inst.gated_room(loaded["snare"])
        loaded["snare"] = gated / max(np.max(np.abs(gated)), 1e-9) * 0.9
    if "open_hat" in loaded:
        kit.open_hat = lambda: loaded["open_hat"]
    return kit


CLASSIC_KIT = DrumKit(inst.classic_kick, inst.open_warm_snare, inst.classic_clap, inst.classic_hat, inst.classic_tom)
HARD_KIT = DrumKit(inst.kick, inst.gated_snare, inst.analog_clap, inst.analog_hat, inst.gated_tom)
WARM_KIT = DrumKit(inst.warm_kick, inst.warm_snare, inst.warm_clap, inst.warm_hat, inst.warm_tom)
# Own samples in tools/music/drums/ (kick.wav, snare.wav, ...) win (now: the Roland TR-707); otherwise the classic kit.
# The classic kit plays the warm snare without its low-pass filters (inst.open_warm_snare);
# inst.classic_snare is the 909 one, inst.gated_snare the big gated one.
# Swap CLASSIC_KIT for HARD_KIT or WARM_KIT to hear the other synthesized kits.
KIT = sample_kit(pathlib.Path(__file__).parent / "drums") or CLASSIC_KIT


GROOVES = {  # one bar of 16th steps per instrument; "ghost" = soft snare notes between the hits
    "groove": {"kick": "X... ..x. X..x ....", "snare": ".... X... .... X...", "ghost": "...x .... .x.. ..x.",
               "hats": "Xx.x Xx.x Xx.x Xxxx", "open": "..x. ..x. ..x. ..x."},
    "four": {"kick": "X... X... X... X..x", "snare": ".... X... .... X...", "ghost": ".... ...x .... .x..",
             "hats": "Xx.x Xx.x Xx.x Xx.x", "open": "..x. ..x. ..x. ..x."},
    "battle": {"kick": "X..x ..x. X..x ..x.", "snare": ".... X... .... X..x", "ghost": "..x. ...x ..x. ....",
               "hats": "Xxxx Xxxx Xxxx Xxxx", "open": "..x. ..x. ..x. ..x."},
    "halftime": {"kick": "X... ...x ..x. ....", "snare": ".... .... X... ....", "ghost": "...x .x.. ...x .x..",
                 "hats": "Xx.x Xx.x Xx.x Xx.x", "open": ".... ..x. .... ..x."},
}
SNARE_FILL = ".... .... xxxx XX.."
TOM_FILL = [(3.5, 1.5), (3.625, 1.25), (3.75, 1.0), (3.875, 0.8)]  # (beat, pitch factor): high to low


def drums(song, tracks, bar, kit="groove", gain=1.0):
    grids = GROOVES[kit]
    play_steps(song, tracks.kick, KIT.kick, bar, grids["kick"], gain=gain, is_kick=True)
    play_steps(song, tracks.snare, KIT.snare, bar, grids["snare"], gain=gain)
    play_steps(song, tracks.clap, KIT.clap, bar, grids["snare"], gain=gain)
    play_steps(song, tracks.ghost_snare, KIT.ghost, bar, grids["ghost"], gain=gain)
    play_steps(song, tracks.hats, KIT.hat, bar, grids["hats"], gain=gain)
    play_steps(song, tracks.open_hats, KIT.open_hat, bar, grids["open"], gain=gain)


def snare_fill(song, tracks, bar, gain=0.8):
    """Snare 16ths into a gated tom roll down on the last half beat."""
    play_steps(song, tracks.snare, KIT.snare, bar, SNARE_FILL, gain=gain)
    for beat, pitch_factor in TOM_FILL:
        tracks.toms.add(KIT.tom(round(110 * pitch_factor, 1)), song.at(bar, beat), gain)


def crash(song, tracks, time, gain=1.0):
    tracks.cymbals.add(inst.crash(), time, gain)


# ---------------------------------------------------------------------------------------------
# Effects at section changes
# ---------------------------------------------------------------------------------------------

def build_into(song, tracks, target_bar, bars=2, lowest_cutoff=700):
    """Before a drop: the whole mix closes through a resonant filter, a reverse crash swells up."""
    song.master_effect(master_filter_sweep(song.at(target_bar - bars), song.at(target_bar), 16000, lowest_cutoff))
    swell = inst.reverse_crash(round(song.bar, 3))
    tracks.cymbals.add(swell, song.at(target_bar) - len(swell) / SAMPLE_RATE, 1.2)


def drop_hit(song, tracks, bar):
    """On the downbeat of a drop: impact, crash and a falling noise tail."""
    tracks.impacts.add(inst.impact(), song.at(bar))
    tracks.noise.add(inst.downlifter(song.beats(4)), song.at(bar), 1.5)
    crash(song, tracks, song.at(bar))


def filter_dip(song, bar, beat=0.0, down_beats=2.0, hold_beats=0.0, up_beats=2.0, lowest=600.0):
    """The music (not the drums) closes to a dull, resonant low-pass and opens up again."""
    start = song.at(bar, beat)
    song.filter_move([(start, MUSIC_FILTER_OPEN), (start + song.beats(down_beats), lowest),
                      (start + song.beats(down_beats + hold_beats), lowest),
                      (start + song.beats(down_beats + hold_beats + up_beats), MUSIC_FILTER_OPEN)])


def filter_open_up(song, bar, bars=4, lowest=500.0):
    """Start a section dull (closing in one beat before it) and open the filter over `bars` bars."""
    start = song.at(bar)
    song.filter_move([(start - song.beat, MUSIC_FILTER_OPEN), (start, lowest),
                      (song.at(bar + bars), MUSIC_FILTER_OPEN)])


def tape_stop_into(song, bar, beats=2.0):
    """The mix grinds to a halt during the last beats before `bar`."""
    song.master_effect(tape_stop(song.at(bar) - song.beats(beats), song.beats(beats)))


def stutter_into(song, bar, beats=1.0, slice_beats=0.25):
    """Beat-repeat: the 16th at the start of the last beat(s) before `bar` repeats like a glitch."""
    start = song.at(bar) - song.beats(beats)
    song.master_effect(stutter(start, song.beats(slice_beats), int(beats / slice_beats)))


# ---------------------------------------------------------------------------------------------
# Harmony instruments
# ---------------------------------------------------------------------------------------------

def bass_root(chord_name):
    return midi(CHORDS[chord_name]["root"])


ROLLING_BASS = "-rro -rro -rro -rro"  # '-' = kick takes the step, r = root, o = octave up


def rolling_bass(song, tracks, bar, chord_name, gain=1.0, pattern=ROLLING_BASS):
    """Darksynth rolling 16th bass that leaves the beats to the kick (and pumps against it)."""
    root = bass_root(chord_name)
    steps = [character for character in pattern if character != " "]
    for step, character in enumerate(steps):
        if character == "-":
            continue
        note = root + (12 if character == "o" else 0)
        tracks.bass.add(inst.retro_bass(note, song.beat * 0.18, cutoff=1700), song.at(bar, step * 0.25), gain)


def octave_bass(song, tracks, bar, chord_name, gain=1.0):
    """Calmer octave bass in 8ths: low, high, low, high..."""
    root = bass_root(chord_name)
    for step in range(8):
        note = root + (12 if step % 2 else 0)
        tracks.bass.add(inst.retro_bass(note, song.beat * 0.35, cutoff=1500), song.at(bar, step * 0.5), gain)


def pads(song, tracks, first_bar, chords, track=None, attack=0.4):
    """One supersaw chord per run of equal chords."""
    track = track or tracks.pad
    index = 0
    while index < len(chords):
        chord_name = chords[index]
        span = 1
        while index + span < len(chords) and chords[index + span] == chord_name:
            span += 1
        track.add(inst.supersaw_pad(CHORDS[chord_name]["pad"], song.beats(4 * span) - 0.05, attack=attack),
                  song.at(first_bar + index))
        index += span


def motif_arp_notes(chord_name):
    """16 steps per bar: twice per bar the motif shape on this chord, accented in the motif rhythm
    (first half low, second half an octave up); the steps in between are soft chord tones.
    Returns (note, accented, side) with side -1 = left, 1 = right (ping-pong)."""
    root, third, step_above, ending = [note - 12 for note in motif_notes(chord_name)]
    fifth = root + 7
    first_half = {0: root, 2: third, 3: step_above, 4: ending}
    second_half = {8: root + 12, 10: third + 12, 11: step_above + 12, 12: ending + 12}
    fillers = [fifth, root + 12, third, fifth]
    steps = []
    for step in range(16):
        if step in first_half:
            steps.append((first_half[step], True, -1))
        elif step in second_half:
            steps.append((second_half[step], True, 1))
        else:
            steps.append((fillers[step % 4], False, 1 if step < 8 else -1))
    return steps


def arp_run(song, tracks, bar, chord_name, gain=1.0, semitones=0, brightness=6000):
    """The background synth: the motif rhythm on every chord, ping-ponging left/right."""
    for step, (note, accented, side) in enumerate(motif_arp_notes(chord_name)):
        track = tracks.arp_left if side < 0 else tracks.arp_right
        track.add(inst.synth_pluck(note + semitones, song.beat * (0.3 if accented else 0.18), brightness, 0.2),
                  song.at(bar, step * 0.25), gain * (1.0 if accented else 0.4))


def brass_stab(song, tracks, bar, chord_name, beat=0.0, beats=1.5, gain=1.0):
    tracks.brass.add(inst.poly_brass(CHORDS[chord_name]["pad"], song.beats(beats)), song.at(bar, beat), gain)


def epiano_comp(song, tracks, bar, chord_name, gain=1.0):
    """E-piano chord on the one and a push on the 'and' of 2."""
    voicing = [midi(note) + 12 for note in CHORDS[chord_name]["pad"][1:]]
    tracks.epiano.add(inst.fm_epiano(voicing, song.beats(1.3)), song.at(bar, 0), gain)
    tracks.epiano.add(inst.fm_epiano(voicing, song.beats(1.3)), song.at(bar, 2.5), gain * 0.8)


# ---------------------------------------------------------------------------------------------
# Melody voices
# ---------------------------------------------------------------------------------------------

def lead_line(song, tracks, first_bar, melody, semitones=0, gain=1.0, echo=True, harmony_chords=None,
              start_beat=0.0):
    """Synth lead with its 3/16 echo; optional harmony a third up."""
    play_melody(song, tracks.lead, inst.synth_lead, first_bar, melody, start_beat=start_beat,
                semitones=semitones, gain=gain)
    if echo:
        play_melody(song, tracks.lead_echo, inst.synth_lead, first_bar, melody, start_beat=start_beat + 0.75,
                    semitones=semitones, gain=gain)
    if harmony_chords:
        play_melody(song, tracks.harmony, inst.synth_lead, first_bar, harmony_line(melody, harmony_chords),
                    start_beat=start_beat, semitones=semitones, gain=gain)


def chip_line(song, tracks, first_bar, melody, semitones=0, gain=1.0, start_beat=0.0):
    """The 8-bit signature voice with its 3/16 echo."""
    play_melody(song, tracks.chip, inst.chip_lead, first_bar, melody, start_beat=start_beat,
                semitones=semitones, gain=gain)
    play_melody(song, tracks.chip_echo, inst.chip_lead, first_bar, melody, start_beat=start_beat + 0.75,
                semitones=semitones, gain=gain * 0.6, duty=0.25)


def guitar_line(song, tracks, first_bar, melody, semitones=0, gain=1.0, harmony_chords=None):
    play_melody(song, tracks.lead_guitar, inst.guitar_lead, first_bar, melody, semitones=semitones, gain=gain)
    if harmony_chords:
        play_melody(song, tracks.harmony_guitar, inst.guitar_lead, first_bar, harmony_line(melody, harmony_chords),
                    semitones=semitones, gain=gain)


# ---------------------------------------------------------------------------------------------
# Darksynth guitars
# ---------------------------------------------------------------------------------------------

def chugs(song, tracks, bar, chord_name, gain=1.0):
    """Palm-muted 8th-note power chords, double-tracked left/right."""
    power_chord = CHORDS[chord_name]["power"]
    for step in range(8):
        for guitar, offset in ((tracks.guitar_left, 0.0), (tracks.guitar_right, 0.007)):
            guitar.add(inst.guitar_chord(power_chord, song.beat * 0.4), song.at(bar, step * 0.5) + offset,
                       gain * (1.0 if step % 2 == 0 else 0.8))


def gallop(song, tracks, bar, chord_name, gain=1.0):
    """8th + two 16ths per beat."""
    power_chord = CHORDS[chord_name]["power"]
    for beat_number in range(4):
        for offset_beats in (0.0, 0.5, 0.75):
            for guitar, offset in ((tracks.guitar_left, 0.0), (tracks.guitar_right, 0.007)):
                guitar.add(inst.guitar_chord(power_chord, song.beat * 0.22),
                           song.at(bar, beat_number + offset_beats) + offset, gain * (1.0 if offset_beats == 0 else 0.8))


def open_chord(song, tracks, bar, beat, chord_name, beats, gain=1.0):
    power_chord = CHORDS[chord_name]["power"]
    for guitar, offset in ((tracks.guitar_left, 0.0), (tracks.guitar_right, 0.008)):
        guitar.add(inst.guitar_chord(power_chord, song.beats(beats), palm_mute=False), song.at(bar, beat) + offset, gain)
