
extends RefCounted
## The sound effects of the menus (main menu, pause menu, intro), made in code in the
## manner of a 16-bit console's FM sound chip (two-operator FM: a modulator bending a
## carrier, short notes, a little digital grit): own sounds in that style, no samples.
## - "kies": choosing another item: two quick bright notes going up;
## - "doe": doing what an item says, going into a menu (and skipping the intro): a quick
##   rising arpeggio of a major chord, the last note ringing on;
## - "terug": going back or leaving a menu: two softer notes going down;
## - "plop": the ZWERVR logo of the intro vanishing in the distance: a short round tone
##   whose pitch drops fast, like a cork;
## - "woord": a word appearing in the story box (story_box.gd): a tiny soft tick;
## - "munt": picking up a coin: a quick bright two-note chime going up (a fourth).
## Play one with UiSounds.play(node, "kies"); the sounds are made once and kept.

const MIX_RATE := 22050
## The volume of the effects (dB).
const VOLUME_DB := -8.0

static var _sounds := {}


## Plays sound `sound_name` (see the top) from a player under `node` that frees itself,
## `softer_db` softer (or louder) than VOLUME_DB.
static func play(node: Node, sound_name: String, softer_db := 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var stream := _sound(sound_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = VOLUME_DB + softer_db
	# it keeps sounding while the game is paused, and after a scene change
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	node.get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _sound(sound_name: String) -> AudioStreamWAV:
	if not _sounds.has(sound_name):
		match sound_name:
			"kies":
				# two quick bright notes going up (a fifth), round (modulator at 1 x, low index)
				_sounds[sound_name] = _notes([[1046.5, 0.035], [1568.0, 0.07]], 1.0, 1.2)
			"doe":
				# a quick rising arpeggio of a major chord (G5 C6 E6 C7), a bit brighter (modulator
				# at 2 x), the last note ringing on
				_sounds[sound_name] = _notes([[784.0, 0.04], [1046.5, 0.04], [1318.5, 0.04], [2093.0, 0.16]], 2.0, 1.4)
			"terug":
				# two softer notes going down (a fourth)
				_sounds[sound_name] = _notes([[880.0, 0.045], [659.3, 0.09]], 1.0, 0.9)
			"plop":
				_sounds[sound_name] = _plop()
			"woord":
				_sounds[sound_name] = _notes([[1318.5, 0.022]], 1.0, 0.5)
			"munt":
				_sounds[sound_name] = _notes([[1975.5, 0.06], [2637.0, 0.2]], 1.0, 1.0)
			_:
				return null
	return _sounds[sound_name]


## A plop: a round FM tone (low index) whose pitch drops from 1100 to 180 Hz in a tenth of
## a second, a sharp attack and a quick decay; held to 6 bits like the others.
static func _plop() -> AudioStreamWAV:
	var seconds := 0.12
	var count := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var carrier_phase := 0.0
	var modulator_phase := 0.0
	for sample_index in count:
		var share := float(sample_index) / count
		var pitch := 180.0 + 920.0 * exp(-share * 7.0)
		carrier_phase += TAU * pitch / MIX_RATE
		modulator_phase += TAU * pitch / MIX_RATE
		var value := sin(carrier_phase + 0.8 * exp(-share * 5.0) * sin(modulator_phase))
		var envelope := clampf(share / 0.04, 0.0, 1.0) * pow(1.0 - share, 2.0)
		value = roundf(value * envelope * 32.0) / 32.0
		data.encode_s16(sample_index * 2, int(clampf(value, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## Notes one after the other ([pitch Hz, seconds] each), each a short FM tone with the
## modulator at `ratio` and modulation `index` (dying away), a quick attack and decay;
## held to 6 bits like the others.
static func _notes(notes: Array, ratio: float, index: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var sample_at := 0
	for note: Array in notes:
		var count := int(float(note[1]) * MIX_RATE)
		data.resize(data.size() + count * 2)
		var carrier_phase := 0.0
		var modulator_phase := 0.0
		for sample_index in count:
			var share := float(sample_index) / count
			modulator_phase += TAU * float(note[0]) * ratio / MIX_RATE
			carrier_phase += TAU * float(note[0]) / MIX_RATE
			var value := sin(carrier_phase + index * exp(-share * 3.0) * sin(modulator_phase))
			var envelope := clampf(share / 0.08, 0.0, 1.0) * pow(1.0 - share, 1.3)
			value = roundf(value * envelope * 32.0) / 32.0
			data.encode_s16((sample_at + sample_index) * 2, int(clampf(value, -1.0, 1.0) * 30000.0))
		sample_at += count
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
