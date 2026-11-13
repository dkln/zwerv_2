"""Checks the music: what is written (assets/audio/muziek/, or --map) and the composition itself.

    tools/muziek/render.sh --controle               the files: length, loudness, peak, loop seam
    tools/muziek/render.sh --controle --balans      also how loud every part of the intro is
    tools/muziek/render.sh --controle --map <dir>   the files in another folder

For the files: every piece exists, is as long as the score says, at -16 LUFS (within 0.5),
peaks under -1.5 dB, no stretch of silence inside a loop, and a loop's end runs into its start
without a jump. For the composition: every note of the melodies is in the key (D minor: D
natural/harmonic minor; the composer's chromatic notes are listed, not failed), and the parts'
balance in the intro (each rendered alone, dB under the loudest).
"""
import argparse
import os
import sys

import numpy
import soundfile

import chip
import derive
import instruments
import mixer
import score as score_module

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "megadrive"))
import loudness  # noqa: E402

MUSIC_FOLDER = os.path.join(score_module.PROJECT, "assets", "audio", "muziek")
SAMPLE_RATE = mixer.SAMPLE_RATE


def check_file(piece: mixer.Piece, folder: str) -> list:
    problems = []
    path = os.path.join(folder, piece.name + ".ogg")
    if not os.path.exists(path):
        return [f"{piece.name}: ontbreekt ({path})"]
    stereo, rate = soundfile.read(path)
    seconds = len(stereo) / rate
    lufs = loudness.integrated_lufs(stereo)
    peak = 20 * numpy.log10(numpy.abs(stereo).max() + 1e-12)
    line = f"{piece.name:24s} {seconds:6.2f} s  {lufs:6.1f} LUFS  piek {peak:5.1f} dB"
    if abs(seconds - piece.seconds) > 0.05:
        problems.append(f"{piece.name}: {seconds:.2f} s, de partituur zegt {piece.seconds:.2f} s")
    if abs(lufs - loudness.TARGET_LUFS) > 0.5:
        problems.append(f"{piece.name}: {lufs:.1f} LUFS (moet {loudness.TARGET_LUFS:.0f})")
    if peak > mixer.MUSIC_CEILING_DB + 0.3:
        problems.append(f"{piece.name}: piek {peak:.1f} dB")
    if piece.loop:
        # the seam: the step from the last sample to the first, against the usual step
        steps = numpy.abs(numpy.diff(stereo, axis=0)).max(axis=1)
        seam = numpy.abs(stereo[0] - stereo[-1]).max()
        usual = numpy.percentile(steps, 99.9)
        line += f"  naad {seam:.3f} (gewoon tot {usual:.3f})"
        if seam > usual * 1.5 + 0.01:
            problems.append(f"{piece.name}: de lus springt bij de naad ({seam:.3f})")
        window = int(0.5 * rate)
        powers = [numpy.mean(stereo[start:start + window] ** 2) for start in range(0, len(stereo) - window, window)]
        if min(powers) < 1e-6:
            problems.append(f"{piece.name}: een halve seconde stilte in de lus")
    print(line)
    return problems


def check_key(score: score_module.Score) -> None:
    tonic = score.tonic()
    allowed = {0, 2, 3, 5, 7, 8, 10, 11} if score.is_minor() else {0, 2, 4, 5, 7, 9, 11}
    outside = {}
    for bar in score.bars:
        for part in ("lead", "solo", "arp"):
            for note in bar.parts.get(part, []):
                for midi in note.pitches:
                    if (midi - tonic) % 12 not in allowed:
                        outside.setdefault(bar.number, set()).add(f"{part} {midi}")
    if outside:
        listed = ", ".join(f"maat {number}: {sorted(found)}" for number, found in sorted(outside.items()))
        print(f"buiten de toonsoort (chromatiek van de componist, ter controle): {listed}")
    else:
        print("alle melodienoten in de toonsoort")


def section_energy(folder: str, score: score_module.Score) -> None:
    path = os.path.join(folder, "zwervr_intro.ogg")
    if not os.path.exists(path):
        return
    stereo, rate = soundfile.read(path)
    parts = []
    for section in score.sections:
        first, last = section["maten"]
        start = int((first - 1) * score.bar_seconds * rate)
        end = int(last * score.bar_seconds * rate)
        level = 10 * numpy.log10(numpy.mean(stereo[start:end] ** 2) + 1e-12)
        parts.append(f"{section['soort']} {level:.1f}")
    print("energie per sectie van de intro (dB): " + ", ".join(parts))


def balance(score: score_module.Score) -> None:
    """Every part of the intro alone, at the level it has in the mix (no loudness levelling)."""
    if score.vgm:
        vgm_balance(score.vgm)
        return
    piece = derive.intro(score)
    names = sorted({part for bar in piece.bars for part in bar.parts} | {"drums"})
    levels = {}
    for name in names:
        alone = mixer.Piece(piece.name, piece.tempo, piece.beats_per_bar,
                            [derive.keep(bar, (name,), keep_drums=name == "drums") for bar in piece.bars],
                            piece.sounds, loop=False, tail=piece.tail)
        signal = mixer.raw_mix(alone)
        # only where it plays: the 100 ms windows within 30 dB of its loudest
        window = int(0.1 * SAMPLE_RATE)
        powers = numpy.array([numpy.mean(signal[start:start + window] ** 2)
                              for start in range(0, len(signal) - window, window)])
        playing = powers[powers > powers.max() * 1e-3]
        levels[name] = 10 * numpy.log10(playing.mean() + 1e-12)
    loudest = max(levels.values())
    print("balans van de intro (dB onder de luidste, elk alleen, waar hij speelt): "
          + ", ".join(f"{name} {level - loudest:.1f}" for name, level in sorted(levels.items(), key=lambda item: -item[1])))


def vgm_balance(file_name: str) -> None:
    """The channels of the VGM the intro is, each played alone by the chip imitation: the
    balance is the VGM's own (nothing is set here)."""
    song = instruments.vgm_song(file_name)
    names = song.channels() + (["psg"] if song.psg_writes else []) + (["dac"] if song.dac_writes or song.dac_streams else [])
    names = sorted({"psg" if name.startswith("psg") else name for name in names})
    levels = {}
    window = int(0.1 * SAMPLE_RATE)
    for name in names:
        signal = chip.render_song(song, 0.0, (name,)).mean(axis=1)
        powers = numpy.array([numpy.mean(signal[start:start + window] ** 2) for start in range(0, len(signal) - window, window)])
        playing = powers[powers > powers.max() * 1e-3]
        levels[name] = 10 * numpy.log10(playing.mean() + 1e-12)
    loudest = max(levels.values())
    print("balans van de intro (de kanalen van het VGM zelf, dB onder de luidste, elk alleen, waar het speelt): "
          + ", ".join(f"{name} {level - loudest:.1f}" for name, level in sorted(levels.items(), key=lambda item: -item[1])))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--map", default=MUSIC_FOLDER)
    parser.add_argument("--balans", action="store_true")
    arguments = parser.parse_args()
    score = score_module.load()
    problems = []
    for piece in derive.pieces(score):
        problems += check_file(piece, arguments.map)
    section_energy(arguments.map, score)
    check_key(score)
    if arguments.balans:
        balance(score)
    if problems:
        print("PROBLEMEN:\n  " + "\n  ".join(problems))
        raise SystemExit(1)
    print("muziek ok")


if __name__ == "__main__":
    main()
