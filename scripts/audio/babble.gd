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
##   Babble.play_near(self, "vrouw", "blij", "kroket")   # in the UI, the sound of that word
##   Babble.play_near(self, "vrouw", "blij")             # in the UI
##   Babble.play_at(vehicle.global_position, "man", "boos")   # in the world

const FOLDER := "res://assets/audio/geluiden/"
const SoundFiles = preload("res://scripts/audio/sound_files.gd")
const VOICES := ["man", "oude_man", "vrouw"]
## Voices of one person only (a character's "stem", data/gesprekken/personages.json): never handed
## out to anyone else (DriverShout.voice_of picks from VOICES).
const OWN_VOICES := ["rasperig"]
const MOODS := ["neutraal", "blij", "opgewonden", "boos", "verdrietig", "vraag"]
const VARIANTS := 32
## How many of the last variants of a voice and mood are not played again yet.
const RECENT := 6
## How loud the babble is in the UI (dB) and how far the pitch of a word lies from 1 at most
## (share, random for every word).
const UI_DB := -7.0
const PITCH_SPREAD := 0.1

static var _recent := {}   # "voice/mood" -> the variants played last (Array, the newest last)
static var _random := RandomNumberGenerator.new()


## The sound name of babble in `voice` and `mood`: a random variant, not one of the last
## RECENT of that voice and mood. `word` (the word it is said for) does not change which.
static func sound_name(voice: String, mood: String, _word := "") -> String:
	var voice_name := voice if voice in VOICES or voice in OWN_VOICES else "man"
	var mood_name := mood if mood in MOODS else "neutraal"
	var key := voice_name + "/" + mood_name
	var recent: Array = _recent.get(key, [])
	var variant := _random.randi_range(1, VARIANTS)
	while variant in recent:
		variant = variant % VARIANTS + 1
	recent.append(variant)
	if recent.size() > RECENT:
		recent.pop_front()
	_recent[key] = recent
	return "brabbel_%s_%s_%d" % [voice_name, mood_name, variant]


## The pitch a sound plays at: random within PITCH_SPREAD of 1, every word anew.
static func played_pitch(_word := "") -> float:
	return 1.0 + _random.randf_range(-PITCH_SPREAD, PITCH_SPREAD)


## The word of `text` that the sound number `index` (0: the first) of its line is: its nth
## word, the last ones again when the line has fewer; "" for a text without words.
static func word_at(text: String, index: int) -> String:
	var words := text.split(" ", false)
	return words[mini(index, words.size() - 1)] if words.size() > 0 else ""


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
		sound.play_signal(at, sound_name(voice, mood, word_at(text, 0)), 7.0)
