"""Note names, chords and simple harmony helpers.

Notes are written as strings like "E5", "F#2", "Bb3" (scientific pitch, A4 = 440 Hz) or as
MIDI numbers. A rest in a melody is "r".
"""

PITCH_CLASSES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
                 "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}
REST = "r"


def midi(note):
    if isinstance(note, (int, float)):
        return note
    name, octave = note[:-1], int(note[-1])
    return 12 * (octave + 1) + PITCH_CLASSES[name]


# The game's key is F minor. Everything is written in E minor (easy note names) and shifted up by
# KEY_TRANSPOSE semitones when it is turned into a frequency.
KEY_TRANSPOSE = 1


def frequency(note):
    return 440.0 * 2 ** ((midi(note) + KEY_TRANSPOSE - 69) / 12)


def transpose(note, semitones):
    return midi(note) + semitones


# Chord name -> voicings. Add new chords here; every song section refers to these names.
CHORDS = {
    "Em": {"power": ["E2", "B2", "E3"], "pad": ["E2", "B2", "E3", "G3", "B3"], "root": "E2",
           "tones": ["E", "G", "B"], "arp": ["E4", "G4", "B4", "E5"]},
    "C": {"power": ["C3", "G3", "C4"], "pad": ["C3", "G3", "C4", "E4"], "root": "C2",
          "tones": ["C", "E", "G"], "arp": ["C4", "E4", "G4", "C5"]},
    "D": {"power": ["D3", "A3", "D4"], "pad": ["D3", "A3", "D4", "F#4"], "root": "D2",
          "tones": ["D", "F#", "A"], "arp": ["D4", "F#4", "A4", "D5"]},
    "Bm": {"power": ["B2", "F#3", "B3"], "pad": ["B2", "F#3", "B3", "D4"], "root": "B1",
           "tones": ["B", "D", "F#"], "arp": ["B3", "D4", "F#4", "B4"]},
    "B7": {"power": ["B2", "F#3", "B3"], "pad": ["B2", "D#3", "F#3", "A3"], "root": "B1",
           "tones": ["B", "D#", "F#", "A"], "arp": ["B3", "D#4", "F#4", "A4"]},
    "E": {"power": ["E2", "B2", "E3"], "pad": ["E3", "B3", "E4", "G#4"], "root": "E2",
          "tones": ["E", "G#", "B"], "arp": ["E4", "G#4", "B4", "E5"]},
    "F": {"power": ["F2", "C3", "F3"], "pad": ["F3", "A3", "C4", "E4"], "root": "F1",
          "tones": ["F", "A", "C"], "arp": ["F4", "A4", "C5", "F5"]},  # bII: the dark Phrygian colour
    "Am": {"power": ["A2", "E3", "A3"], "pad": ["A2", "E3", "A3", "C4"], "root": "A1",
           "tones": ["A", "C", "E"], "arp": ["A3", "C4", "E4", "A4"]},
    "G": {"power": ["G2", "D3", "G3"], "pad": ["G2", "D3", "G3", "B3"], "root": "G1",
          "tones": ["G", "B", "D"], "arp": ["G3", "B3", "D4", "G4"]},
    "D7": {"power": ["D3", "A3", "D4"], "pad": ["D3", "A3", "C4", "F#4"], "root": "D2",
           "tones": ["D", "F#", "A", "C"], "arp": ["D4", "F#4", "A4", "C5"]},
}

E_MINOR_SCALE = [4, 6, 7, 9, 11, 0, 2]


def third_above(note, chord_name=None, scale=E_MINOR_SCALE):
    """Harmony note a diatonic third above `note`.

    Over a chord whose tones fall outside the scale (like B7 with D#) the next chord tone at
    least a minor third higher is used instead, so the harmony never clashes with the chord.
    """
    pitch = midi(note)
    pitch_class = pitch % 12
    chord_classes = [PITCH_CLASSES[tone] for tone in CHORDS[chord_name]["tones"]] if chord_name else []
    if chord_classes and any(tone not in scale for tone in chord_classes):
        for interval in range(3, 13):
            if (pitch_class + interval) % 12 in chord_classes:
                return pitch + interval
    if pitch_class in scale:
        target = scale[(scale.index(pitch_class) + 2) % 7]
        return pitch + (target - pitch_class) % 12
    return pitch + 3
