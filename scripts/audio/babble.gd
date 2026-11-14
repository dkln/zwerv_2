extends RefCounted
## Babble: no words, a few syllables whose tune tells the mood (tools/megadrive/stemmen.py,
## assets/audio/geluiden/brabbel_<voice>_<mood>_<n>.ogg). For the conversations (the story
## box: in the speaker's voice while the line types out, not placed in the world, as the game
## stands still) and the shouts in the street (DriverShout: at the speaker, through
## RuimtelijkGeluid).
## Every word its own random sound: one of the VARIANTS that was not among the last RECENT of
## that voice and mood, at a random pitch within PITCH_SPREAD of 1, so a line never sounds like
## the same few recordings going round; a conversation plays one sound per word of its line
## (word_at). The word itself no longer picks the sound.
## This is the behaviour layer: the random draws, what was played last, the players. Which
## variant a draw gives, the names and the pitch are the rules layer (babble_rules.gd); sound
## has no view and no layout.
##   Babble.play_near(self, "vrouw", "blij", "kroket")   # in the UI, the sound of that word
##   Babble.play_near(self, "vrouw", "blij")             # in the UI
##   Babble.play_at(vehicle.global_position, "man", "boos")   # in the world

const FOLDER := "res://assets/audio/geluiden/"
const SoundFiles = preload("res://scripts/audio/sound_files.gd")
const BabbleRules = preload("res://scripts/audio/babble_rules.gd")
## The voices, the moods and the numbers are the rules' (BabbleRules); here under their old
## names for whoever lets someone babble.
const VOICES := BabbleRules.VOICES
const OWN_VOICES := BabbleRules.OWN_VOICES
const MOODS := BabbleRules.MOODS
const VARIANTS := BabbleRules.VARIANTS
const RECENT := BabbleRules.RECENT
const UI_DB := BabbleRules.UI_DB
const PITCH_SPREAD := BabbleRules.PITCH_SPREAD

static var _recent := {}   # "voice/mood" -> the variants played last (Array, the newest last)
static var _random := RandomNumberGenerator.new()


## The sound name of babble in `voice` and `mood`: a random variant, not one of the last
## RECENT of that voice and mood. `word` (the word it is said for) does not change which.
static func sound_name(voice: String, mood: String, _word := "") -> String:
	var key := BabbleRules.recent_key(voice, mood)
	var recent: Array = _recent.get(key, [])
	var variant := BabbleRules.free_variant(_random.randi_range(1, VARIANTS), recent)
	_recent[key] = BabbleRules.recent_after(recent, variant)
	return BabbleRules.name_of(voice, mood, variant)


## The pitch a sound plays at: random within PITCH_SPREAD of 1, every word anew.
static func played_pitch(_word := "") -> float:
	return BabbleRules.pitch_of(_random.randf_range(-PITCH_SPREAD, PITCH_SPREAD))


## The word of `text` that the sound number `index` (0: the first) of its line is: its nth
## word, the last ones again when the line has fewer; "" for a text without words.
static func word_at(text: String, index: int) -> String:
	return BabbleRules.word_at(text, index)


## Plays babble on `owner` (not in the world; it plays while the game stands still too);
## returns the player (freed when done), or null when the sound is missing.
static func play_near(owner: Node, voice: String, mood: String, word := "") -> AudioStreamPlayer:
	var path := SoundFiles.path_of(sound_name(voice, mood, word))   # brabbel/<voice>/
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
	player.pitch_scale = played_pitch(word)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


## Plays babble in the world at `at` (RuimtelijkGeluid: softer further off); `text`: what
## is shouted (the same shout always sounds the same: the sound of its first word).
static func play_at(tree: SceneTree, at: Vector3, voice: String, mood: String, text := "") -> void:
	var sound := tree.root.get_node_or_null("RuimtelijkGeluid") if tree else null
	if sound and sound.has_method("play_signal"):
		sound.play_signal(at, sound_name(voice, mood, word_at(text, 0)), BabbleRules.SHOUT_UNIT)
