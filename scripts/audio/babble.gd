extends RefCounted
## Babble: no words, a few syllables whose tune tells the mood (tools/megadrive/stemmen.py,
## assets/audio/geluiden/brabbel_<voice>_<mood>_<n>.ogg). For the conversations (the story
## box: in the speaker's voice while the line types out, not placed in the world, as the game
## stands still) and the shouts in the street (DriverShout: at the speaker, through
## RuimtelijkGeluid).
## A word has its own sound: given the word that is spoken (`word`), which of the VARIANTS
## it is and how high it sounds follow from the word itself (variant_of, pitch_of), so the
## same text always sounds the same; a conversation plays one sound per word of its line
## (word_at: the nth sound of a line is its nth word). Without a word: any variant. Every
## time it plays it is a little higher or lower still (PITCH_WOBBLE), so a word said twice
## does not sound like one recording played again.
##   Babble.play_near(self, "vrouw", "blij", "kroket")   # in the UI, the sound of that word
##   Babble.play_near(self, "vrouw", "blij")             # in the UI
##   Babble.play_at(vehicle.global_position, "man", "boos")   # in the world

const FOLDER := "res://assets/audio/geluiden/"
const VOICES := ["man", "oude_man", "vrouw"]
## Voices of one person only (a character's "stem", data/gesprekken/personages.json): never handed
## out to anyone else (DriverShout.voice_of picks from VOICES).
const OWN_VOICES := ["rasperig"]
const MOODS := ["neutraal", "blij", "opgewonden", "boos", "verdrietig", "vraag"]
const VARIANTS := 8
## How loud the babble is in the UI (dB), how far the pitch of a word lies from 1 (share,
## the same for that word) and how much it wobbles on top of that each time it plays.
const UI_DB := -6.0
const PITCH_SPREAD := 0.06
const PITCH_WOBBLE := 0.04

static var _last_variant := {}   # "voice/mood" -> the variant played last (never twice in a row)
static var _random := RandomNumberGenerator.new()


## The sound name of babble in `voice` and `mood`: the variant of `word` (always the same
## for the same word), or without a word another variant than the last one.
static func sound_name(voice: String, mood: String, word := "") -> String:
	var voice_name := voice if voice in VOICES or voice in OWN_VOICES else "man"
	var mood_name := mood if mood in MOODS else "neutraal"
	if _plain(word) != "":
		return "brabbel_%s_%s_%d" % [voice_name, mood_name, variant_of(word)]
	var key := voice_name + "/" + mood_name
	var variant := _random.randi_range(1, VARIANTS)
	if variant == int(_last_variant.get(key, 0)):
		variant = variant % VARIANTS + 1
	_last_variant[key] = variant
	return "brabbel_%s_%s_%d" % [voice_name, mood_name, variant]


## The word as it counts for its sound: lower case, without the signs round it ("Kroket!"
## and "kroket" sound the same).
static func _plain(word: String) -> String:
	var plain := ""
	for letter in word.to_lower():
		if letter.unicode_at(0) > 127 or (letter >= "a" and letter <= "z") or (letter >= "0" and letter <= "9"):
			plain += letter
	return plain


## Which of the VARIANTS (1..) the word `word` sounds as: always the same for that word.
static func variant_of(word: String) -> int:
	return int(hash(_plain(word)) % VARIANTS) + 1


## How high the word `word` sounds (the pitch of its sound, within PITCH_SPREAD of 1):
## always the same for that word.
static func pitch_of(word: String) -> float:
	var share := float(hash(_plain(word) + "/toon") % 1000) / 999.0   # 0..1
	return 1.0 + (share * 2.0 - 1.0) * PITCH_SPREAD


## The pitch a sound of `word` plays at this time: that of the word (pitch_of; without a
## word anywhere in PITCH_SPREAD), a little higher or lower each time (PITCH_WOBBLE).
static func played_pitch(word := "") -> float:
	var base := pitch_of(word) if _plain(word) != "" else 1.0 + _random.randf_range(-PITCH_SPREAD, PITCH_SPREAD)
	return base * (1.0 + _random.randf_range(-PITCH_WOBBLE, PITCH_WOBBLE))


## The word of `text` that the sound number `index` (0: the first) of its line is: its nth
## word, the last ones again when the line has fewer; "" for a text without words.
static func word_at(text: String, index: int) -> String:
	var words := text.split(" ", false)
	return words[mini(index, words.size() - 1)] if words.size() > 0 else ""


## Plays babble on `owner` (not in the world; it plays while the game stands still too);
## returns the player (freed when done), or null when the sound is missing.
static func play_near(owner: Node, voice: String, mood: String, word := "") -> AudioStreamPlayer:
	var path := FOLDER + sound_name(voice, mood, word) + ".ogg"
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
