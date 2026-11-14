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
## This script keeps the streams (each made once) and plays them; how each is made (its
## samples, its volume) is in machine_sounds_rules.gd.
##   MachineSounds.play(node, "toets")

const MachineSoundsRules = preload("res://scripts/ui/machines/machine_sounds_rules.gd")
const MIX_RATE := MachineSoundsRules.MIX_RATE
const VOLUME_DB := MachineSoundsRules.VOLUME_DB
const LEVEL_TRIM_DB := MachineSoundsRules.LEVEL_TRIM_DB

static var _sounds := {}


static func play(node: Node, sound_name: String, softer_db := 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var stream := sound(sound_name)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = MachineSoundsRules.volume_db(sound_name, softer_db)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	node.get_tree().root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


## The stream of `sound_name`, made the first time it is asked for; null: no such sound.
static func sound(sound_name: String) -> AudioStreamWAV:
	if not MachineSoundsRules.is_sound(sound_name):
		return null
	if not _sounds.has(sound_name):
		_sounds[sound_name] = stream_of(MachineSoundsRules.samples(sound_name, RandomNumberGenerator.new()))
	return _sounds[sound_name]


## The samples as a mono 16-bit stream.
static func stream_of(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = MachineSoundsRules.pcm_bytes(samples)
	return stream
