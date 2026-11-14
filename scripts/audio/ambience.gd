extends Node
## The background sound of where the player is (assets/audio/omgeving/, free recordings made
## into loops by tools/megadrive/omgeving.py): softly under everything, the murmur of the
## street outside, the hall of Den Haag Centraal, a shop. Going somewhere else crossfades from
## the one to the other in FADE_SECONDS (equal power). Interiors tells it where (set_place).
## This is the behaviour layer: the players and the crossfade over time. Which loop belongs
## to which place and how loud it plays is the rules layer (ambience_rules.gd); sound has no
## view and no layout.
##   var ambience := Ambience.new()
##   add_child(ambience)
##   ambience.set_place("straat")

const AmbienceRules = preload("res://scripts/audio/ambience_rules.gd")
## The places and the fade are the rules' (AmbienceRules); here under their old names.
const FOLDER := AmbienceRules.FOLDER
const PLACES := AmbienceRules.PLACES
const FADE_SECONDS := AmbienceRules.FADE_SECONDS
const SILENT_DB := AmbienceRules.SILENT_DB

var place := ""
var _player: AudioStreamPlayer      # what plays now
var _fading_out: AudioStreamPlayer  # what plays no more, fading


## Where the player is now ("straat", "station", "winkel"; "" none): crossfades to its sound.
func set_place(new_place: String) -> void:
	if new_place == place:
		return
	place = new_place
	_fade_out_current()
	var stream := _loop(AmbienceRules.path_of(new_place))
	if stream == null:
		return
	_player = AudioStreamPlayer.new()
	_player.name = AmbienceRules.player_name(new_place)
	_player.stream = stream
	_player.volume_db = SILENT_DB
	add_child(_player)
	_player.play(AmbienceRules.start_position(randf(), stream.get_length()))
	var fade_in := create_tween()
	fade_in.tween_property(_player, "volume_db", AmbienceRules.volume_db_of(new_place), FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## What plays now fades out and goes; what was still fading out goes at once.
func _fade_out_current() -> void:
	if _fading_out and is_instance_valid(_fading_out):
		_fading_out.queue_free()
	_fading_out = _player
	_player = null
	if _fading_out:
		var out := create_tween()
		out.tween_property(_fading_out, "volume_db", SILENT_DB, FADE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		out.tween_callback(_fading_out.queue_free)


## The loop at `path` (imported by the editor, or straight from the file before that); null
## without a path or a file.
static func _loop(path: String) -> AudioStream:
	if path == "":
		return null
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	elif FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream
