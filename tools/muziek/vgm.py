"""Reads a VGM file (the register log of the Sega Mega Drive sound chips) and writes it out as a
composition file (tools/muziek/composities/<naam>.py, docs/MUZIEK.md "Een VGM als compositie").

    tools/muziek/render.sh --vgm <bestand.vgm|.vgz> [naam]     write composities/<naam>.py
    tools/muziek/render.sh --vgm <bestand> [naam] --toon       only show what the file holds
    tools/muziek/render.sh --vgm <bestand> [naam] --vergelijk  compare composities/<naam>.py with it
    tools/muziek/render.sh --vgm <bestand> [naam] --meet       measure the chip imitation (chip.py) and the intro
    ... --overschrijf       replace an existing composities/<naam>.py
    ... --tempo 92          the tempo (BPM) when the file name or the notes do not give it

What is read (pure Python, also gzipped files):
- YM2612 FM: per channel the key-on/off (register 0x28) with the frequency of that moment
  (F-number and block, 0xA0-0xA6) as a MIDI pitch, its start and its length; the patch of the
  channel (algorithm, feedback, the four operators), from which the sound is chosen;
- SN76489 PSG: the three tone channels (period -> pitch, volume -> on/off and velocity) and the
  noise channel as drums (loud white noise a snare, soft a hi-hat, long an open hat or a crash);
- the DAC (channel 6, registers 0x2A/0x2B, data blocks): every burst of samples a drum, named
  by what the sample looks like (a low thump a kick, a tone a tom, noise a snare).

From the timing of the notes (44100 samples a second) come the grid, the tempo (checked
against a number in the file name: "_92" may be the BPM) and the bar length; from the notes the
key, the chords of every bar, the parts (bas, lead, arp, pad, brass, drums) and the sections
(intro, thema, opbouw, refrein, breakdown, finale).
"""
import argparse
import gzip
import math
import os
import re
import shutil
import struct
import sys
import textwrap
from collections import Counter
from dataclasses import dataclass, field

HERE = os.path.dirname(os.path.abspath(__file__))
COMPOSITIONS_FOLDER = os.path.join(HERE, "composities")
VGM_RATE = 44100
DEFAULT_YM2612_CLOCK = 7670453
DEFAULT_PSG_CLOCK = 3579545
HIGHEST_F_NUMBER = 2047
## Operator slots in register order (0x30, 0x34, 0x38, 0x3C) are operators 1, 3, 2, 4.
SLOT_OPERATORS = (0, 2, 1, 3)
## The operators that sound (the carriers) in each of the 8 algorithms.
CARRIERS = ((3,), (3,), (3,), (3,), (1, 3), (1, 2, 3), (1, 2, 3), (0, 1, 2, 3))
NOTE_NAMES_SHARP = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
NOTE_NAMES_FLAT = ("C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B")


# ----------------------------------------------------------------------------- what a VGM holds

@dataclass(frozen=True)
class FmVoice:
    """The patch of an FM channel as the registers hold it (operators 1-4 in order)."""
    algorithm: int
    feedback: int
    multiples: tuple
    total_levels: tuple
    attack_rates: tuple
    decay_rates: tuple
    sustain_levels: tuple
    detunes: tuple = (0, 0, 0, 0)
    rate_scalings: tuple = (0, 0, 0, 0)
    sustain_rates: tuple = (0, 0, 0, 0)
    release_rates: tuple = (15, 15, 15, 15)

    def carriers(self) -> tuple:
        return CARRIERS[self.algorithm]

    def modulators(self) -> tuple:
        return tuple(operator for operator in range(4) if operator not in self.carriers())

    def describe(self) -> str:
        return (f"algoritme {self.algorithm}, feedback {self.feedback}, MUL {'/'.join(map(str, self.multiples))}, "
                f"TL {'/'.join(map(str, self.total_levels))}, AR {'/'.join(map(str, self.attack_rates))}")


@dataclass
class RawNote:
    """One note as the chip played it: times in samples (44100 a second), a MIDI pitch (not
    rounded), a level in dB (0 the loudest the chip can)."""
    channel: str                  # "fm1".."fm6", "psg1".."psg3"
    start: int
    end: int
    pitch: float
    level_db: float = 0.0
    saturated: bool = False       # the F-number at its maximum: the writer probably clipped the pitch
    voice: FmVoice = None


@dataclass
class RawHit:
    """One drum hit: the noise channel of the PSG or a sample through the DAC."""
    source: str                   # "psg_ruis", "dac"
    start: int
    end: int
    drum: str = ""                # a drum name of notation.DRUM_NAMES
    level_db: float = 0.0
    white: bool = True            # PSG: white noise (else periodic)


@dataclass
class VgmSong:
    path: str
    version: int
    total_samples: int
    loop_sample: int              # where the loop starts (-1: none)
    title: str
    chips: list
    notes: list = field(default_factory=list)
    hits: list = field(default_factory=list)
    key_ons: Counter = field(default_factory=Counter)      # channel -> key-on writes (FM) / onsets (PSG)
    voices: dict = field(default_factory=dict)             # FM channel -> its most used FmVoice
    patches: dict = field(default_factory=dict)            # every FM channel a patch was written to -> FmVoice
    fm_clock: int = DEFAULT_YM2612_CLOCK
    psg_clock: int = DEFAULT_PSG_CLOCK
    # the register log itself, for chip.py: (sample, port, register, value), (sample, byte),
    # (sample, DAC value) and (sample, DAC samples, their rate)
    fm_writes: list = field(default_factory=list)
    psg_writes: list = field(default_factory=list)
    dac_writes: list = field(default_factory=list)
    dac_streams: list = field(default_factory=list)
    warnings: list = field(default_factory=list)

    @property
    def seconds(self) -> float:
        return self.total_samples / VGM_RATE

    def channels(self) -> list:
        return sorted({note.channel for note in self.notes})


def midi_from_hz(hz: float) -> float:
    return 69.0 + 12.0 * math.log2(hz / 440.0)


def fm_hz(f_number: int, block: int, clock: int) -> float:
    return f_number * (clock / 144.0) / 2 ** (21 - block)


def psg_hz(period: int, clock: int) -> float:
    return clock / (32.0 * (period or 1024))


class _FmChannel:
    def __init__(self) -> None:
        self.high_latch = 0           # the last 0xA4 write: used by the next 0xA0 write
        self.f_number = 0
        self.block = 0
        self.key_mask = 0
        self.key_on_event = False
        self.frequency_changed = False
        self.algorithm = 0
        self.feedback = 0
        self.operators = [{"mul": 1, "tl": 0, "ar": 31, "dr": 0, "sl": 0, "dt": 0, "rs": 0, "sr": 0, "rr": 15}
                          for _operator in range(4)]
        self.patched = False
        self.open_note = None

    def voice(self) -> FmVoice:
        return FmVoice(self.algorithm, self.feedback,
                       tuple(operator["mul"] for operator in self.operators),
                       tuple(operator["tl"] for operator in self.operators),
                       tuple(operator["ar"] for operator in self.operators),
                       tuple(operator["dr"] for operator in self.operators),
                       tuple(operator["sl"] for operator in self.operators),
                       tuple(operator["dt"] for operator in self.operators),
                       tuple(operator["rs"] for operator in self.operators),
                       tuple(operator["sr"] for operator in self.operators),
                       tuple(operator["rr"] for operator in self.operators))


class _PsgTone:
    def __init__(self) -> None:
        self.period = 0
        self.attenuation = 15
        self.open_note = None
        self.quietest = 0             # the highest attenuation the open note has reached


class _Reader:
    """Plays the command stream into notes and hits. Writes at the same sample count as one
    moment: the channels they touch are looked at when the time moves on (flush)."""

    def __init__(self, data: bytes, path: str) -> None:
        self.data = data
        self.version = self._u32(0x08)
        psg_clock = self._u32(0x0C) & 0x3FFFFFFF
        fm_clock = (self._u32(0x2C) & 0x3FFFFFFF) if self.version >= 0x110 else 0
        self.psg_clock = psg_clock or DEFAULT_PSG_CLOCK
        self.fm_clock = fm_clock or DEFAULT_YM2612_CLOCK
        chips = ([f"YM2612 ({fm_clock} Hz)"] if fm_clock else []) + ([f"SN76489 ({psg_clock} Hz)"] if psg_clock else [])
        loop_offset = self._u32(0x1C)
        self.loop_position = 0x1C + loop_offset if loop_offset else -1
        self.song = VgmSong(path, self.version, self._u32(0x18), -1, self._gd3_title(), chips,
                            fm_clock=self.fm_clock, psg_clock=self.psg_clock)
        self.time = 0
        self.fm = [_FmChannel() for _channel in range(6)]
        self.fm_dirty = set()
        self.tones = [_PsgTone() for _channel in range(3)]
        self.tones_dirty = set()
        self.psg_latch = (0, 0)       # (channel, 1 volume / 0 tone)
        self.noise_control = 0
        self.noise_attenuation = 15
        self.noise_before = 15        # the attenuation when this moment began
        self.noise_control_written = False
        self.noise_volume_written = False
        self.open_hit = None
        self.dac_enabled = False
        self.dac_writes = []          # (time, value)
        self.data_bank = b""          # the YM2612 PCM data blocks, joined
        self.data_blocks = []         # (offset in the bank, size)
        self.bank_position = 0
        self.stream_rate = 8000
        self.stream_hits = []         # (time, samples, rate)
        self.unknown_commands = Counter()
        self.special_mode = False

    def _u32(self, offset: int) -> int:
        return struct.unpack_from("<I", self.data, offset)[0] if offset + 4 <= len(self.data) else 0

    def _gd3_title(self) -> str:
        offset = self._u32(0x14)
        if not offset:
            return ""
        start = 0x14 + offset
        if self.data[start:start + 4] != b"Gd3 ":
            return ""
        text = self.data[start + 12:start + 12 + self._u32(start + 8)].decode("utf-16-le", "replace")
        return text.split("\0")[0].strip()

    # ------------------------------------------------------------------ the command stream

    def play(self) -> VgmSong:
        data = self.data
        position = 0x34 + self._u32(0x34) if self.version >= 0x150 and self._u32(0x34) else 0x40
        while position < len(data):
            if position == self.loop_position:
                self.song.loop_sample = self.time
            command = data[position]
            if command == 0x66:
                break
            if command == 0x52 or command == 0x53:
                self._fm_write(command - 0x52, data[position + 1], data[position + 2])
                position += 3
            elif command == 0x50:
                self._psg_write(data[position + 1])
                position += 2
            elif command == 0x61:
                self._wait(struct.unpack_from("<H", data, position + 1)[0])
                position += 3
            elif command == 0x62:
                self._wait(735)
                position += 1
            elif command == 0x63:
                self._wait(882)
                position += 1
            elif 0x70 <= command <= 0x7F:
                self._wait((command & 0x0F) + 1)
                position += 1
            elif 0x80 <= command <= 0x8F:
                if self.bank_position < len(self.data_bank):
                    self._dac_write(self.data_bank[self.bank_position])
                self.bank_position += 1
                self._wait(command & 0x0F)
                position += 1
            elif command == 0x67:
                block_type = data[position + 2]
                size = self._u32(position + 3) & 0x7FFFFFFF
                if block_type == 0x00:
                    self.data_blocks.append((len(self.data_bank), size))
                    self.data_bank += data[position + 7:position + 7 + size]
                position += 7 + size
            elif command == 0xE0:
                self.bank_position = self._u32(position + 1)
                position += 5
            elif command == 0x92:
                self.stream_rate = self._u32(position + 2) or self.stream_rate
                position += 6
            elif command == 0x93:
                start = self._u32(position + 2)
                length = self._u32(position + 7)
                self.stream_hits.append((self.time, self.data_bank[start:start + length], self.stream_rate))
                position += 11
            elif command == 0x95:
                block = struct.unpack_from("<H", data, position + 2)[0]
                if block < len(self.data_blocks):
                    start, size = self.data_blocks[block]
                    self.stream_hits.append((self.time, self.data_bank[start:start + size], self.stream_rate))
                position += 5
            else:
                self.unknown_commands[command] += 1
                position += 1 + self._operand_bytes(command)
        self._flush()
        self._finish()
        return self.song

    def _operand_bytes(self, command: int) -> int:
        if command in (0x90, 0x91):
            return 4
        if command == 0x94:
            return 1
        if command == 0x68:
            return 11
        if 0x30 <= command <= 0x3F or command == 0x4F:
            return 1
        if 0x40 <= command <= 0x4E:
            return 2 if self.version >= 0x160 else 1
        if 0x51 <= command <= 0x5F or 0xA0 <= command <= 0xBF:
            return 2
        if 0xC0 <= command <= 0xDF:
            return 3
        if 0xE1 <= command <= 0xFF:
            return 4
        return 0

    def _wait(self, samples: int) -> None:
        if samples > 0:
            self._flush()
            self.time += samples

    # ------------------------------------------------------------------ YM2612

    def _fm_write(self, port: int, register: int, value: int) -> None:
        if not (port == 0 and register == 0x2A):
            self.song.fm_writes.append((self.time, port, register, value))
        if port == 0 and register == 0x28:
            index = {0: 0, 1: 1, 2: 2, 4: 3, 5: 4, 6: 5}.get(value & 0x07)
            if index is None:
                return
            channel = self.fm[index]
            mask = value >> 4
            if mask and not channel.key_mask:
                channel.key_on_event = True
                self.song.key_ons[f"fm{index + 1}"] += 1
            channel.key_mask = mask
            self.fm_dirty.add(index)
        elif port == 0 and register == 0x2A:
            if self.dac_enabled:
                self._dac_write(value)
        elif port == 0 and register == 0x2B:
            self.dac_enabled = bool(value & 0x80)
        elif port == 0 and register == 0x27:
            self.special_mode = self.special_mode or bool(value & 0xC0)
        elif 0x30 <= register <= 0x8F and register & 0x03 != 3:
            channel = self.fm[port * 3 + (register & 0x03)]
            operator = channel.operators[SLOT_OPERATORS[(register >> 2) & 0x03]]
            group = register & 0xF0
            channel.patched = True
            if group == 0x30:
                operator["mul"] = value & 0x0F
                operator["dt"] = (value >> 4) & 0x07
            elif group == 0x40:
                operator["tl"] = value & 0x7F
            elif group == 0x50:
                operator["ar"] = value & 0x1F
                operator["rs"] = value >> 6
            elif group == 0x60:
                operator["dr"] = value & 0x1F
            elif group == 0x70:
                operator["sr"] = value & 0x1F
            elif group == 0x80:
                operator["sl"] = value >> 4
                operator["rr"] = value & 0x0F
        elif 0xA4 <= register <= 0xA6:
            self.fm[port * 3 + register - 0xA4].high_latch = value
        elif 0xA0 <= register <= 0xA2:
            index = port * 3 + register - 0xA0
            channel = self.fm[index]
            channel.f_number = ((channel.high_latch & 0x07) << 8) | value
            channel.block = (channel.high_latch >> 3) & 0x07
            channel.frequency_changed = True
            self.fm_dirty.add(index)
        elif 0xB0 <= register <= 0xB2:
            channel = self.fm[port * 3 + register - 0xB0]
            channel.algorithm = value & 0x07
            channel.feedback = (value >> 3) & 0x07

    def _flush_fm(self, index: int) -> None:
        channel = self.fm[index]
        name = f"fm{index + 1}"
        if channel.key_on_event and channel.key_mask:
            self._close(channel)
            self._open_fm(channel, name, index)
        elif not channel.key_mask:
            self._close(channel)
        elif channel.open_note and channel.frequency_changed and channel.f_number:
            # the pitch moves under a held key: a new note when it lands on another semitone
            pitch = midi_from_hz(fm_hz(channel.f_number, channel.block, self.fm_clock))
            if round(pitch) != round(channel.open_note.pitch):
                self._close(channel)
                self._open_fm(channel, name, index)
        channel.key_on_event = False
        channel.frequency_changed = False

    def _open_fm(self, channel: _FmChannel, name: str, index: int) -> None:
        if not channel.f_number or (index == 5 and self.dac_enabled):
            return
        voice = channel.voice()
        carrier_levels = [voice.total_levels[operator] for operator in voice.carriers()]
        channel.open_note = RawNote(name, self.time, self.time,
                                    midi_from_hz(fm_hz(channel.f_number, channel.block, self.fm_clock)),
                                    -0.75 * sum(carrier_levels) / len(carrier_levels),
                                    channel.f_number >= HIGHEST_F_NUMBER, voice)

    def _close(self, holder) -> None:
        note = holder.open_note
        if note is not None:
            note.end = self.time
            if note.end > note.start:
                self.song.notes.append(note)
            holder.open_note = None

    # ------------------------------------------------------------------ SN76489

    def _psg_write(self, value: int) -> None:
        self.song.psg_writes.append((self.time, value))
        if value & 0x80:
            self.psg_latch = ((value >> 5) & 0x03, (value >> 4) & 0x01)
            data = value & 0x0F
            first_byte = True
        else:
            data = value & 0x3F
            first_byte = False
        channel, is_volume = self.psg_latch
        if is_volume:
            if channel == 3:
                self.noise_attenuation = data & 0x0F
                self.noise_volume_written = True
            else:
                self.tones[channel].attenuation = data & 0x0F
                self.tones_dirty.add(channel)
        elif channel == 3:
            self.noise_control = data & 0x07
            self.noise_control_written = True
        else:
            tone = self.tones[channel]
            tone.period = (tone.period & 0x3F0) | data if first_byte else (tone.period & 0x00F) | (data << 4)
            self.tones_dirty.add(channel)

    def _flush_tone(self, index: int) -> None:
        tone = self.tones[index]
        name = f"psg{index + 1}"
        # periods under 6 are above hearing: the trick for playing samples, not a note
        audible = tone.attenuation < 15 and tone.period >= 6
        if not audible:
            self._close(tone)
            return
        pitch = midi_from_hz(psg_hz(tone.period, self.psg_clock))
        note = tone.open_note
        if note is not None:
            struck_again = tone.attenuation <= tone.quietest - 2
            if round(pitch) == round(note.pitch) and not struck_again:
                tone.quietest = max(tone.quietest, tone.attenuation)
                return
            self._close(tone)
        tone.open_note = RawNote(name, self.time, self.time, pitch, -2.0 * tone.attenuation)
        tone.quietest = tone.attenuation
        self.song.key_ons[name] += 1

    def _flush_noise(self) -> None:
        audible = self.noise_attenuation < 15
        struck = self.noise_control_written or (
            self.noise_volume_written and (self.noise_before == 15 or self.noise_attenuation <= self.noise_before - 2))
        if self.open_hit is not None and (not audible or struck):
            self.open_hit.end = self.time
            self.song.hits.append(self.open_hit)
            self.open_hit = None
        if audible and struck:
            self.open_hit = RawHit("psg_ruis", self.time, self.time, "", -2.0 * self.noise_attenuation,
                                   bool(self.noise_control & 0x04))
            self.song.key_ons["psg_ruis"] += 1
        self.noise_before = self.noise_attenuation
        self.noise_control_written = False
        self.noise_volume_written = False

    # ------------------------------------------------------------------ the DAC

    def _dac_write(self, value: int) -> None:
        self.dac_writes.append((self.time, value))

    def _flush(self) -> None:
        for index in sorted(self.fm_dirty):
            self._flush_fm(index)
        self.fm_dirty.clear()
        for index in sorted(self.tones_dirty):
            self._flush_tone(index)
        self.tones_dirty.clear()
        if self.noise_control_written or self.noise_volume_written:
            self._flush_noise()

    def _finish(self) -> None:
        song = self.song
        self.time = max(self.time, 1)
        song.total_samples = song.total_samples or self.time
        for holder in self.fm + self.tones:
            self._close(holder)
        if self.open_hit is not None:
            self.open_hit.end = self.time
            song.hits.append(self.open_hit)
        _name_noise_hits([hit for hit in song.hits if hit.source == "psg_ruis"])
        song.hits += _dac_hits(self.dac_writes) + [
            RawHit("dac", time, time + int(len(samples) / rate * VGM_RATE), classify_sample(samples, len(samples) / rate))
            for time, samples, rate in self.stream_hits if len(samples) >= DAC_SHORTEST_BURST]
        song.key_ons["dac"] = sum(1 for hit in song.hits if hit.source == "dac")
        song.dac_writes = self.dac_writes
        song.dac_streams = self.stream_hits
        for index, channel in enumerate(self.fm):
            if channel.patched:
                song.patches[f"fm{index + 1}"] = channel.voice()
        song.notes.sort(key=lambda note: (note.start, note.channel))
        song.hits.sort(key=lambda hit: hit.start)
        for index, channel in enumerate(self.fm):
            used = Counter(note.voice for note in song.notes if note.channel == f"fm{index + 1}")
            if used:
                song.voices[f"fm{index + 1}"] = used.most_common(1)[0][0]
                song.patches[f"fm{index + 1}"] = song.voices[f"fm{index + 1}"]
        saturated = Counter(note.channel for note in song.notes if note.saturated)
        for channel, count in sorted(saturated.items()):
            total = sum(1 for note in song.notes if note.channel == channel)
            song.warnings.append(
                f"{channel}: {count} van de {total} noten hebben het hoogste F-number ({HIGHEST_F_NUMBER}); de "
                "schrijver van het VGM heeft de toonhoogte daar waarschijnlijk afgekapt (de noot is overgenomen "
                "zoals de chip hem speelt; hij telt niet mee voor de toonsoort en licht voor de akkoorden)")
        if self.special_mode:
            song.warnings.append("kanaal 3 staat in de speciale modus (een frequentie per operator): alleen de "
                                 "hoofdfrequentie is gelezen")
        if self.unknown_commands:
            listed = ", ".join(f"0x{command:02X} ({count}x)" for command, count in sorted(self.unknown_commands.items()))
            song.warnings.append(f"overgeslagen commando's (andere chips of besturing): {listed}")


## A burst of DAC writes is a drum when it has at least this many samples; a silence of this
## many VGM samples (20 ms) ends it.
DAC_SHORTEST_BURST = 8
DAC_GAP = 882


def _dac_hits(writes: list) -> list:
    hits = []
    burst = []
    for write in writes + [(None, 0)]:
        if burst and (write[0] is None or write[0] - burst[-1][0] > DAC_GAP):
            if len(burst) >= DAC_SHORTEST_BURST:
                start, end = burst[0][0], burst[-1][0]
                values = bytes(value for _time, value in burst)
                hits.append(RawHit("dac", start, max(end, start + 1), classify_sample(values, (end - start) / VGM_RATE)))
            burst = []
        if write[0] is not None:
            burst.append(write)
    return hits


def classify_sample(values: bytes, seconds: float) -> str:
    """The drum an 8-bit sample looks like, from how often it crosses its middle: a low thump
    is a kick, a steady tone a tom, noise a snare (short and very bright: a hi-hat; long: a crash)."""
    if len(values) < 2 or seconds <= 0:
        return "snare"
    middle = sum(values) / len(values)
    crossings = []
    side = 0
    for index, value in enumerate(values):
        if abs(value - middle) < 3:
            continue
        new_side = 1 if value > middle else -1
        if side and new_side != side:
            crossings.append(index)
        side = new_side
    frequency = len(crossings) / seconds / 2.0
    gaps = [later - earlier for earlier, later in zip(crossings, crossings[1:])]
    steady = False
    if len(gaps) >= 3:
        mean_gap = sum(gaps) / len(gaps)
        spread = (sum((gap - mean_gap) ** 2 for gap in gaps) / len(gaps)) ** 0.5
        steady = spread < 0.6 * mean_gap
    if frequency < 160.0:
        return "kick"
    if steady and frequency < 450.0:
        return "tom_laag" if frequency < 220.0 else ("tom_mid" if frequency < 320.0 else "tom_hoog")
    if seconds > 0.6:
        return "crash"
    if seconds < 0.05 and frequency > 3000.0:
        return "hihat"
    return "snare"


def _name_noise_hits(hits: list) -> None:
    """Names the hits of the PSG noise channel: periodic noise a low tom; white noise by its
    length (a crash, an open hi-hat) and its level: where the file has loud and soft hits
    (4 dB or more apart) the loud ones are snares, the others hi-hats."""
    short_levels = sorted({hit.level_db for hit in hits if hit.white and hit.end - hit.start < 0.2 * VGM_RATE},
                          reverse=True)
    snare_from = None
    widest_gap = 0.0
    for louder, softer in zip(short_levels, short_levels[1:]):
        if louder - softer >= 4.0 and louder - softer > widest_gap:
            widest_gap = louder - softer
            snare_from = louder
    for hit in hits:
        seconds = (hit.end - hit.start) / VGM_RATE
        if not hit.white:
            hit.drum = "tom_laag"
        elif seconds >= 0.6:
            hit.drum = "crash"
        elif seconds >= 0.2:
            hit.drum = "open"
        else:
            hit.drum = "snare" if snare_from is not None and hit.level_db >= snare_from else "hihat"


def read(path: str) -> VgmSong:
    with open(path, "rb") as vgm_file:
        data = vgm_file.read()
    if data[:2] == b"\x1f\x8b":
        data = gzip.decompress(data)
    if data[:4] != b"Vgm ":
        raise ValueError(f"{path}: geen VGM-bestand (begint niet met 'Vgm ')")
    return _Reader(data, path).play()


# ----------------------------------------------------------------------------- tempo and grid

@dataclass
class Timing:
    origin: int                   # the sample the first bar starts on (the first note)
    step_samples: float           # one step of the grid
    steps_per_beat: int
    beats_per_bar: int
    tempo: float                  # BPM
    fit: float                    # how far the notes are from the grid on average (in steps)
    name_tempo: float = None      # the number in the file name, if any
    name_tempo_fits: bool = False

    @property
    def steps_per_bar(self) -> int:
        return self.steps_per_beat * self.beats_per_bar

    @property
    def step_beats(self) -> float:
        return 1.0 / self.steps_per_beat

    def step_of(self, sample: int) -> int:
        return int(round((sample - self.origin) / self.step_samples))


def tempo_in_name(path: str):
    """A number at the end of the file name that could be a tempo ("nitro_overdrive_92")."""
    match = re.search(r"[_\- ](\d{2,3})(?:bpm)?$", os.path.splitext(os.path.basename(path))[0].lower())
    if match and 40 <= int(match.group(1)) <= 300:
        return float(match.group(1))
    return None


def _grid_step(onsets: list) -> tuple:
    """(step in samples, mean distance to the grid in steps): the smallest gap between notes
    that comes back often, then fitted to all of them."""
    gaps = sorted(later - earlier for earlier, later in zip(onsets, onsets[1:]) if later - earlier > 400)
    if not gaps:
        return 60.0 * VGM_RATE / 120.0 / 4.0, 0.0
    wanted = max(3, int(0.08 * len(gaps)))
    step = float(gaps[len(gaps) // 2])
    index = 0
    while index < len(gaps):
        alike = [gap for gap in gaps[index:] if gap <= gaps[index] * 1.04]
        if len(alike) >= wanted:
            step = float(alike[len(alike) // 2])
            break
        index += len(alike)
    origin = onsets[0]
    fit = 0.0
    for _round in range(3):
        counts = [round((onset - origin) / step) for onset in onsets]
        squares = sum(count * count for count in counts)
        if squares:
            step = sum(count * (onset - origin) for count, onset in zip(counts, onsets)) / squares
        fit = sum(abs((onset - origin) / step - round((onset - origin) / step)) for onset in onsets) / len(onsets)
    return step, fit


def _repeat_score(events: dict, lag: int, last_step: int) -> float:
    """How much of what happens comes back `lag` steps later (0..1)."""
    same = 0
    total = 0
    for step, happening in events.items():
        if step + lag > last_step:
            continue
        total += len(happening)
        same += len(happening & events.get(step + lag, frozenset()))
    return same / total if total else 0.0


def find_timing(song: VgmSong, tempo: float = None) -> Timing:
    onsets = sorted({note.start for note in song.notes} | {hit.start for hit in song.hits})
    if not onsets:
        raise ValueError(f"{song.path}: geen noten of slagen gevonden")
    step_samples, fit = _grid_step(onsets)
    name_tempo = tempo_in_name(song.path)
    candidates = {steps: 60.0 * VGM_RATE / (step_samples * steps) for steps in (4, 2, 8, 3, 6, 1)}
    steps_per_beat = None
    name_fits = False
    for wanted in (tempo, name_tempo):
        if wanted and steps_per_beat is None:
            for steps, candidate in candidates.items():
                if abs(candidate - wanted) <= 0.015 * wanted:
                    steps_per_beat = steps
                    name_fits = wanted == name_tempo
                    break
    if steps_per_beat is None and tempo:
        # a tempo given by hand that the notes do not show: the grid in sixteenths of that tempo
        steps_per_beat = 4
        step_samples = 60.0 * VGM_RATE / tempo / 4.0
        candidates[4] = tempo
        fit = sum(abs((onset - onsets[0]) / step_samples - round((onset - onsets[0]) / step_samples))
                  for onset in onsets) / len(onsets)
    if steps_per_beat is None:
        steps_per_beat = next((steps for steps, candidate in candidates.items() if 80.0 <= candidate < 180.0), 4)
    found = candidates[steps_per_beat]
    # notes only on the beats or the eighths: the grid still in sixteenths (for the note lengths)
    while steps_per_beat in (1, 2):
        steps_per_beat *= 2
        step_samples /= 2.0
        fit *= 2.0
    if abs(found - round(found)) <= 0.003 * found:
        found = float(round(found))
    timing = Timing(onsets[0], step_samples, steps_per_beat, 4, round(found, 2), fit, name_tempo, name_fits)
    # the bar: three or four beats, whichever makes the music repeat best
    events = {}
    for note in song.notes:
        events.setdefault(timing.step_of(note.start), set()).add((note.channel, round(note.pitch)))
    for hit in song.hits:
        events.setdefault(timing.step_of(hit.start), set()).add(hit.drum)
    events = {step: frozenset(happening) for step, happening in events.items()}
    last_step = max(events)
    scores = {beats: max(_repeat_score(events, beats * steps_per_beat * bars, last_step) for bars in (1, 2, 4))
              for beats in (3, 4)}
    timing.beats_per_bar = 3 if scores[3] > scores[4] * 1.15 + 0.02 else 4
    return timing


# ----------------------------------------------------------------------------- parts

@dataclass(frozen=True)
class StepNote:
    """A note on the grid: steps from the start of the piece."""
    step: int
    pitches: tuple
    steps: int
    velocity: float = 1.0
    saturated: bool = False


@dataclass(frozen=True)
class StepHit:
    step: int
    drum: str
    velocity: float = 1.0


def _velocity(level_db: float, loudest_db: float) -> float:
    return max(0.3, min(1.0, round(10 ** ((level_db - loudest_db) / 20.0) * 20.0) / 20.0))


def _on_grid(notes: list, timing: Timing) -> list:
    """One channel's notes on the grid; two on the same step: the longest stays."""
    if not notes:
        return []
    loudest = max(note.level_db for note in notes)
    by_step = {}
    for note in notes:
        step = timing.step_of(note.start)
        steps = max(1, timing.step_of(note.end) - step)
        placed = StepNote(step, (int(round(note.pitch)),), steps, _velocity(note.level_db, loudest), note.saturated)
        if step not in by_step or by_step[step].steps < steps:
            by_step[step] = placed
    return [by_step[step] for step in sorted(by_step)]


def _median(values: list) -> float:
    ordered = sorted(values)
    return ordered[len(ordered) // 2] if ordered else 0.0


def _chords_of(channels: list) -> list:
    """Several channels struck together as one part of chords."""
    by_step = {}
    for notes in channels:
        for note in notes:
            by_step.setdefault(note.step, []).append(note)
    return [StepNote(step, tuple(sorted({pitch for note in together for pitch in note.pitches})),
                     max(note.steps for note in together), max(note.velocity for note in together),
                     all(note.saturated for note in together))
            for step, together in sorted(by_step.items())]


@dataclass
class Arrangement:
    """The VGM as parts on the grid: what the composition file is written from."""
    song: VgmSong
    timing: Timing
    parts: dict                   # part -> [StepNote]
    hits: list                    # [StepHit]
    part_channels: dict           # part -> [channel]
    sounds: dict                  # part -> sound name
    sound_reasons: dict           # part -> why that sound
    key: tuple = ("C", "majeur")
    bar_count: int = 0
    chords: dict = field(default_factory=dict)       # bar number -> "E7" or "C D"
    sections: list = field(default_factory=list)     # [{"naam", "soort", "maten"}]
    moments: dict = field(default_factory=dict)
    octaves: dict = field(default_factory=dict)      # part -> octaves it is moved (BIJSTELLING)
    notes: list = field(default_factory=list)        # remarks for the report and the file's docstring

    def bar_of(self, step: int) -> int:
        return step // self.timing.steps_per_bar + 1

    def bar_notes(self, part: str, bar: int) -> list:
        return [note for note in self.parts.get(part, []) if self.bar_of(note.step) == bar]

    def bar_hits(self, bar: int) -> list:
        return [hit for hit in self.hits if self.bar_of(hit.step) == bar]


def choose_sound(part: str, channel: str, voice: FmVoice, mean_beats: float) -> tuple:
    """(sound of instruments.SOUNDS, the reason) for a part, from the patch of its FM channel:
    the feedback (how raw), how hard the modulators are driven (how bright), the attack of the
    carriers (how slow) and the multiples of the modulators (how metallic)."""
    role = part.rstrip("0123456789")
    if voice is None:
        sound = {"lead": "psg_lead_fel", "arp": "psg_arp", "bas": "psg_lead", "pad": "psg_lead"}.get(role, "psg_arp")
        return sound, f"{channel}: PSG-blokgolf"
    modulators = voice.modulators()
    drive = sum(127 - voice.total_levels[operator] for operator in modulators) / (127.0 * len(modulators)) if modulators else 0.0
    slowest_attack = min(voice.attack_rates[operator] for operator in voice.carriers())
    metallic = any(voice.multiples[operator] >= 5 for operator in modulators)
    dies_away = all(voice.sustain_levels[operator] >= 12 for operator in voice.carriers())
    why = f"{channel}: {voice.describe()}"
    if role == "bas":
        if voice.feedback >= 5 or (drive > 0.75 and voice.feedback >= 3):
            return "fm_housebas", why + ": hoge feedback, hard gestuurde modulatoren (een rauwe bas)"
        if voice.feedback <= 1 and drive < 0.6:
            return "fm_subbas", why + ": weinig feedback en modulatie (een ronde bas)"
        return "fm_slapbas", why + ": een gewone FM-bas"
    if role in ("pad", "brass"):
        if metallic and mean_beats < 1.0:
            return "fm_stoot_metaal", why + ": hoge modulatorverhoudingen, korte noten (metalige stoten)"
        if slowest_attack <= 18:
            return ("fm_strijkers" if voice.feedback <= 3 else "synthwave_pad"), why + ": trage aanzet (een pad)"
        return ("synthwave_pad" if mean_beats >= 1.0 else "synth_brass"), why + ": akkoorden, snelle aanzet"
    if role == "arp":
        if dies_away:
            return ("fm_klok" if metallic else "fm_piano"), why + ": sterft uit (aangeslagen klank)"
        return "psg_arp", why + ": doorlopend figuur (op de PSG-blokgolf)"
    if voice.feedback >= 6:
        return "fm_lead_zuur", why + ": feedback bijna op zijn hoogst (een rauwe lead)"
    if voice.feedback >= 4:
        return "fm_lead_snerpend", why + ": hoge feedback (een snerpende lead)"
    return "fm_lead_helder", why + ": een heldere FM-lead"


## The sounds of instruments.SOUNDS by what they are used as: a composition read from a VGM
## replaces each by the VGM's own voice of that kind (AFGELEIDE_KLANKEN).
SOUND_KINDS = {
    "bas": ("fm_slapbas", "fm_housebas", "fm_subbas"),
    "lead": ("fm_lead_helder", "fm_lead_snerpend", "fm_lead_zuur", "fm_housebas_lead", "psg_lead_arp", "psg_lead_fel",
             "psg_lead", "overdrive_gitaar_solo", "clean_gitaar_solo"),
    "zacht": ("psg_arp", "fm_klok", "fm_vibrafoon", "fm_fluit"),
    "akkoord": ("synthwave_pad", "synth_brass", "fm_stoot_metaal", "overdrive_gitaar", "clean_gitaar", "fm_piano",
                "fm_strijkers"),
}
DRUM_KIT_NAMES = ("standaard", "dmx")


def own_voices(arrangement: "Arrangement") -> dict:
    """{kind of SOUND_KINDS: (FM channel, why)}: which patch of the VGM plays each kind of
    sound in the derived pieces. The bass and the melody are the channels that play them; the
    soft sounds (bells, flute, arpeggio) and the chords get a patch the VGM sets but does not
    play, when there is one (the mildest for the soft sounds, the one with the most carriers
    for the chords), else the patch of the chords or the melody."""
    song = arrangement.song
    fm_of = {part: channels[0] for part, channels in arrangement.part_channels.items() if channels[0] in song.patches}
    if not fm_of:
        return {}
    melody = fm_of.get("lead") or next(iter(fm_of.values()))
    voices = {"lead": (melody, "het kanaal van de melodie"),
              "bas": (fm_of.get("bas", melody), "het kanaal van de bas" if "bas" in fm_of else "geen FM-bas: de melodie")}
    unplayed = [channel for channel in sorted(song.patches) if channel not in song.voices]
    chords = next((fm_of[part] for part in fm_of if part.startswith(("pad", "brass"))), None)
    if chords:
        voices["akkoord"] = (chords, "het kanaal van de akkoorden")
    elif unplayed:
        fullest = max(unplayed, key=lambda channel: len(song.patches[channel].carriers()))
        voices["akkoord"] = (fullest, "een patch die het VGM zet maar niet speelt (de meeste dragers)")
    else:
        voices["akkoord"] = (melody, "geen eigen patch: die van de melodie")
    spare = [channel for channel in unplayed if channel != voices["akkoord"][0]] or unplayed
    if spare:
        mildest = min(spare, key=lambda channel: song.patches[channel].feedback)
        voices["zacht"] = (mildest, "een patch die het VGM zet maar niet speelt (de minste feedback)")
    else:
        voices["zacht"] = (melody, "geen eigen patch: die van de melodie")
    return voices


def voice_name(song: VgmSong, channel: str, like: str) -> str:
    """The name instruments.SOUNDS knows the patch of a channel by, at the place of `like`."""
    return f"vgm:{os.path.basename(song.path)}:{channel}={like}"


## Where the middle of each kind of part belongs (MIDI), as the derived pieces expect them
## (derive.py lowers the melody an octave for the piano and the flute; the existing
## compositions have the bass around E2 and the melody around E5-E6).
REGISTER_MIDDLE = {"bas": 40, "lead": 76, "arp": 76, "pad": 57, "brass": 57}


def arrange(song: VgmSong, timing: Timing) -> Arrangement:
    by_channel = {channel: _on_grid([note for note in song.notes if note.channel == channel], timing)
                  for channel in song.channels()}
    by_channel = {channel: notes for channel, notes in by_channel.items() if notes}
    remarks = []
    medians = {channel: _median([note.pitches[0] for note in notes]) for channel, notes in by_channel.items()}
    onsets = {channel: {note.step for note in notes} for channel, notes in by_channel.items()}
    mean_beats = {channel: sum(note.steps for note in notes) / len(notes) * timing.step_beats
                  for channel, notes in by_channel.items()}
    part_channels = {}
    left = sorted(by_channel)
    # the bass: the lowest channel, when there is more than one and it is low
    if len(left) > 1:
        lowest = min(left, key=lambda channel: medians[channel])
        if medians[lowest] <= 57:
            part_channels["bas"] = [lowest]
            left.remove(lowest)
    # channels that strike together: one part of chords (the same pitches: a doubling, left out)
    groups = []
    for channel in list(left):
        if channel not in left or len(by_channel[channel]) < 8:
            continue
        group = [channel]
        for other in left:
            if other == channel or len(by_channel[other]) < 8:
                continue
            together = onsets[channel] & onsets[other]
            if len(together) >= 0.75 * len(onsets[channel] | onsets[other]):
                pitch_at = {note.step: note.pitches[0] for note in by_channel[other]}
                unison = sum(1 for note in by_channel[channel]
                             if note.step in together and (note.pitches[0] - pitch_at[note.step]) % 12 == 0)
                if unison >= 0.8 * len(together):
                    remarks.append(f"{other} speelt hetzelfde als {channel} (een verdubbeling): weggelaten")
                    left.remove(other)
                else:
                    group.append(other)
        if len(group) > 1:
            groups.append(group)
            for member in group:
                left.remove(member)
    counts = Counter()

    def numbered(role: str) -> str:
        counts[role] += 1
        return role if counts[role] == 1 else f"{role}{counts[role]}"

    for group in groups:
        long_notes = sum(mean_beats[channel] for channel in group) / len(group) >= 1.0
        part_channels[numbered("pad" if long_notes else "brass")] = group
    # a channel that fills most of the grid is an arpeggio, as long as a melody is left
    by_density = sorted(left, key=lambda channel: -len(by_channel[channel]))
    for channel in by_density:
        if len(left) < 2:
            break
        first, last = by_channel[channel][0].step, by_channel[channel][-1].step
        filled = len(by_channel[channel]) / max(1, last - first + 1)
        if filled >= 0.6 and mean_beats[channel] <= 1.5 * timing.step_beats:
            part_channels[numbered("arp")] = [channel]
            left.remove(channel)
    # what is left: the melodies, the one that sounds longest first
    for channel in sorted(left, key=lambda channel: -sum(note.steps for note in by_channel[channel])):
        part_channels[numbered("lead")] = [channel]
    if "lead" not in part_channels:
        # the derived pieces need a melody: the highest other part takes that name
        others = [part for part in part_channels if part != "bas"] or list(part_channels)
        highest = max(others, key=lambda part: max(medians[channel] for channel in part_channels[part]))
        part_channels["lead"] = part_channels.pop(highest)
        remarks.append(f"geen aparte melodie gevonden: de partij '{highest}' is de lead")
    parts = {}
    sounds = {}
    reasons = {}
    octaves = {}
    for part, channels in part_channels.items():
        parts[part] = (_chords_of([by_channel[channel] for channel in channels]) if len(channels) > 1
                       else by_channel[channels[0]])
        length = sum(mean_beats[channel] for channel in channels) / len(channels)
        sounds[part], reasons[part] = choose_sound(part, "+".join(channels), song.voices.get(channels[0]), length)
        middle = REGISTER_MIDDLE.get(part.rstrip("0123456789"))
        if middle is not None:
            shift = int(round((middle - _median([pitch for note in parts[part] for pitch in note.pitches])) / 12.0))
            if shift:
                octaves[part] = shift
    loudest = {}
    for hit in song.hits:
        loudest[hit.drum] = max(loudest.get(hit.drum, -999.0), hit.level_db)
    hits = sorted({(timing.step_of(hit.start), hit.drum): StepHit(timing.step_of(hit.start), hit.drum,
                                                                 _velocity(hit.level_db, loudest[hit.drum]))
                   for hit in song.hits}.values(), key=lambda hit: (hit.step, hit.drum))
    last_step = max([note.step + 1 for notes in parts.values() for note in notes] + [hit.step + 1 for hit in hits])
    arrangement = Arrangement(song, timing, parts, hits, part_channels, sounds, reasons, octaves=octaves, notes=remarks)
    arrangement.bar_count = max(1, math.ceil(last_step / timing.steps_per_bar))
    arrangement.key = find_key(arrangement)
    arrangement.chords = {bar: bar_chord(arrangement, bar) for bar in range(1, arrangement.bar_count + 1)}
    previous = tonic_name(arrangement.key)
    for bar in range(1, arrangement.bar_count + 1):
        # an empty bar keeps the chord before it
        arrangement.chords[bar] = arrangement.chords[bar] or previous
        previous = arrangement.chords[bar].split()[-1]
    arrangement.sections = find_sections(arrangement)
    arrangement.moments = find_moments(arrangement)
    return arrangement


# ----------------------------------------------------------------------------- key and chords

MAJOR_PROFILE = (6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88)
MINOR_PROFILE = (6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17)
MAJOR_TONICS = ("C", "Db", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B")
MINOR_TONICS = ("C", "C#", "D", "Eb", "E", "F", "F#", "G", "G#", "A", "Bb", "B")
## The keys written with flats (note class of the tonic).
FLAT_MAJORS = (5, 10, 3, 8, 1)
FLAT_MINORS = (2, 7, 0, 5, 10, 3)
CHORD_SHAPES = (("", (0, 4, 7)), ("m", (0, 3, 7)), ("5", (0, 7)), ("7", (0, 4, 7, 10)), ("m7", (0, 3, 7, 10)),
                ("maj7", (0, 4, 7, 11)))


def _correlation(first: list, second: list) -> float:
    mean_first = sum(first) / len(first)
    mean_second = sum(second) / len(second)
    above = sum((one - mean_first) * (other - mean_second) for one, other in zip(first, second))
    below = math.sqrt(sum((one - mean_first) ** 2 for one in first) * sum((other - mean_second) ** 2 for other in second))
    return above / below if below else 0.0


def find_key(arrangement: Arrangement) -> tuple:
    """The key (tonic, "majeur"/"mineur"): how long every note class sounds (the melody counts
    double; clipped notes not at all) against the profiles of the 24 keys (Krumhansl)."""
    weights = [0.0] * 12
    for part, notes in arrangement.parts.items():
        part_weight = 1.0 if part.startswith("lead") else 0.5
        for note in notes:
            if note.saturated:
                continue
            for pitch in note.pitches:
                weights[pitch % 12] += note.steps * part_weight
    if not any(weights):
        return ("C", "majeur")
    best = None
    for tonic in range(12):
        turned = weights[tonic:] + weights[:tonic]
        for mode, profile in (("majeur", MAJOR_PROFILE), ("mineur", MINOR_PROFILE)):
            score = _correlation(turned, list(profile))
            if best is None or score > best[0]:
                best = (score, tonic, mode)
    _score, tonic, mode = best
    return ((MAJOR_TONICS if mode == "majeur" else MINOR_TONICS)[tonic], mode)


def tonic_class(key: tuple) -> int:
    names = MAJOR_TONICS if key[1] == "majeur" else MINOR_TONICS
    return names.index(key[0])


def tonic_name(key: tuple) -> str:
    return key[0] + ("m" if key[1] == "mineur" else "")


def uses_flats(key: tuple) -> bool:
    return tonic_class(key) in (FLAT_MAJORS if key[1] == "majeur" else FLAT_MINORS)


def note_name(pitch: int, flats: bool) -> str:
    return f"{(NOTE_NAMES_FLAT if flats else NOTE_NAMES_SHARP)[pitch % 12]}{pitch // 12 - 1}"


## How much a note with a clipped pitch (RawNote.saturated) counts in the chord of its bar.
SATURATED_CHORD_WEIGHT = 0.3


def _span_weights(arrangement: Arrangement, first_step: int, last_step: int) -> tuple:
    """(weight per note class, the bass's first note class or None) over steps [first, last)."""
    weights = [0.0] * 12
    bass_first = None
    for part, notes in arrangement.parts.items():
        part_weight = 1.5 if part == "bas" else (1.2 if part.startswith(("pad", "brass")) else 1.0)
        for note in notes:
            overlap = min(note.step + note.steps, last_step) - max(note.step, first_step)
            if overlap <= 0:
                continue
            # a clipped note sounds, but its pitch is not what was meant: it counts lightly
            trust = SATURATED_CHORD_WEIGHT if note.saturated else 1.0
            for pitch in note.pitches:
                weights[pitch % 12] += overlap * part_weight * trust
            if part == "bas" and bass_first is None and note.step >= first_step and not note.saturated:
                bass_first = min(note.pitches) % 12
    return weights, bass_first


def _best_chord(weights: list, bass_first, flats: bool) -> tuple:
    """(score, chord name) of the chord whose tones cover the weights best."""
    total = sum(weights)
    if total <= 0:
        return (0.0, "")
    best = (-1e9, "")
    names = NOTE_NAMES_FLAT if flats else NOTE_NAMES_SHARP
    for root in range(12):
        for quality, intervals in CHORD_SHAPES:
            tones = [(root + interval) % 12 for interval in intervals]
            inside = sum(weights[tone] for tone in tones)
            score = inside - 0.6 * (total - inside)
            score -= 0.12 * total * sum(1 for tone in tones if weights[tone] < 0.03 * total)
            score -= 0.05 * total * (len(tones) - 3 if len(tones) > 3 else 0)
            if bass_first == root:
                score += 0.3 * total
            if weights[root] < 0.03 * total:
                score -= 0.5 * total
            if score > best[0]:
                best = (score, names[root] + quality)
    return best


def bar_chord(arrangement: Arrangement, bar: int) -> str:
    """The chord of a bar from its notes ("E7"), or two when its halves clearly differ ("C D")."""
    steps_per_bar = arrangement.timing.steps_per_bar
    first_step = (bar - 1) * steps_per_bar
    flats = uses_flats(arrangement.key)
    whole_score, whole = _best_chord(*_span_weights(arrangement, first_step, first_step + steps_per_bar), flats)
    if not whole:
        return ""
    half = steps_per_bar // 2
    first_score, first = _best_chord(*_span_weights(arrangement, first_step, first_step + half), flats)
    second_score, second = _best_chord(*_span_weights(arrangement, first_step + half, first_step + steps_per_bar), flats)
    if first and second and _root(first) != _root(second) and first_score + second_score > 1.25 * whole_score:
        return f"{first} {second}"
    return whole


def _root(chord: str) -> str:
    return chord[:2] if len(chord) > 1 and chord[1] in "#b" else chord[:1]


# ----------------------------------------------------------------------------- sections

PHRASE_BARS = 4
SECTION_NAMES = {"intro": "Intro", "thema": "Thema", "opbouw": "Opbouw", "refrein": "Refrein",
                 "breakdown": "Breakdown", "finale": "Finale"}


def _bar_material(arrangement: Arrangement, bar: int) -> tuple:
    """What a bar is recognised by: its bass line (without one: its melody, its chord)."""
    first_step = (bar - 1) * arrangement.timing.steps_per_bar
    for part in ("bas", "lead"):
        if part in arrangement.parts and (part == "bas" or "bas" not in arrangement.parts):
            return tuple((note.step - first_step, note.pitches) for note in arrangement.bar_notes(part, bar))
    return (arrangement.chords.get(bar, ""),)


def find_sections(arrangement: Arrangement) -> list:
    """The sections: phrases of four bars with the same bass line, the same parts playing and
    as many drums are one section; each gets its soort (the function the derived pieces look
    for) from where it stands and how busy it is."""
    bar_count = arrangement.bar_count
    phrases = [(first, min(first + PHRASE_BARS - 1, bar_count)) for first in range(1, bar_count + 1, PHRASE_BARS)]
    materials = [[_bar_material(arrangement, bar) for bar in range(first, last + 1)] for first, last in phrases]
    material_ids = []
    for index, material in enumerate(materials):
        found = None
        for earlier in range(index):
            both = min(len(material), len(materials[earlier]))
            same = sum(1 for offset in range(both) if material[offset] == materials[earlier][offset])
            if same >= 0.5 * both and same > 0:
                found = material_ids[earlier]
                break
        material_ids.append(index if found is None else found)
    drum_counts = [sum(len(arrangement.bar_hits(bar)) for bar in range(first, last + 1)) / (last - first + 1)
                   for first, last in phrases]
    busiest_drums = max(drum_counts) if drum_counts else 0.0
    signatures = []
    for index, (first, last) in enumerate(phrases):
        bars_with_lead = sum(1 for bar in range(first, last + 1) if arrangement.bar_notes("lead", bar))
        has_lead = bars_with_lead > 0.5 * (last - first + 1)
        sparse_drums = busiest_drums > 0 and drum_counts[index] < 0.5 * busiest_drums
        signatures.append((material_ids[index], has_lead, sparse_drums))
    merged = []
    for index, (first, last) in enumerate(phrases):
        if merged and merged[-1]["signature"] == signatures[index]:
            merged[-1]["maten"] = (merged[-1]["maten"][0], last)
        else:
            merged.append({"maten": (first, last), "signature": signatures[index]})
    for section in merged:
        first, last = section["maten"]
        events = sum(len(arrangement.bar_notes(part, bar)) for part in arrangement.parts for bar in range(first, last + 1))
        events += sum(len(arrangement.bar_hits(bar)) for bar in range(first, last + 1))
        section["energy"] = events / (last - first + 1)
    kinds = _section_kinds(merged)
    used = Counter()
    sections = []
    for section, kind in zip(merged, kinds):
        used[kind] += 1
        name = SECTION_NAMES[kind] + (f" {used[kind]}" if used[kind] > 1 else "")
        sections.append({"naam": name, "soort": kind, "maten": section["maten"]})
    return sections


def _section_kinds(merged: list) -> list:
    count = len(merged)
    material = [section["signature"][0] for section in merged]
    has_lead = [section["signature"][1] for section in merged]
    sparse = [section["signature"][2] for section in merged]
    energy = [section["energy"] for section in merged]
    if count == 1:
        return ["thema"]
    kinds = [None] * count
    kinds[0] = "thema" if has_lead[0] else "intro"
    if count == 2:
        kinds[1] = "refrein" if kinds[0] == "thema" else "thema"
        return kinds
    kinds[-1] = "finale"
    theme = 0 if kinds[0] == "thema" else next((index for index in range(1, count - 1) if has_lead[index]), 1)
    kinds[theme] = "thema"
    free = [index for index in range(count) if kinds[index] is None]
    other_material = [index for index in free if material[index] != material[theme]]
    breakdown = None
    quiet = [index for index in other_material if index > theme and (sparse[index] or energy[index] < 0.85 * energy[theme])]
    if quiet:
        breakdown = min(quiet, key=lambda index: energy[index])
        kinds[breakdown] = "breakdown"
    loud = [index for index in other_material if kinds[index] is None]
    chorus = max(loud, key=lambda index: energy[index]) if loud else None
    if chorus is not None:
        kinds[chorus] = "refrein"
    for index in free:
        if kinds[index] is not None:
            continue
        if material[index] == material[theme]:
            kinds[index] = "thema"
        elif chorus is not None and material[index] == material[chorus]:
            kinds[index] = "refrein"
        elif breakdown is not None and material[index] == material[breakdown]:
            kinds[index] = "breakdown"
        else:
            kinds[index] = "opbouw" if chorus is None or index < chorus else "breakdown"
    return kinds


## The opening line of the intro stands for this many seconds: the logo comes after it.
LOGO_EARLIEST_SECONDS = 6.0


def find_moments(arrangement: Arrangement) -> dict:
    """MOMENTEN for the intro's pictures: the logo on the theme (after the opening line), the
    story a phrase later, then the chorus, the breakdown and the finale, and the rest on the
    last bar; where the sections do not give them in that order, spread evenly."""
    timing = arrangement.timing
    bar_seconds = 60.0 / timing.tempo * timing.beats_per_bar
    last = arrangement.bar_count

    def first_bar(kind: str):
        return next((section["maten"][0] for section in arrangement.sections if section["soort"] == kind), None)

    earliest = int(math.ceil(LOGO_EARLIEST_SECONDS / bar_seconds)) + 1
    logo = max(first_bar("thema") or 1, earliest)
    wanted = [logo, logo + PHRASE_BARS, first_bar("refrein"), first_bar("breakdown"), first_bar("finale")]
    in_order = all(bar is not None for bar in wanted) and all(
        earlier < later for earlier, later in zip(wanted, wanted[1:])) and wanted[-1] <= last
    if not in_order:
        logo = min(logo, max(1, last - 5))
        wanted = [min(last, logo + int(round(index * (last - logo) / 5.0))) for index in range(5)]
    names = ("logo", "verhaal", "hoogtepunt", "duel", "crash")
    moments = dict(zip(names, wanted))
    moments["rust"] = (last, 1.0)
    return moments


# ----------------------------------------------------------------------------- the composition file

def _number(value: float) -> str:
    return f"{round(value, 4):g}"


def _note_texts(notes: list, first_step: int, timing: Timing, flats: bool) -> list:
    texts = []
    for note in notes:
        position = 1.0 + (note.step - first_step) * timing.step_beats
        names = "+".join(note_name(pitch, flats) for pitch in note.pitches)
        text = f"{_number(position)} {names} {_number(note.steps * timing.step_beats)}"
        texts.append(text + (f" {_number(note.velocity)}" if note.velocity != 1.0 else ""))
    return texts


def _wrapped_call(opening: str, items: list, indent: int, width: int = 112) -> str:
    """`opening` + the items as string literals of one notes("...") call, wrapped."""
    lines = []
    line = ""
    for index, item in enumerate(items):
        piece = item + (", " if index + 1 < len(items) else "")
        if line and indent + len(opening) + len(line) + len(piece) + 3 > width:
            lines.append(line)
            line = ""
        line += piece
    lines.append(line)
    joiner = "\"\n" + " " * (indent + len(opening)) + "\""
    return opening + "\"" + joiner.join(lines) + "\")"


def _drum_expression(hits: list, first_step: int, timing: Timing) -> str:
    """drums(snare="2 4", hihat="1 1.5 ...") (+ a drums(...) per other velocity)."""
    if not hits:
        return "[]"
    by_velocity = {}
    for hit in hits:
        position = 1.0 + (hit.step - first_step) * timing.step_beats
        by_velocity.setdefault(hit.velocity, {}).setdefault(hit.drum, []).append(_number(position))
    calls = []
    for velocity in sorted(by_velocity, reverse=True):
        arguments = []
        if timing.beats_per_bar != 4:
            arguments.append(f"beats_per_bar={timing.beats_per_bar}")
        if velocity != 1.0:
            arguments.append(f"velocity={_number(velocity)}")
        arguments += [f"{drum}=\"{' '.join(positions)}\"" for drum, positions in sorted(by_velocity[velocity].items())]
        calls.append(f"drums({', '.join(arguments)})")
    return " + ".join(calls)


def _letters(index: int) -> str:
    return (_letters(index // 26 - 1) if index >= 26 else "") + chr(ord("A") + index % 26)


def _bar_list(bars: list) -> str:
    return ", ".join(str(bar) for bar in bars)


def composition_source(arrangement: Arrangement, name: str, title: str) -> str:
    """The text of composities/<naam>.py: the VGM bar by bar in the notation of notation.py."""
    timing = arrangement.timing
    song = arrangement.song
    flats = uses_flats(arrangement.key)
    steps_per_bar = timing.steps_per_bar
    bars = range(1, arrangement.bar_count + 1)
    # every different line of a part (and of the drums) once, as a constant when it comes back
    lines = {}                    # (part, texts) -> [bars]
    for bar in bars:
        first_step = (bar - 1) * steps_per_bar
        for part in arrangement.parts:
            texts = tuple(_note_texts(arrangement.bar_notes(part, bar), first_step, timing, flats))
            if texts:
                lines.setdefault((part, texts), []).append(bar)
        drum_text = _drum_expression(arrangement.bar_hits(bar), first_step, timing)
        if drum_text != "[]":
            lines.setdefault(("drums", drum_text), []).append(bar)
    constants = {}
    counters = Counter()
    for (part, content), line_bars in lines.items():
        if len(line_bars) > 1:
            constants[(part, content)] = f"{part.upper()}_{_letters(counters[part])}"
            counters[part] += 1
    # the drums of most bars of a section are its "standaard"
    section_standard = {}
    for section in arrangement.sections:
        first, last = section["maten"]
        patterns = Counter(_drum_expression(arrangement.bar_hits(bar), (bar - 1) * steps_per_bar, timing)
                           for bar in range(first, last + 1))
        pattern, times = patterns.most_common(1)[0]
        if pattern != "[]" and times > 1:
            section_standard[section["maten"]] = pattern

    def expression(part: str, content, indent: int, opening: str) -> str:
        if (part, content) in constants:
            return opening + constants[(part, content)]
        if part == "drums":
            return opening + content
        return _wrapped_call(opening + "notes(", list(content), indent)

    out = []

    def paragraph(sentence: str, bullet: bool = False) -> None:
        out.extend(textwrap.wrap(sentence, 100, initial_indent="- " if bullet else "",
                                 subsequent_indent="  " if bullet else "", break_on_hyphens=False))

    chips = " en ".join(song.chips) or "onbekend"
    paragraph(f'"""{title}: omgezet uit het VGM-bestand {os.path.basename(song.path)} (het registerlog van de '
              f"Mega Drive-geluidschips: {chips}) door tools/muziek/vgm.py, maat voor maat in de notatie van "
              "tools/muziek/notation.py. De intro van het spel is het VGM zelf, door de nabootsing van de chips "
              "gespeeld (tools/muziek/chip.py; VGM hieronder): exacte frequenties, de patches en de volumes uit het "
              "registerlog. De maten hieronder zijn dezelfde noten op het raster (toonhoogte uit F-number en blok "
              "naar de dichtstbijzijnde noot, begin en lengte uit key-on en key-off): daar worden de andere stukken "
              "van afgeleid, in de stemmen van het VGM (AFGELEIDE_KLANKEN).")
    out.append("")
    paragraph(f"Bron: {song.seconds:.2f} s ({song.total_samples} samples van 1/44100 s)"
              + (f", lus vanaf {song.loop_sample / VGM_RATE:.2f} s" if song.loop_sample >= 0 else ", geen luspunt") + ".")
    paragraph(f"Raster: een stap is {timing.step_samples:.1f} samples, {timing.steps_per_beat} stappen per tel: "
              f"{_number(timing.tempo)} BPM, {timing.beats_per_bar} tellen per maat, {arrangement.bar_count} maten (de "
              f"noten liggen gemiddeld {timing.fit:.3f} stap van het raster).")
    if timing.name_tempo:
        if timing.name_tempo_fits:
            paragraph(f"De {_number(timing.name_tempo)} in de bestandsnaam is het tempo: het klopt met de noten.")
        else:
            paragraph(f"De {_number(timing.name_tempo)} in de bestandsnaam is niet het tempo: geen telverdeling van "
                      "het raster komt daarop uit.")
    out.append("")
    out.append("Partijen (kanaal -> partij; de partij klinkt met de patch van dat kanaal, op de plek in de mix van")
    out.append("de klank die bij de patch past):")
    for part, channels in arrangement.part_channels.items():
        paragraph(f"{part}: {arrangement.sound_reasons[part]} -> de plek van {arrangement.sounds[part]}", bullet=True)
    drum_sources = Counter((hit.source, hit.drum) for hit in song.hits)
    if drum_sources:
        listed = ", ".join(f"{drum} ({'PSG-ruis' if source == 'psg_ruis' else 'DAC'}, {count}x)"
                           for (source, drum), count in sorted(drum_sources.items()))
        paragraph(f"drums: {listed}", bullet=True)
    out.append("")
    paragraph("Afgeleid uit de noten (het VGM zegt ze niet): de toonsoort, het akkoord van elke maat, de secties "
              "met hun soort en de MOMENTEN van de intro.")
    for remark in song.warnings + arrangement.notes:
        out.append("")
        paragraph(f"Let op: {remark}.")
    out.append('"""')
    out.append("from notation import drums, notes")
    out.append("")
    out.append(f"TITEL = {title!r}".replace("'", '"'))
    out.append(f"TEMPO = {_number(timing.tempo)}")
    out.append(f"TELLEN_PER_MAAT = {timing.beats_per_bar}")
    out.append(f'TOONSOORT = ("{arrangement.key[0]}", "{arrangement.key[1]}")')
    out.append("")
    out.append("# het VGM waar de intro letterlijk uit gespeeld wordt (in deze map)")
    out.append(f'VGM = "{os.path.basename(song.path)}"')
    out.append("")
    out.append("# elke partij met de patch van haar eigen kanaal (\"vgm:<bestand>:<kanaal>=<klank>\": even hard en op")
    out.append("# dezelfde plek in de mix als die klank)")
    out.append("KLANKEN = {")
    for part, channels in arrangement.part_channels.items():
        sound = (voice_name(song, channels[0], arrangement.sounds[part]) if channels[0] in song.patches
                 else arrangement.sounds[part])
        out.append(f'    "{part}": "{sound}",   # {", ".join(channels)}')
    out.append("}")
    voices = own_voices(arrangement)
    if voices:
        out.append("")
        out.append("# de afgeleide stukken in de stemmen van het VGM: elke klank die ze gebruiken wordt de patch van een")
        out.append("# kanaal van het VGM (op de plek en het niveau van die klank), het drumstel dat van het VGM (snare en")
        out.append("# hi-hat de PSG-ruis van het VGM; kick, toms, clap, open hi-hat en crash daarvan afgeleid)")
        for kind, (channel, why) in voices.items():
            out.append(f"# - {kind}: {channel} ({why})")
        out.append("AFGELEIDE_KLANKEN = {")
        for kind, (channel, _why) in voices.items():
            for sound in SOUND_KINDS[kind]:
                out.append(f'    "{sound}": "{voice_name(song, channel, sound)}",')
        for kit in DRUM_KIT_NAMES:
            out.append(f'    "{kit}": "vgm:{os.path.basename(song.path)}",')
        out.append("}")
    out.append("")
    out.append("# waar de intro-beelden wisselen (scripts/ui/intro.gd): het logo op het thema, het verhaal een")
    out.append("# frase later, dan het refrein, de breakdown en de finale; de rust op de laatste maat")
    moment_texts = [f'"{moment}": {value!r}' for moment, value in arrangement.moments.items()]
    out.append("MOMENTEN = {" + ", ".join(moment_texts) + "}")
    if arrangement.octaves:
        out.append("")
        out.append("# de maten hieronder staan in het octaaf van het VGM, en zo klinkt de intro; alleen in de afgeleide")
        out.append("# stukken liggen deze partijen zoveel octaven hoger (+) of lager (-), in het register waar die")
        out.append("# stukken op rekenen (de melodie rond octaaf 5, de bas rond octaaf 2)")
        octave_texts = ", ".join(f'"{part}": {shift}' for part, shift in arrangement.octaves.items())
        out.append("AFGELEID_OCTAAF = {" + octave_texts + "}")
    out.append("")
    for (part, content), constant in constants.items():
        opening = f"{constant} = "
        text = expression(part, content, 0, "") if part == "drums" else _wrapped_call(opening + "notes(", list(content), 0)
        out.append((opening + content if part == "drums" else text) + f"   # maat {_bar_list(lines[(part, content)])}")
    out.append("")
    out.append("SECTIES = [")
    for section in arrangement.sections:
        entry = f'    {{"naam": "{section["naam"]}", "soort": "{section["soort"]}", "maten": {section["maten"]!r}'
        standard = section_standard.get(section["maten"])
        if standard:
            entry += f', "standaard": {{"drums": {constants.get(("drums", standard), standard)}}}'
        out.append(entry + "},")
    out.append("]")
    out.append("")
    out.append("MATEN = {")
    for section in arrangement.sections:
        first, last = section["maten"]
        out.append(f"    # {'-' * 66} {section['naam']} ({section['soort']})")
        standard = section_standard.get(section["maten"])
        for bar in range(first, last + 1):
            first_step = (bar - 1) * steps_per_bar
            entries = [f'"akkoord": "{arrangement.chords[bar]}"']
            for part in arrangement.parts:
                texts = tuple(_note_texts(arrangement.bar_notes(part, bar), first_step, timing, flats))
                if texts:
                    entries.append(expression(part, texts, 8, f'"{part}": '))
            drum_text = _drum_expression(arrangement.bar_hits(bar), first_step, timing)
            if drum_text != (standard or "[]"):
                entries.append(expression("drums", drum_text, 8, '"drums": '))
            opening = f"    {bar}: {{"
            out.append(opening + (",\n" + " " * len(opening)).join(entries) + "},")
    out.append("}")
    return "\n".join(out) + "\n"


def default_name(path: str) -> str:
    base = os.path.splitext(os.path.basename(path))[0].lower()
    return re.sub(r"[^a-z0-9]+", "_", base).strip("_") or "vgm"


def default_title(song: VgmSong, name: str) -> str:
    if song.title:
        return song.title
    words = [word for word in name.split("_") if word]
    if len(words) > 1 and words[-1].isdigit():
        words = words[:-1]
    return " ".join(word.capitalize() for word in words)


# ----------------------------------------------------------------------------- report and comparison

def report(arrangement: Arrangement) -> str:
    song = arrangement.song
    timing = arrangement.timing
    flats = uses_flats(arrangement.key)
    lines = [f"VGM {os.path.basename(song.path)}: versie {song.version >> 8:x}.{song.version & 0xFF:02x}, "
             f"{song.seconds:.2f} s, " + ("geen luspunt" if song.loop_sample < 0 else f"lus vanaf {song.loop_sample / VGM_RATE:.2f} s"),
             f"chips: {', '.join(song.chips) or 'onbekend'}",
             f"tempo: {_number(timing.tempo)} BPM ({timing.steps_per_beat} stappen van {timing.step_samples:.1f} samples per tel, "
             f"afstand tot het raster {timing.fit:.3f} stap), {timing.beats_per_bar} tellen per maat, "
             f"{arrangement.bar_count} maten = {arrangement.bar_count * timing.beats_per_bar * 60.0 / timing.tempo:.2f} s"]
    if timing.name_tempo:
        lines.append(f"bestandsnaam: {_number(timing.name_tempo)} "
                     + ("is het tempo (klopt met de noten)" if timing.name_tempo_fits
                        else "is niet het tempo (past op geen telverdeling van het raster)"))
    lines.append(f"toonsoort: {arrangement.key[0]} {arrangement.key[1]}")
    for part, channels in arrangement.part_channels.items():
        notes = arrangement.parts[part]
        pitches = [pitch for note in notes for pitch in note.pitches]
        raw = sum(song.key_ons[channel] for channel in channels)
        shift = arrangement.octaves.get(part, 0)
        lines.append(f"  {part:6s} {'+'.join(channels):9s} {raw:5d} key-ons -> {len(notes):5d} noten, "
                     f"{note_name(min(pitches), flats)}..{note_name(max(pitches), flats)}"
                     + (f" (afgeleide stukken {shift:+d} octaaf)" if shift else "")
                     + f", de patch van het kanaal op de plek van {arrangement.sounds[part]}")
        lines.append(f"         {arrangement.sound_reasons[part]}")
    drum_counts = Counter(hit.drum for hit in arrangement.hits)
    raw_hits = Counter(hit.source for hit in song.hits)
    lines.append(f"  drums  {dict(raw_hits)} -> " + (", ".join(f"{drum} {count}" for drum, count in sorted(drum_counts.items())) or "geen"))
    lines.append("secties: " + ", ".join(f"{section['naam']} ({section['soort']}) maat {section['maten'][0]}-{section['maten'][1]}"
                                         for section in arrangement.sections))
    lines.append("akkoorden: " + " | ".join(arrangement.chords[bar] for bar in range(1, arrangement.bar_count + 1)))
    lines.append(f"momenten: {arrangement.moments}")
    lines += [f"let op: {remark}" for remark in song.warnings + arrangement.notes]
    return "\n".join(lines)


def compare(arrangement: Arrangement, name: str) -> list:
    """Compares composities/<naam>.py (as score.py reads it) with the VGM: every part's notes
    (bar, position, pitches, length) and the drums must be the same, and the piece as long.
    Returns the problems (empty: the same); prints a line per part."""
    import score as score_module
    timing = arrangement.timing
    score = score_module.load(name)
    problems = []
    if abs(score.tempo - timing.tempo) > 1e-6 or score.beats_per_bar != timing.beats_per_bar:
        problems.append(f"tempo/maat: {score.tempo:g} BPM in {score.beats_per_bar}, het VGM geeft {timing.tempo:g} in "
                        f"{timing.beats_per_bar}")
    written_seconds = len(score.bars) * score.bar_seconds
    last_sound = max([note.end for note in arrangement.song.notes] + [hit.end for hit in arrangement.song.hits])
    vgm_seconds = (last_sound - timing.origin) / VGM_RATE
    print(f"lengte: de compositie {written_seconds:.2f} s ({len(score.bars)} maten), het VGM {vgm_seconds:.2f} s "
          f"van de eerste tot de laatste klank")
    if abs(written_seconds - vgm_seconds) > score.bar_seconds:
        problems.append(f"lengte: {written_seconds:.2f} s tegen {vgm_seconds:.2f} s in het VGM")
    module = sys.modules[name]
    octaves = getattr(module, "BIJSTELLING", {}).get("octaaf", {})
    flats = uses_flats(arrangement.key)
    for part, notes in arrangement.parts.items():
        shift = 12 * octaves.get(part, 0)
        wanted = sorted((arrangement.bar_of(note.step),
                         round(1.0 + (note.step % timing.steps_per_bar) * timing.step_beats, 4),
                         note.pitches, round(note.steps * timing.step_beats, 4)) for note in notes)
        written = sorted((bar.number, round(note.position, 4), tuple(pitch - shift for pitch in note.pitches),
                          round(note.length, 4)) for bar in score.bars for note in bar.parts.get(part, []))
        raw = sum(arrangement.song.key_ons[channel] for channel in arrangement.part_channels[part])
        pitches = [pitch for _bar, _position, note_pitches, _length in written for pitch in note_pitches] or [0]
        same = wanted == written
        print(f"{part:6s} VGM {raw:5d} key-ons, op het raster {len(wanted):5d} noten; compositie {len(written):5d} noten, "
              f"{note_name(min(pitches), flats)}..{note_name(max(pitches), flats)}"
              + (f" (klinkt {octaves[part]:+d} octaaf)" if part in octaves else "") + (": gelijk" if same else ": ANDERS"))
        if not same:
            differing = sorted(set(wanted) ^ set(written))[:5]
            problems.append(f"{part}: {len(set(wanted) ^ set(written))} noten anders, bv. {differing}")
    wanted_hits = sorted((arrangement.bar_of(hit.step), round(1.0 + (hit.step % timing.steps_per_bar) * timing.step_beats, 4),
                          hit.drum) for hit in arrangement.hits)
    written_hits = sorted((bar.number, round(hit.position, 4), hit.drum) for bar in score.bars for hit in bar.hits)
    # (a BIJSTELLING may add drums; only what the VGM has must be there)
    missing = [hit for hit in wanted_hits if hit not in written_hits]
    print(f"drums  VGM {len(arrangement.song.hits):5d} slagen, op het raster {len(wanted_hits):5d}; compositie "
          f"{len(written_hits):5d}" + (": gelijk" if wanted_hits == written_hits else (": ANDERS" if missing else ": meer (bijstelling)")))
    if missing:
        problems.append(f"drums: {len(missing)} slagen ontbreken, bv. {missing[:5]}")
    return problems


def measure(song: VgmSong, intro_path: str = None) -> list:
    """Measures the chip imitation (chip.py) against the register log, and the rendered intro
    against the imitation. Per FM and PSG tone channel, played alone: the pitch of every note
    (the period it repeats with, near the one the registers give, in cents from it). The PSG
    noise: the level of every hit against its volume register. The intro file: its length, how
    alike it is to the bare imitation (correlation) and the level of every eighth of it against
    the imitation's. Returns the problems (Dutch); prints the measurements."""
    import numpy
    import chip
    problems = []
    window_least = int(0.06 * VGM_RATE)
    for channel in song.channels():
        alone = chip.render_song(song, 0.0, (channel if channel.startswith("fm") else "psg",)).mean(axis=1)
        if channel.startswith("psg"):
            # the tone channels share the PSG with the noise: only measurable where a tone sounds; skipped here
            continue
        cents = []
        for note in song.notes:
            if note.channel != channel or note.end - note.start < window_least:
                continue
            # the period: the lag near the one the registers give at which the note repeats best
            piece = alone[note.start + 256:note.end - 64]
            wanted = 440.0 * 2 ** ((note.pitch - 69) / 12.0)
            lags = range(int(VGM_RATE / wanted * 0.94), int(VGM_RATE / wanted * 1.06) + 2)
            alike = [float(numpy.dot(piece[:-lag], piece[lag:])) / (len(piece) - lag) for lag in lags]
            best = int(numpy.argmax(alike))
            shift = 0.0
            if 0 < best < len(alike) - 1:
                bend = alike[best - 1] - 2.0 * alike[best] + alike[best + 1]
                shift = 0.5 * (alike[best - 1] - alike[best + 1]) / bend if bend else 0.0
            found = VGM_RATE / (lags[best] + shift)
            cents.append(1200.0 * math.log2(found / wanted))
        if cents:
            worst = max(abs(value) for value in cents)
            middle = sorted(abs(value) for value in cents)[len(cents) // 2]
            exact = song.notes and [note for note in song.notes if note.channel == channel]
            lowest = min(440.0 * 2 ** ((note.pitch - 69) / 12.0) for note in exact)
            highest = max(440.0 * 2 ** ((note.pitch - 69) / 12.0) for note in exact)
            print(f"{channel}: {len(cents)} noten gemeten, {lowest:.2f}..{highest:.2f} Hz volgens de registers; de nabootsing "
                  f"wijkt gemiddeld {middle:.1f} cent af, hooguit {worst:.1f} cent")
            if worst > 25.0:
                problems.append(f"{channel}: een noot {worst:.0f} cent naast de frequentie van de registers")
    noise = [hit for hit in song.hits if hit.source == "psg_ruis" and hit.end - hit.start >= window_least]
    if noise:
        alone = chip.render_song(song, 0.0, ("psg",)).mean(axis=1)
        off = []
        for hit in noise:
            level = numpy.sqrt(numpy.mean(alone[hit.start + 64:hit.end - 64] ** 2))
            wanted = chip.PSG_LEVEL * 10.0 ** (hit.level_db / 20.0)
            off.append(abs(20.0 * math.log10(max(level, 1e-9) / wanted)))
        print(f"psg-ruis: {len(noise)} slagen gemeten; het niveau wijkt hooguit {max(off):.2f} dB af van het volumeregister")
        if max(off) > 1.0:
            problems.append(f"psg-ruis: een slag {max(off):.1f} dB naast zijn volume")
    for remark in chip.unsupported(song):
        print(f"niet nagebootst: {remark}")
    if intro_path and os.path.exists(intro_path):
        import soundfile
        written, rate = soundfile.read(intro_path)
        bare = chip.render_song(song, 0.0)
        origin = min([note.start for note in song.notes] + [hit.start for hit in song.hits] + [song.total_samples])
        bare = bare[origin:]
        both = min(len(written), len(bare))
        print(f"intro: {len(written) / rate:.2f} s; het VGM {len(bare) / VGM_RATE:.2f} s (de rest is uitklinken)")
        alike = [float(numpy.corrcoef(written[:both, side], bare[:both, side])[0, 1]) for side in (0, 1)]
        print(f"intro tegen de kale nabootsing (voor het filter en de luidheid): correlatie links {alike[0]:.3f}, "
              f"rechts {alike[1]:.3f}")
        if min(alike) < 0.8:
            problems.append(f"de intro lijkt te weinig op de nabootsing (correlatie {min(alike):.2f})")
        eighth = both // 8
        levels = []
        for part in range(8):
            ours = numpy.sqrt(numpy.mean(written[part * eighth:(part + 1) * eighth] ** 2))
            theirs = numpy.sqrt(numpy.mean(bare[part * eighth:(part + 1) * eighth] ** 2))
            levels.append(20.0 * math.log10(ours / theirs))
        spread = max(levels) - min(levels)
        print("intro: niveau per achtste deel tegen de nabootsing (dB): " + ", ".join(f"{level:.1f}" for level in levels)
              + f" (verschil onderling {spread:.2f} dB)")
        if spread > 1.5:
            problems.append(f"de dynamiek van de intro wijkt {spread:.1f} dB af van de nabootsing")
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("vgm", help="the VGM file (.vgm or .vgz)")
    parser.add_argument("naam", nargs="?", help="the name of the composition (default: the file name)")
    parser.add_argument("--toon", action="store_true", help="only show what the file holds")
    parser.add_argument("--vergelijk", action="store_true", help="compare composities/<naam>.py with the file")
    parser.add_argument("--meet", action="store_true",
                        help="measure the chip imitation against the registers, and the rendered intro against it")
    parser.add_argument("--overschrijf", action="store_true", help="replace an existing composities/<naam>.py")
    parser.add_argument("--tempo", type=float, help="the tempo in BPM (default: from the notes and the file name)")
    parser.add_argument("--titel", help="the title (default: the VGM's own, else from the name)")
    arguments = parser.parse_args()
    song = read(arguments.vgm)
    arrangement = arrange(song, find_timing(song, arguments.tempo))
    name = arguments.naam or default_name(arguments.vgm)
    print(report(arrangement))
    if arguments.toon:
        return 0
    if arguments.meet:
        intro_path = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "audio", "muziek", "zwervr_intro.ogg")
        problems = measure(song, intro_path)
        if problems:
            print("VERSCHILLEN:\n  " + "\n  ".join(problems))
            return 1
        print("de nabootsing komt overeen met het registerlog")
        return 0
    target = os.path.join(COMPOSITIONS_FOLDER, name + ".py")
    if arguments.vergelijk:
        sys.path.insert(0, HERE)
        problems = compare(arrangement, name)
        if problems:
            print("VERSCHILLEN:\n  " + "\n  ".join(problems))
            return 1
        print("de compositie komt overeen met het VGM")
        return 0
    if os.path.exists(target) and not arguments.overschrijf:
        print(f"{target} bestaat al (handwerk erin gaat verloren): geef --overschrijf om het te vervangen")
        return 1
    # the source next to the composition, unchanged, under the composition's name
    kept = os.path.join(COMPOSITIONS_FOLDER, name + os.path.splitext(arguments.vgm)[1].lower())
    if os.path.abspath(kept) != os.path.abspath(arguments.vgm):
        shutil.copyfile(arguments.vgm, kept)
        print(f"bron bewaard: {kept}")
        arrangement.song.path = kept
    with open(target, "w") as composition_file:
        composition_file.write(composition_source(arrangement, name, arguments.titel or default_title(song, name)))
    print(f"geschreven: {target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
