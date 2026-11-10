extends RefCounted
## Babble: no words, a few syllables whose tune tells the mood (tools/megadrive/stemmen.py,
## assets/audio/geluiden/brabbel_<voice>_<mood>_<n>.ogg). For the conversations (the story
## box: in the speaker's voice while the line types out, not placed in the world, as the game
## stands still) and the shouts in the street (DriverShout: at the speaker, through
## RuimtelijkGeluid).
##   Babble.play_near(self, "vrouw", "blij")             # in the UI
##   Babble.play_at(vehicle.global_position, "man", "boos")   # in the world

const FOLDER := "res://assets/audio/geluiden/"
const VOICES := ["man", "oude_man", "vrouw"]
const MOODS := ["neutraal", "blij", "opgewonden", "boos", "verdrietig", "vraag"]
const VARIANTS := 3
## How loud the babble is in the UI (dB), and how much its pitch may wander (share).
const UI_DB := -6.0
const PITCH_SPREAD := 0.06

static var _last_variant := {}   # "voice/mood" -> the variant played last (never twice in a row)
static var _random := RandomNumberGenerator.new()


## The sound name of babble in `voice` and `mood` (another variant than the last one).
static func sound_name(voice: String, mood: String) -> String:
	var voice_name := voice if voice in VOICES else "man"
	var mood_name := mood if mood in MOODS else "neutraal"
	var key := voice_name + "/" + mood_name
	var variant := _random.randi_range(1, VARIANTS)
	if variant == int(_last_variant.get(key, 0)):
		variant = variant % VARIANTS + 1
	_last_variant[key] = variant
	return "brabbel_%s_%s_%d" % [voice_name, mood_name, variant]


## Plays babble on `owner` (not in the world; it plays while the game stands still too);
## returns the player (freed when done), or null when the sound is missing.
static func play_near(owner: Node, voice: String, mood: String) -> AudioStreamPlayer:
	var path := FOLDER + sound_name(voice, mood) + ".ogg"
	if owner == null:
		return null
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)   # not imported yet
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = UI_DB
	player.pitch_scale = 1.0 + _random.randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Plays babble in the world at `at` (RuimtelijkGeluid: softer further off).
static func play_at(tree: SceneTree, at: Vector3, voice: String, mood: String) -> void:
	var sound := tree.root.get_node_or_null("RuimtelijkGeluid") if tree else null
	if sound and sound.has_method("play_signal"):
		sound.play_signal(at, sound_name(voice, mood), 7.0)
