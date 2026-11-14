extends RefCounted
## How the sounds of the machines are made (the rules layer of
## scripts/ui/machines/machine_sounds.gd, which keeps the streams and plays them): which
## sounds there are, the samples of each (in the manner of a 16-bit console's sound chip:
## square waves of the PSG, a little noise channel, coarse volume steps), how loud each is
## played and the samples as 16-bit bytes. Plain functions; the noise takes the random
## generator it is handed (it seeds it itself, so the same sound comes out every time).
##   const MachineSoundsRules = preload("res://scripts/ui/machines/machine_sounds_rules.gd")

const MIX_RATE := 22050
const VOLUME_DB := -9.0
## The sounds that came out louder than the rest (measured: docs/GELUIDEN.md "Eén mix"), brought
## back to about -16 LUFS as made, so with VOLUME_DB they are heard at about -22.
const LEVEL_TRIM_DB := {"blik": -4.8, "fout": -2.2, "goed": -1.4}
## Every sound there is (see machine_sounds.gd for what each one is).
const NAMES := ["toets", "goed", "fout", "blik", "band", "printer", "geld", "kaart", "inslikken"]
## The loudest sample as a 16-bit number.
const FULL_SCALE := 26000.0


## Whether there is a sound called `sound_name`.
static func is_sound(sound_name: String) -> bool:
	return NAMES.has(sound_name)


## How loud `sound_name` is played (dB): the mix, its own trim and `softer_db`.
static func volume_db(sound_name: String, softer_db := 0.0) -> float:
	return VOLUME_DB + LEVEL_TRIM_DB.get(sound_name, 0.0) + softer_db


## The samples of `sound_name` (empty: no such sound); `random` makes its noise.
static func samples(sound_name: String, random: RandomNumberGenerator) -> PackedFloat32Array:
	var made := PackedFloat32Array()
	match sound_name:
		"toets":
			made = square(1480.0, 0.05, 0.5)
		"goed":
			made = square(1046.5, 0.07, 0.5) + silence(0.02) + square(1568.0, 0.11, 0.5)
		"fout":
			made = square(196.0, 0.14, 0.5) + silence(0.05) + square(185.0, 0.2, 0.5)
		"blik":
			made = noise(0.12, 0.6, 2, random) + sweep(520.0, 140.0, 0.16, 0.7)
		"band":
			made = noise(0.5, 0.25, 12, random)
		"printer":
			for tick in 9:
				made += noise(0.025, 0.45, 1, random) + square(2600.0, 0.012, 0.25) + silence(0.03)
		"geld":
			made = sweep(160.0, 210.0, 0.35, 0.35)
			for flutter in 6:
				made += noise(0.03, 0.5, 3, random) + silence(0.025)
		"kaart":
			made = noise(0.02, 0.7, 1, random) + sweep(240.0, 300.0, 0.25, 0.3)
		"inslikken":
			made = sweep(300.0, 90.0, 0.9, 0.35) + sweep(120.0, 50.0, 0.12, 0.8)
	return made


## A square wave (25 % duty, as the PSG), its volume falling in 16 steps.
static func square(pitch: float, seconds: float, loudness: float) -> PackedFloat32Array:
	var count := int(seconds * MIX_RATE)
	var made := PackedFloat32Array()
	made.resize(count)
	var phase := 0.0
	for sample_index in count:
		phase = fmod(phase + pitch / MIX_RATE, 1.0)
		var share := float(sample_index) / count
		var envelope := roundf((1.0 - share * 0.7) * 15.0) / 15.0
		made[sample_index] = (1.0 if phase < 0.25 else -1.0) * loudness * envelope
	return made


## A square wave sliding from one pitch to another.
static func sweep(from_pitch: float, to_pitch: float, seconds: float, loudness: float) -> PackedFloat32Array:
	var count := int(seconds * MIX_RATE)
	var made := PackedFloat32Array()
	made.resize(count)
	var phase := 0.0
	for sample_index in count:
		var share := float(sample_index) / count
		phase = fmod(phase + lerpf(from_pitch, to_pitch, share) / MIX_RATE, 1.0)
		var envelope := roundf(clampf(share / 0.05, 0.0, 1.0) * (1.0 - share * 0.8) * 15.0) / 15.0
		made[sample_index] = (1.0 if phase < 0.5 else -1.0) * loudness * envelope
	return made


## Noise from the noise channel: a new random level every `hold` samples (more: lower).
## `random` is seeded here with the length and the hold: the same noise every time.
static func noise(seconds: float, loudness: float, hold: int, random: RandomNumberGenerator) -> PackedFloat32Array:
	var count := int(seconds * MIX_RATE)
	var made := PackedFloat32Array()
	made.resize(count)
	random.seed = hash([seconds, hold])
	var level := 0.0
	for sample_index in count:
		if sample_index % maxi(hold, 1) == 0:
			level = 1.0 if random.randf() < 0.5 else -1.0
		var share := float(sample_index) / count
		made[sample_index] = level * loudness * roundf((1.0 - share) * 15.0) / 15.0
	return made


static func silence(seconds: float) -> PackedFloat32Array:
	var made := PackedFloat32Array()
	made.resize(int(seconds * MIX_RATE))
	return made


## The samples (-1..1, clipped) as 16-bit bytes, the data of a mono stream.
static func pcm_bytes(from_samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(from_samples.size() * 2)
	for sample_index in from_samples.size():
		data.encode_s16(sample_index * 2, int(clampf(from_samples[sample_index], -1.0, 1.0) * FULL_SCALE))
	return data
