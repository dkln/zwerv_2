extends RefCounted
## The sounds of the machines (the deposit machine, the OV-chipkaart machine, the cash
## machine: scripts/ui/machines/), made in code in the manner of a 16-bit console's sound
## chip, as UiSounds: square waves of the PSG, a little noise channel, coarse volume steps.
## - "toets": a key of a keypad or a button of the screen: a short high square beep;
## - "goed": accepted (the PIN, a payment): two quick beeps going up;
## - "fout": refused (wrong PIN, too little money): a low buzz, twice;
## - "blik": a can or bottle taken in: a rattle of noise and a hollow clunk going down;
## - "band": the belt carrying it away: a low rumble;
## - "printer": the bon or the ticket printed: a row of buzzy ticks;
## - "geld": money counted out: a whirr with the flutter of notes;
## - "kaart": a card in or out of the slot: a click and a short motor;
## - "inslikken": the card kept: the motor long, going down, a thud.
##   MachineSounds.play(node, "toets")

const MIX_RATE := 22050
const VOLUME_DB := -9.0
## The sounds that came out louder than the rest (measured: docs/GELUIDEN.md "Eén mix"), brought
## back to about -16 LUFS as made, so with VOLUME_DB they are heard at about -22.
const LEVEL_TRIM_DB := {"blik": -4.8, "fout": -2.2, "goed": -1.4}

static var _sounds := {}


static func play(node: Node, sound_name: String, softer_db := 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var stream := sound(sound_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = VOLUME_DB + LEVEL_TRIM_DB.get(sound_name, 0.0) + softer_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	node.get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func sound(sound_name: String) -> AudioStreamWAV:
	if not _sounds.has(sound_name):
		var samples := PackedFloat32Array()
		match sound_name:
			"toets":
				samples = _square(1480.0, 0.05, 0.5)
			"goed":
				samples = _square(1046.5, 0.07, 0.5) + _silence(0.02) + _square(1568.0, 0.11, 0.5)
			"fout":
				samples = _square(196.0, 0.14, 0.5) + _silence(0.05) + _square(185.0, 0.2, 0.5)
			"blik":
				samples = _noise(0.12, 0.6, 2) + _sweep(520.0, 140.0, 0.16, 0.7)
			"band":
				samples = _noise(0.5, 0.25, 12)
			"printer":
				for tick in 9:
					samples += _noise(0.025, 0.45, 1) + _square(2600.0, 0.012, 0.25) + _silence(0.03)
			"geld":
				samples = _sweep(160.0, 210.0, 0.35, 0.35)
				for flutter in 6:
					samples += _noise(0.03, 0.5, 3) + _silence(0.025)
			"kaart":
				samples = _noise(0.02, 0.7, 1) + _sweep(240.0, 300.0, 0.25, 0.3)
			"inslikken":
				samples = _sweep(300.0, 90.0, 0.9, 0.35) + _sweep(120.0, 50.0, 0.12, 0.8)
			_:
				return null
		_sounds[sound_name] = _stream(samples)
	return _sounds[sound_name]


## A square wave (25 % duty, as the PSG), its volume falling in 16 steps.
static func _square(pitch: float, seconds: float, loudness: float) -> PackedFloat32Array:
	var count := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for sample_index in count:
		phase = fmod(phase + pitch / MIX_RATE, 1.0)
		var share := float(sample_index) / count
		var envelope := roundf((1.0 - share * 0.7) * 15.0) / 15.0
		samples[sample_index] = (1.0 if phase < 0.25 else -1.0) * loudness * envelope
	return samples


## A square wave sliding from one pitch to another.
static func _sweep(from_pitch: float, to_pitch: float, seconds: float, loudness: float) -> PackedFloat32Array:
	var count := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for sample_index in count:
		var share := float(sample_index) / count
		phase = fmod(phase + lerpf(from_pitch, to_pitch, share) / MIX_RATE, 1.0)
		var envelope := roundf(clampf(share / 0.05, 0.0, 1.0) * (1.0 - share * 0.8) * 15.0) / 15.0
		samples[sample_index] = (1.0 if phase < 0.5 else -1.0) * loudness * envelope
	return samples


## Noise from the noise channel: a new random level every `hold` samples (more: lower).
static func _noise(seconds: float, loudness: float, hold: int) -> PackedFloat32Array:
	var count := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var random := RandomNumberGenerator.new()
	random.seed = hash([seconds, hold])
	var level := 0.0
	for sample_index in count:
		if sample_index % maxi(hold, 1) == 0:
			level = 1.0 if random.randf() < 0.5 else -1.0
		var share := float(sample_index) / count
		samples[sample_index] = level * loudness * roundf((1.0 - share) * 15.0) / 15.0
	return samples


static func _silence(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	return samples


static func _stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for sample_index in samples.size():
		data.encode_s16(sample_index * 2, int(clampf(samples[sample_index], -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
